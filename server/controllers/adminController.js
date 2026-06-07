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
const { runAllLanguageIngestionParallel } = require('../services/languageIngestionService');
const { isPerLanguageIngestEnabled } = require('../config/ingestLanguages');
const { fetchBestImageFallback, isUnusableFeedImageUrl } = require('../services/newsApiService');
const { resolveGoogleNewsPublisherUrl } = require('../services/rssService');
const feedResponseCache = require('../utils/feedResponseCache');
const { validateCategoryInput } = require('../utils/categoryValidation');
const { runPoliticalVideoIngestion } = require('../services/politicalVideoIngestionService');

const { rehostExternalImageToCloudinary: rehostImage } = require('../utils/rehostExternalImage');

async function rehostExternalImageToCloudinary(imageUrl, { referer } = {}) {
  const result = await rehostImage(imageUrl, { referer, skipIngestEnvCheck: true });
  if (!result.ok || !result.url) return null;
  return { url: result.url, publicId: result.publicId || null };
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
    const validated = validateCategoryInput(req.body || {});
    if (validated.error) {
      return res.status(400).json({ success: false, message: validated.error });
    }
    const { name, slug } = validated.data;
    const { icon, color, order } = req.body || {};
    const category = await prisma.category.create({
      data: {
        name,
        slug,
        icon,
        color,
        order: Number.isFinite(Number(order)) ? Number(order) : undefined,
      },
    });
    await feedResponseCache.invalidateFeedCaches();
    res.status(201).json({ success: true, category: serializeCategory(category) });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
      return res.status(409).json({ success: false, message: 'Category slug already exists.' });
    }
    res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/admin/categories/:id
const updateCategory = async (req, res) => {
  try {
    const { id } = req.params;
    const existing = await prisma.category.findUnique({ where: { id } });
    if (!existing) {
      return res.status(404).json({ success: false, message: 'Category not found.' });
    }

    const data = {};
    if (req.body?.name != null) {
      const name = String(req.body.name).trim();
      if (!name) return res.status(400).json({ success: false, message: 'Category name cannot be empty.' });
      data.name = name;
    }
    if (req.body?.slug != null) {
      const slug = String(req.body.slug).trim().toLowerCase();
      const validated = validateCategoryInput({ name: data.name || existing.name, slug });
      if (validated.error) {
        return res.status(400).json({ success: false, message: validated.error });
      }
      data.slug = validated.data.slug;
    }
    if (req.body?.icon != null) data.icon = req.body.icon;
    if (req.body?.color != null) data.color = req.body.color;
    if (req.body?.order != null && Number.isFinite(Number(req.body.order))) {
      data.order = Number(req.body.order);
    }
    if (req.body?.isActive != null) data.isActive = Boolean(req.body.isActive);

    const category = await prisma.category.update({ where: { id }, data });
    await feedResponseCache.invalidateFeedCaches();
    res.json({ success: true, category: serializeCategory(category) });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
      return res.status(409).json({ success: false, message: 'Category slug already exists.' });
    }
    res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/admin/categories/:id/toggle-active
const toggleCategoryActive = async (req, res) => {
  try {
    const existing = await prisma.category.findUnique({ where: { id: req.params.id } });
    if (!existing) {
      return res.status(404).json({ success: false, message: 'Category not found.' });
    }
    const category = await prisma.category.update({
      where: { id: req.params.id },
      data: { isActive: !existing.isActive },
    });
    await feedResponseCache.invalidateFeedCaches();
    res.json({
      success: true,
      message: `Category ${category.isActive ? 'activated' : 'deactivated'}.`,
      category: serializeCategory(category),
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/admin/political-videos/ingest
const runPoliticalVideoIngestionNow = async (req, res) => {
  try {
    const result = await runPoliticalVideoIngestion({
      triggeredBy: `admin:${req.user._id.toString()}`,
    });
    if (!result.success) {
      return res.status(500).json(result);
    }
    return res.json(result);
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/admin/ingestion/run
const runIngestionNow = async (req, res) => {
  try {
    if (isPerLanguageIngestEnabled()) {
      const result = await runAllLanguageIngestionParallel({
        triggeredBy: `admin:${req.user._id.toString()}`,
      });
      if (!result.success) {
        return res.status(500).json(result);
      }
      return res.json(result);
    }

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
  updateCategory,
  toggleCategoryActive,
  runIngestionNow,
  runYoutubeIngestionNow,
  runPoliticalVideoIngestionNow,
  getIngestionRunStatus,
  backfillThumbnails,
};