const { prisma } = require('../config/prisma');
const { reverseGeocode } = require('../utils/geocode');
const { cloudinary } = require('../config/cloudinary');
const { serializeNewsPost } = require('../utils/serializers');
const {
  createNewsPost,
  mediaCreate,
  newsPostInclude,
} = require('../utils/prismaNewsPost');

// POST /api/reporter/posts — create a new post
const createPost = async (req, res) => {
  try {
    const { title, body, summary, categoryId, latitude, longitude, tags, isDraft } = req.body;
    if (!title || !body || !categoryId) {
      return res.status(400).json({
        success: false,
        message: 'Title, body, and categoryId are required.',
      });
    }

    // Build location object via reverse geocoding
    let location = null;
    if (latitude && longitude) {
      location = await reverseGeocode(latitude, longitude);
    }

    // Build media array from uploaded files
    const media = [];
    if (req.files && req.files.length > 0) {
      for (const file of req.files) {
        const isVideo = file.mimetype.startsWith('video/');
        media.push({
          type: isVideo ? 'video' : 'image',
          url: file.path,           // Cloudinary URL
          publicId: file.filename,  // Cloudinary public_id
          size: file.size || 0,
          thumbnail: isVideo ? file.path.replace('/upload/', '/upload/so_0,w_400,h_225,c_fill/') : null,
        });
      }
    }

    const post = await createNewsPost({
      title,
      body,
      summary,
      reporterId: req.user._id,
      categoryId,
      media,
      location,
      status: isDraft === 'true' ? 'draft' : 'pending',
      tags: tags ? JSON.parse(tags) : [],
    }, {
      include: newsPostInclude,
    });

    res.status(201).json({
      success: true,
      message: isDraft === 'true' ? 'Draft saved.' : 'Post submitted for review.',
      post: serializeNewsPost(post),
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/reporter/posts — reporter's own posts
const getMyPosts = async (req, res) => {
  try {
    const { status, page = 1, limit = 20 } = req.query;
    const where = { reporterId: req.user._id };
    if (status) where.status = status;

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

// PUT /api/reporter/posts/:id — edit a draft or rejected post
const updatePost = async (req, res) => {
  try {
    const post = await prisma.newsPost.findFirst({
      where: { id: req.params.id, reporterId: req.user._id },
      include: { media: true },
    });
    if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });

    if (!['draft', 'rejected'].includes(post.status)) {
      return res.status(403).json({ success: false, message: 'Only drafts or rejected posts can be edited.' });
    }

    const { title, body, summary, categoryId, tags } = req.body;
    const data = {};
    if (title) data.title = title;
    if (body) data.body = body;
    if (summary) data.summary = summary;
    if (categoryId) data.categoryId = categoryId;
    if (tags) data.tags = JSON.parse(tags);

    // Add new media files if any
    if (req.files && req.files.length > 0) {
      for (const file of req.files) {
        const isVideo = file.mimetype.startsWith('video/');
        const newMedia = {
          type: isVideo ? 'video' : 'image',
          url: file.path,
          publicId: file.filename,
          size: file.size || 0,
        };
        data.media = data.media || { create: [] };
        data.media.create.push(...mediaCreate([newMedia]));
      }
    }

    data.status = 'pending'; // Re-submit for approval
    data.rejectionReason = null;
    const updated = await prisma.newsPost.update({
      where: { id: post.id },
      data,
      include: newsPostInclude,
    });

    res.json({ success: true, message: 'Post re-submitted for review.', post: serializeNewsPost(updated) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// DELETE /api/reporter/posts/:id/media/:mediaId — remove a media item
const deleteMedia = async (req, res) => {
  try {
    const post = await prisma.newsPost.findFirst({
      where: { id: req.params.id, reporterId: req.user._id },
      include: { media: true },
    });
    if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });

    const mediaItem = post.media.find((m) => m.id === req.params.mediaId);
    if (!mediaItem) return res.status(404).json({ success: false, message: 'Media not found.' });

    // Delete from Cloudinary
    if (mediaItem.publicId) {
      const resourceType = mediaItem.type === 'video' ? 'video' : 'image';
      await cloudinary.uploader.destroy(mediaItem.publicId, { resource_type: resourceType });
    }

    await prisma.newsPostMedia.delete({ where: { id: req.params.mediaId } });

    res.json({ success: true, message: 'Media removed.' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/reporter/stats — reporter dashboard stats
const getStats = async (req, res) => {
  try {
    const reporterId = req.user._id;
    const [total, pending, approved, rejected, sums] = await Promise.all([
      prisma.newsPost.count({ where: { reporterId } }),
      prisma.newsPost.count({ where: { reporterId, status: 'pending' } }),
      prisma.newsPost.count({ where: { reporterId, status: 'approved' } }),
      prisma.newsPost.count({ where: { reporterId, status: 'rejected' } }),
      prisma.newsPost.aggregate({
        where: { reporterId },
        _sum: { views: true, likes: true },
      }),
    ]);

    res.json({
      success: true,
      stats: {
        totalPosts: total,
        pending,
        approved,
        rejected,
        totalViews: sums._sum.views || 0,
        totalLikes: sums._sum.likes || 0,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { createPost, getMyPosts, updatePost, deleteMedia, getStats };