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
  getLocalNews,
  markPostSeen,
  chatWithNews,
  getReverseGeocode,
} = require('../controllers/newsController');
const { optionalProtect } = require('../middleware/authMiddleware');
const aiRateLimit = require('../middleware/aiRateLimit');
const {
  requestTimeout,
  chatRequestTimeoutMs,
  translateRequestTimeoutMs,
} = require('../middleware/requestTimeout');

router.get('/feed', optionalProtect, getFeed);
router.get('/local', optionalProtect, getLocalNews);
router.get('/geocode', getReverseGeocode);
router.get('/proxy-image', getProxyImage);
router.get('/extract', extractArticle);
router.get('/bookmarks', optionalProtect, getBookmarks);
router.post('/translate', optionalProtect, aiRateLimit, requestTimeout(translateRequestTimeoutMs()), translateText);
router.post('/chat', optionalProtect, aiRateLimit, requestTimeout(chatRequestTimeoutMs()), chatWithNews);
router.get('/:id', optionalProtect, getPost);
router.post('/:id/like', optionalProtect, toggleLike);
router.post('/:id/bookmark', optionalProtect, toggleBookmark);
router.post('/:id/seen', optionalProtect, markPostSeen);
router.get('/:id/comments', getComments);
router.post('/:id/comments', optionalProtect, addComment);

module.exports = router;