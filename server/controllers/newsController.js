const NewsPost = require('../models/NewsPost');
const User = require('../models/User');
const Comment = require('../models/Comment');

// GET /api/news/feed  — paginated, filterable by category and city
const getFeed = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      category,
      city,
      search,
      breaking,
      featured,
    } = req.query;

    const query = { status: 'approved' };
    if (category) query.category = category;
    if (city) query['location.city'] = new RegExp(city, 'i');
    if (breaking === 'true') query.isBreaking = true;
    if (featured === 'true') query.isFeatured = true;
    if (search) {
      query.$or = [
        { title: new RegExp(search, 'i') },
        { body: new RegExp(search, 'i') },
        { tags: new RegExp(search, 'i') },
      ];
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const total = await NewsPost.countDocuments(query);

    const posts = await NewsPost.find(query)
      .populate('reporter', 'name avatar')
      .populate('category', 'name slug icon color')
      .select('-likedBy -rejectionReason')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(parseInt(limit));

    res.json({
      success: true,
      total,
      page: parseInt(page),
      pages: Math.ceil(total / parseInt(limit)),
      posts,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/news/:id — single article
const getPost = async (req, res) => {
  try {
    const post = await NewsPost.findOne({ _id: req.params.id, status: 'approved' })
      .populate('reporter', 'name avatar bio')
      .populate('category', 'name slug icon color');

    if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });

    // Increment view count (fire and forget)
    NewsPost.findByIdAndUpdate(post._id, { $inc: { views: 1 } }).exec();

    res.json({ success: true, post });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/news/:id/like
const toggleLike = async (req, res) => {
  try {
    const post = await NewsPost.findById(req.params.id);
    if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });

    const userId = req.user._id;
    const alreadyLiked = post.likedBy.includes(userId);

    if (alreadyLiked) {
      post.likedBy.pull(userId);
      post.likes = Math.max(0, post.likes - 1);
    } else {
      post.likedBy.push(userId);
      post.likes += 1;
    }

    await post.save();
    res.json({ success: true, likes: post.likes, liked: !alreadyLiked });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/news/:id/bookmark
const toggleBookmark = async (req, res) => {
  try {
    const user = req.user;
    const postId = req.params.id;
    const isBookmarked = user.bookmarks.includes(postId);

    if (isBookmarked) {
      await User.findByIdAndUpdate(user._id, { $pull: { bookmarks: postId } });
    } else {
      await User.findByIdAndUpdate(user._id, { $addToSet: { bookmarks: postId } });
    }

    res.json({ success: true, bookmarked: !isBookmarked });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/news/bookmarks — user's saved posts
const getBookmarks = async (req, res) => {
  try {
    const user = await User.findById(req.user._id)
      .populate({
        path: 'bookmarks',
        populate: [
          { path: 'reporter', select: 'name avatar' },
          { path: 'category', select: 'name slug icon color' },
        ],
        match: { status: 'approved' },
      });

    res.json({ success: true, bookmarks: user.bookmarks });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/news/:id/comments
const getComments = async (req, res) => {
  try {
    const comments = await Comment.find({ post: req.params.id, isDeleted: false })
      .populate('user', 'name avatar')
      .sort({ createdAt: -1 })
      .limit(50);
    res.json({ success: true, comments });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/news/:id/comments
const addComment = async (req, res) => {
  try {
    const { text } = req.body;
    if (!text) return res.status(400).json({ success: false, message: 'Comment text required.' });

    const comment = await Comment.create({
      post: req.params.id,
      user: req.user._id,
      text,
    });

    await comment.populate('user', 'name avatar');
    res.status(201).json({ success: true, comment });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { getFeed, getPost, toggleLike, toggleBookmark, getBookmarks, getComments, addComment };