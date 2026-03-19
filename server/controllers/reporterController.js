const NewsPost = require('../models/NewsPost');
const { reverseGeocode } = require('../utils/geocode');
const { sendToTopic } = require('../utils/notifications');
const { cloudinary } = require('../config/cloudinary');

// POST /api/reporter/posts — create a new post
const createPost = async (req, res) => {
  try {
    const { title, body, summary, categoryId, latitude, longitude, tags, isDraft } = req.body;

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

    const post = await NewsPost.create({
      title,
      body,
      summary,
      reporter: req.user._id,
      category: categoryId,
      media,
      location,
      status: isDraft === 'true' ? 'draft' : 'pending',
      tags: tags ? JSON.parse(tags) : [],
    });

    await post.populate('category', 'name slug icon');

    res.status(201).json({
      success: true,
      message: isDraft === 'true' ? 'Draft saved.' : 'Post submitted for review.',
      post,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/reporter/posts — reporter's own posts
const getMyPosts = async (req, res) => {
  try {
    const { status, page = 1, limit = 20 } = req.query;
    const query = { reporter: req.user._id };
    if (status) query.status = status;

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const total = await NewsPost.countDocuments(query);

    const posts = await NewsPost.find(query)
      .populate('category', 'name slug icon color')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    res.json({ success: true, total, posts });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/reporter/posts/:id — edit a draft or rejected post
const updatePost = async (req, res) => {
  try {
    const post = await NewsPost.findOne({ _id: req.params.id, reporter: req.user._id });
    if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });

    if (!['draft', 'rejected'].includes(post.status)) {
      return res.status(403).json({ success: false, message: 'Only drafts or rejected posts can be edited.' });
    }

    const { title, body, summary, categoryId, tags } = req.body;
    if (title) post.title = title;
    if (body) post.body = body;
    if (summary) post.summary = summary;
    if (categoryId) post.category = categoryId;
    if (tags) post.tags = JSON.parse(tags);

    // Add new media files if any
    if (req.files && req.files.length > 0) {
      for (const file of req.files) {
        const isVideo = file.mimetype.startsWith('video/');
        post.media.push({
          type: isVideo ? 'video' : 'image',
          url: file.path,
          publicId: file.filename,
          size: file.size || 0,
        });
      }
    }

    post.status = 'pending'; // Re-submit for approval
    post.rejectionReason = null;
    await post.save();

    res.json({ success: true, message: 'Post re-submitted for review.', post });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// DELETE /api/reporter/posts/:id/media/:mediaId — remove a media item
const deleteMedia = async (req, res) => {
  try {
    const post = await NewsPost.findOne({ _id: req.params.id, reporter: req.user._id });
    if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });

    const mediaItem = post.media.id(req.params.mediaId);
    if (!mediaItem) return res.status(404).json({ success: false, message: 'Media not found.' });

    // Delete from Cloudinary
    if (mediaItem.publicId) {
      const resourceType = mediaItem.type === 'video' ? 'video' : 'image';
      await cloudinary.uploader.destroy(mediaItem.publicId, { resource_type: resourceType });
    }

    post.media.pull(req.params.mediaId);
    await post.save();

    res.json({ success: true, message: 'Media removed.' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/reporter/stats — reporter dashboard stats
const getStats = async (req, res) => {
  try {
    const reporterId = req.user._id;
    const [total, pending, approved, rejected, views, likes] = await Promise.all([
      NewsPost.countDocuments({ reporter: reporterId }),
      NewsPost.countDocuments({ reporter: reporterId, status: 'pending' }),
      NewsPost.countDocuments({ reporter: reporterId, status: 'approved' }),
      NewsPost.countDocuments({ reporter: reporterId, status: 'rejected' }),
      NewsPost.aggregate([
        { $match: { reporter: reporterId } },
        { $group: { _id: null, total: { $sum: '$views' } } },
      ]),
      NewsPost.aggregate([
        { $match: { reporter: reporterId } },
        { $group: { _id: null, total: { $sum: '$likes' } } },
      ]),
    ]);

    res.json({
      success: true,
      stats: {
        totalPosts: total,
        pending,
        approved,
        rejected,
        totalViews: views[0]?.total || 0,
        totalLikes: likes[0]?.total || 0,
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { createPost, getMyPosts, updatePost, deleteMedia, getStats };