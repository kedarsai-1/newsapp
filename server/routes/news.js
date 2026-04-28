const express = require('express');
const router = express.Router();
const {
  getFeed,
  getPost,
  getProxyImage,
  extractArticle,
  toggleLike,
  toggleBookmark,
  getBookmarks,
  getComments,
  addComment,
  translateText,
} = require('../controllers/newsController');
const { optionalProtect } = require('../middleware/authMiddleware');

router.get('/feed', optionalProtect, getFeed);
router.get('/proxy-image', getProxyImage);
router.get('/extract', extractArticle);
router.get('/bookmarks', optionalProtect, getBookmarks);
router.post('/translate', optionalProtect, translateText);
router.get('/:id', getPost);
router.post('/:id/like', optionalProtect, toggleLike);
router.post('/:id/bookmark', optionalProtect, toggleBookmark);
router.get('/:id/comments', getComments);
router.post('/:id/comments', optionalProtect, addComment);

module.exports = router;