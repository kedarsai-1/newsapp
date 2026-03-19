const express = require('express');
const router = express.Router();
const {
  getFeed,
  getPost,
  toggleLike,
  toggleBookmark,
  getBookmarks,
  getComments,
  addComment,
} = require('../controllers/newsController');
const { protect } = require('../middleware/authMiddleware');

router.get('/feed', getFeed);
router.get('/bookmarks', protect, getBookmarks);
router.get('/:id', getPost);
router.post('/:id/like', protect, toggleLike);
router.post('/:id/bookmark', protect, toggleBookmark);
router.get('/:id/comments', getComments);
router.post('/:id/comments', protect, addComment);

module.exports = router;