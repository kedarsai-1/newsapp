const { Prisma, prisma } = require('../config/prisma');
const {
  serializeCategory,
  serializeNewsPost,
  serializeUser,
} = require('../utils/serializers');
const { mediaCreate, newsPostInclude } = require('../utils/prismaNewsPost');
const { sendToDevice, sendToTopic } = require('../utils/notifications');
const {
  runIngestion,
  getIngestionStatus,
} = require('../services/newsIngestionService');
const { runYoutubeIngestion } = require('../services/youtubeIngestionService');
const { fetchBestImageFallback, isUnusableFeedImageUrl } = require('../services/newsApiService');
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
      prisma.user.count({ where: { role: 'user' } }),
      prisma.user.count({ where: { role: 'reporter' } }),
      prisma.newsPost.count({ where: { status: 'pending' } }),
      prisma.newsPost.count({
        where: {
          status: 'approved',
          approvedAt: { gte: new Date(new Date().setHours(0, 0, 0, 0)) },
        },
      }),
      prisma.newsPost.count(),
    ]);

    const recentActivity = await prisma.newsPost.findMany({
      where: { status: 'pending' },
      include: newsPostInclude,
      orderBy: { createdAt: 'desc' },
      take: 5,
    });

    res.json({
      success: true,
      stats: { totalUsers, totalReporters, pendingPosts, approvedToday, totalPosts },
      recentActivity: recentActivity.map(serializeNewsPost),
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
    const where = { status: 'pending' };
    const [total, posts] = await Promise.all([
      prisma.newsPost.count({ where }),
      prisma.newsPost.findMany({
        where,
        include: newsPostInclude,
        orderBy: { createdAt: 'asc' }, // oldest first for fair review
        skip,
        take: parseInt(limit),
      }),
    ]);

    res.json({ success: true, total, posts: posts.map(serializeNewsPost) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/admin/posts — all posts with filters
const getAllPosts = async (req, res) => {
  try {
    const { page = 1, limit = 20, status, category, reporter } = req.query;
    const where = {};
    if (status) where.status = status;
    if (category) where.categoryId = String(category);
    if (reporter) where.reporterId = String(reporter);

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const [total, posts] = await Promise.all([
      prisma.newsPost.count({ where }),
      prisma.newsPost.findMany({
        where,
        include: newsPostInclude,
        orderBy: { createdAt: 'desc' },
        skip,
        take: parseInt(limit),
      }),
    ]);

    res.json({ success: true, total, posts: posts.map(serializeNewsPost) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/admin/posts/:id/approve
const approvePost = async (req, res) => {
  try {
    const { isBreaking, isFeatured } = req.body;
    const post = await prisma.newsPost.update({
      where: { id: req.params.id },
      data: {
        status: 'approved',
        approvedById: req.user._id,
        approvedAt: new Date(),
        isBreaking: !!isBreaking,
        isFeatured: !!isFeatured,
        rejectionReason: null,
      },
      include: newsPostInclude,
    });

    if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });

    // Notify the reporter
    if (post.reporter.fcmToken) {
      await sendToDevice(
        post.reporter.fcmToken,
        'Story Published!',
        `Your story "${post.title}" is now live.`,
        { postId: post.id, type: 'approved' }
      );
    }

    // Broadcast to category subscribers
    await sendToTopic(
      `category_${post.category.slug}`,
      isBreaking ? '🔴 Breaking News' : post.category.name,
      post.title,
      { postId: post.id, type: 'news' }
    );

    // Emit real-time event via Socket.io
    req.io.to('all').emit('new_post', {
      id: post.id,
      title: post.title,
      category: serializeCategory(post.category),
      isBreaking: post.isBreaking,
    });

    res.json({ success: true, message: 'Post approved and published.', post: serializeNewsPost(post) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/admin/posts/:id/reject
const rejectPost = async (req, res) => {
  try {
    const { reason } = req.body;
    if (!reason) return res.status(400).json({ success: false, message: 'Rejection reason required.' });

    const post = await prisma.newsPost.update({
      where: { id: req.params.id },
      data: { status: 'rejected', rejectionReason: reason },
      include: newsPostInclude,
    });

    if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });

    // Notify reporter
    if (post.reporter.fcmToken) {
      await sendToDevice(
        post.reporter.fcmToken,
        'Story Update',
        `Your story "${post.title}" needs revision. Reason: ${reason}`,
        { postId: post.id, type: 'rejected' }
      );
    }

    res.json({ success: true, message: 'Post rejected.', post: serializeNewsPost(post) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/admin/posts/:id/feature — toggle breaking/featured flags
const featurePost = async (req, res) => {
  try {
    const { isBreaking, isFeatured } = req.body;
    const post = await prisma.newsPost.update({
      where: { id: req.params.id },
      data: { isBreaking, isFeatured },
      include: newsPostInclude,
    });
    res.json({ success: true, post: serializeNewsPost(post) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/admin/users
const getUsers = async (req, res) => {
  try {
    const { role, page = 1, limit = 30, search } = req.query;
    const where = {};
    if (role) where.role = role;
    if (search) where.OR = [
      { name: { contains: String(search), mode: 'insensitive' } },
      { email: { contains: String(search), mode: 'insensitive' } },
    ];

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const [total, users] = await Promise.all([
      prisma.user.count({ where }),
      prisma.user.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip,
        take: parseInt(limit),
      }),
    ]);

    res.json({ success: true, total, users: users.map(serializeUser) });
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
    const user = await prisma.user.update({ where: { id: req.params.id }, data: { role } });
    res.json({ success: true, user: serializeUser(user) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/admin/users/:id/toggle-active
const toggleUserActive = async (req, res) => {
  try {
    const user = await prisma.user.findUnique({ where: { id: req.params.id } });
    if (!user) return res.status(404).json({ success: false, message: 'User not found.' });
    const updated = await prisma.user.update({
      where: { id: req.params.id },
      data: { isActive: !user.isActive },
    });
    res.json({ success: true, message: `User ${updated.isActive ? 'activated' : 'suspended'}.`, user: serializeUser(updated) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/admin/categories
const createCategory = async (req, res) => {
  try {
    const { name, slug, icon, color, order } = req.body;
    const category = await prisma.category.create({
      data: {
        name,
        slug: String(slug || '').toLowerCase(),
        icon,
        color,
        order,
      },
    });
    res.status(201).json({ success: true, category: serializeCategory(category) });
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

// POST /api/admin/youtube/ingest
const runYoutubeIngestionNow = async (req, res) => {
  try {
    const result = await runYoutubeIngestion({
      triggeredBy: `admin:${req.user._id.toString()}`,
    });
    if (!result.success && result.skipped) {
      return res.json(result);
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

    const where = {
      status: 'approved',
      sourceType: { in: sourceTypes },
      sourceUrl: { not: null },
      media: { none: {} },
    };

    const posts = await prisma.newsPost.findMany({
      where,
      select: { id: true, sourceUrl: true, sourceName: true, sourceType: true, createdAt: true },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

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

      if (og && !isUnusableFeedImageUrl(og)) {
        // eslint-disable-next-line no-await-in-loop
        const reh = await rehostExternalImageToCloudinary(og, { referer: articleUrl });
        finalUrl = reh?.url || og;
        finalPublicId = reh?.publicId || null;
      }

      if (!finalUrl) {
        failed += 1;
        continue;
      }

      // eslint-disable-next-line no-await-in-loop
      await prisma.newsPost.update({
        where: { id: p.id },
        data: {
          sourceUrl: articleUrl,
          media: {
            create: mediaCreate([
              {
                type: 'image',
                url: finalUrl,
                ...(finalPublicId ? { publicId: finalPublicId } : {}),
              },
            ]),
          },
        },
      });
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
  runYoutubeIngestionNow,
  getIngestionRunStatus,
  backfillThumbnails,
};