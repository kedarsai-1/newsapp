const express = require('express');
const router = express.Router();
const {
  createPost,
  getMyPosts,
  updatePost,
  deleteMedia,
  getStats,
} = require('../controllers/reporterController');
const { protect, authorize } = require('../middleware/authMiddleware');
const { uploadMixed } = require('../config/cloudinary');

// All reporter routes require authentication and reporter role
router.use(protect, authorize('reporter', 'admin'));

router.get('/stats', getStats);
router.get('/posts', getMyPosts);
router.post('/posts', uploadMixed.array('media', 10), createPost);
router.put('/posts/:id', uploadMixed.array('media', 10), updatePost);
router.delete('/posts/:id/media/:mediaId', deleteMedia);

module.exports = router;