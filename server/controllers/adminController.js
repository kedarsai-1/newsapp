const NewsPost = require('../models/NewsPost');
const User = require('../models/User');
const Category = require('../models/Category');
const { sendToDevice, sendToTopic } = require('../utils/notifications');
const {
  runIngestion,
  getIngestionStatus,
} = require('../services/newsIngestionService');
const { fetchBestImageFallback, buildDomainImageFallbackCandidates } = require('../services/newsApiService');
const { resolveGoogleNewsPublisherUrl } = require('../services/rssService');
const { cloudinary } = require('../config/cloudinary');

function isCloudinaryUrl(url) {
  if (!url || typeof url !== 'string') return false;
  return url.includes('res.cloudinary.com/') || url.includes('cloudinary.com/');
}

async function rehostExternalImageToCloudinary(imageUrl, { referer } = {}) {
  if (!imageUrl || typeof imageUrl !== 'string') return null;
  if (isCloudinaryUrl(imageUrl)) return { url: imageUrl, publicId: null };

  const ac = new AbortController();
  const to = setTimeout(() => ac.abort(), 15000);
  try {
    const res = await fetch(imageUrl, {
      redirect: 'follow',
      signal: ac.signal,
      headers: {
        'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
        Accept: 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
        ...(referer ? { Referer: referer, Origin: referer } : {}),
      },
    });
    clearTimeout(to);
    if (!res.ok) return null;
    const ct = (res.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
    if (ct && !ct.startsWith('image/')) return null;
    const buf = Buffer.from(await res.arrayBuffer());
    if (!buf.length || buf.length > 5 * 1024 * 1024) return null;
    const dataUri = `data:${ct || 'image/jpeg'};base64,${buf.toString('base64')}`;
    const up = await cloudinary.uploader.upload(dataUri, {
      folder: 'newsapp/external',
      resource_type: 'image',
      overwrite: false,
      unique_filename: true,
    });
    const url = up?.secure_url || up?.url;
    if (!url) return null;
    return { url, publicId: up.public_id };
  } catch {
    clearTimeout(to);
    return null;
  }
}

// GET /api/admin/dashboard — stats overview
const getDashboard = async (req, res) => {
  try {
    const [totalUsers, totalReporters, pendingPosts, approvedToday, totalPosts] = await Promise.all([
      User.countDocuments({ role: 'user' }),
      User.countDocuments({ role: 'reporter' }),
      NewsPost.countDocuments({ status: 'pending' }),
      NewsPost.countDocuments({
        status: 'approved',
        approvedAt: { $gte: new Date(new Date().setHours(0, 0, 0, 0)) },
      }),
      NewsPost.countDocuments(),
    ]);

    const recentActivity = await NewsPost.find({ status: 'pending' })
      .populate('reporter', 'name avatar')
      .populate('category', 'name icon')
      .sort({ createdAt: -1 })
      .limit(5);

    res.json({
      success: true,
      stats: { totalUsers, totalReporters, pendingPosts, approvedToday, totalPosts },
      recentActivity,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/admin/posts/pending
const getPendingPosts = async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const skip = (parseInt(page) - 1) * parseInt(limit);
    const total = await NewsPost.countDocuments({ status: 'pending' });

    const posts = await NewsPost.find({ status: 'pending' })
      .populate('reporter', 'name avatar email')
      .populate('category', 'name icon color')
      .sort({ createdAt: 1 }) // oldest first for fair review
      .skip(skip)
      .limit(parseInt(limit));

    res.json({ success: true, total, posts });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/admin/posts — all posts with filters
const getAllPosts = async (req, res) => {
  try {
    const { page = 1, limit = 20, status, category, reporter } = req.query;
    const query = {};
    if (status) query.status = status;
    if (category) query.category = category;
    if (reporter) query.reporter = reporter;

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const total = await NewsPost.countDocuments(query);

    const posts = await NewsPost.find(query)
      .populate('reporter', 'name avatar')
      .populate('category', 'name icon color')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    res.json({ success: true, total, posts });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/admin/posts/:id/approve
const approvePost = async (req, res) => {
  try {
    const { isBreaking, isFeatured } = req.body;
    const post = await NewsPost.findByIdAndUpdate(
      req.params.id,
      {
        status: 'approved',
        approvedBy: req.user._id,
        approvedAt: new Date(),
        isBreaking: !!isBreaking,
        isFeatured: !!isFeatured,
        rejectionReason: null,
      },
      { new: true }
    ).populate('reporter', 'name fcmToken').populate('category', 'name slug');

    if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });

    // Notify the reporter
    if (post.reporter.fcmToken) {
      await sendToDevice(
        post.reporter.fcmToken,
        'Story Published!',
        `Your story "${post.title}" is now live.`,
        { postId: post._id.toString(), type: 'approved' }
      );
    }

    // Broadcast to category subscribers
    await sendToTopic(
      `category_${post.category.slug}`,
      isBreaking ? '🔴 Breaking News' : post.category.name,
      post.title,
      { postId: post._id.toString(), type: 'news' }
    );

    // Emit real-time event via Socket.io
    req.io.to('all').emit('new_post', {
      id: post._id,
      title: post.title,
      category: post.category,
      isBreaking: post.isBreaking,
    });

    res.json({ success: true, message: 'Post approved and published.', post });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/admin/posts/:id/reject
const rejectPost = async (req, res) => {
  try {
    const { reason } = req.body;
    if (!reason) return res.status(400).json({ success: false, message: 'Rejection reason required.' });

    const post = await NewsPost.findByIdAndUpdate(
      req.params.id,
      { status: 'rejected', rejectionReason: reason },
      { new: true }
    ).populate('reporter', 'name fcmToken');

    if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });

    // Notify reporter
    if (post.reporter.fcmToken) {
      await sendToDevice(
        post.reporter.fcmToken,
        'Story Update',
        `Your story "${post.title}" needs revision. Reason: ${reason}`,
        { postId: post._id.toString(), type: 'rejected' }
      );
    }

    res.json({ success: true, message: 'Post rejected.', post });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/admin/posts/:id/feature — toggle breaking/featured flags
const featurePost = async (req, res) => {
  try {
    const { isBreaking, isFeatured } = req.body;
    const post = await NewsPost.findByIdAndUpdate(
      req.params.id,
      { isBreaking, isFeatured },
      { new: true }
    );
    res.json({ success: true, post });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/admin/users
const getUsers = async (req, res) => {
  try {
    const { role, page = 1, limit = 30, search } = req.query;
    const query = {};
    if (role) query.role = role;
    if (search) query.$or = [
      { name: new RegExp(search, 'i') },
      { email: new RegExp(search, 'i') },
    ];

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const total = await User.countDocuments(query);

    const users = await User.find(query)
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    res.json({ success: true, total, users });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/admin/users/:id/role
const updateUserRole = async (req, res) => {
  try {
    const { role } = req.body;
    if (!['user', 'reporter', 'admin'].includes(role)) {
      return res.status(400).json({ success: false, message: 'Invalid role.' });
    }
    const user = await User.findByIdAndUpdate(req.params.id, { role }, { new: true });
    res.json({ success: true, user });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/admin/users/:id/toggle-active
const toggleUserActive = async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found.' });
    user.isActive = !user.isActive;
    await user.save();
    res.json({ success: true, message: `User ${user.isActive ? 'activated' : 'suspended'}.`, user });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/admin/categories
const createCategory = async (req, res) => {
  try {
    const { name, slug, icon, color, order } = req.body;
    const category = await Category.create({ name, slug, icon, color, order });
    res.status(201).json({ success: true, category });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/admin/ingestion/run
const runIngestionNow = async (req, res) => {
  try {
    const result = await runIngestion({
      triggeredBy: `admin:${req.user._id.toString()}`,
    });
    if (!result.success && result.skipped) {
      return res.status(409).json(result);
    }
    if (!result.success) {
      return res.status(500).json(result);
    }
    return res.json(result);
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/admin/ingestion/status
const getIngestionRunStatus = async (req, res) => {
  try {
    return res.json({ success: true, status: getIngestionStatus() });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/admin/media/backfill-thumbnails
// Backfill thumbnails for RSS/API posts that have sourceUrl but no media.
const backfillThumbnails = async (req, res) => {
  try {
    const limit = Math.min(500, Math.max(1, Number(req.body?.limit || 80)));
    const sourceTypes = (req.body?.sourceTypes || ['rss', 'api'])
      .map((s) => String(s).trim().toLowerCase())
      .filter(Boolean);

    const query = {
      status: 'approved',
      sourceType: { $in: sourceTypes },
      sourceUrl: { $exists: true, $ne: null, $ne: '' },
      $or: [{ media: { $exists: false } }, { media: { $size: 0 } }],
    };

    const posts = await NewsPost.find(query)
      .select('_id sourceUrl sourceType media createdAt')
      .sort({ createdAt: -1 })
      .limit(limit);

    let updated = 0;
    let failed = 0;

    for (const p of posts) {
      let articleUrl = p.sourceUrl;
      if (articleUrl && String(articleUrl).includes('news.google.com')) {
        // For older rows saved with Google News redirect links, resolve to publisher first.
        let preferredHost = null;
        const src = String(p.sourceName || '').toLowerCase();
        if (src.includes('eenadu')) preferredHost = 'eenadu.net';
        else if (src.includes('aaj tak')) preferredHost = 'aajtak.in';
        else if (src.includes('amar ujala')) preferredHost = 'amarujala.com';
        // eslint-disable-next-line no-await-in-loop
        const resolved = await resolveGoogleNewsPublisherUrl(articleUrl, { preferredHost });
        if (resolved) articleUrl = resolved;
      }

      // eslint-disable-next-line no-await-in-loop
      const og = await fetchBestImageFallback(articleUrl);
      let finalUrl = null;
      let finalPublicId = null;

      if (og) {
        // eslint-disable-next-line no-await-in-loop
        const reh = await rehostExternalImageToCloudinary(og, { referer: articleUrl });
        finalUrl = reh?.url || og;
        finalPublicId = reh?.publicId || null;
      } else {
        const logoCandidates = buildDomainImageFallbackCandidates(articleUrl);
        for (const c of logoCandidates) {
          // eslint-disable-next-line no-await-in-loop
          const reh = await rehostExternalImageToCloudinary(c, { referer: articleUrl });
          if (reh?.url) {
            finalUrl = reh.url;
            finalPublicId = reh.publicId || null;
            break;
          }
        }
      }

      if (!finalUrl) {
        failed += 1;
        continue;
      }

      p.sourceUrl = articleUrl;
      p.media = [
        {
          type: 'image',
          url: finalUrl,
          ...(finalPublicId ? { publicId: finalPublicId } : {}),
        },
      ];
      // eslint-disable-next-line no-await-in-loop
      await p.save();
      updated += 1;
    }

    return res.json({
      success: true,
      scanned: posts.length,
      updated,
      failed,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  getDashboard,
  getPendingPosts,
  getAllPosts,
  approvePost,
  rejectPost,
  featurePost,
  getUsers,
  updateUserRole,
  toggleUserActive,
  createCategory,
  runIngestionNow,
  getIngestionRunStatus,
  backfillThumbnails,
};