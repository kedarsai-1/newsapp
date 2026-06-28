const express = require('express');
const router = express.Router();
const {
  getFeed,
  getPost,
  getPostShare,
  getProxyImage,
  extractArticle,
  toggleLike,
  toggleBookmark,
  getBookmarks,
  getFollowingPublishers,
  togglePublisherFollow,
  getComments,
  addComment,
  translateText,
  getLocalNews,
  markPostSeen,
  reportPost,
  chatWithNews,
  getReverseGeocode,
  getForwardGeocode,
} = require('../controllers/newsController');
const { optionalProtect, protect } = require('../middleware/authMiddleware');
const aiRateLimit = require('../middleware/aiRateLimit');
const reportRateLimit = require('../middleware/reportRateLimit');
const {
  requestTimeout,
  translateRequestTimeoutMs,
} = require('../middleware/requestTimeout');

router.get('/feed', optionalProtect, getFeed);
router.get('/local', optionalProtect, getLocalNews);
router.get('/geocode', getReverseGeocode);
router.get('/geocode/forward', getForwardGeocode);
router.get('/proxy-image', getProxyImage);
router.get('/extract', extractArticle);
router.get('/bookmarks', protect, getBookmarks);
router.get('/publishers/following', optionalProtect, getFollowingPublishers);
router.post('/publishers/follow', protect, togglePublisherFollow);
router.post('/translate', optionalProtect, aiRateLimit, requestTimeout(translateRequestTimeoutMs()), translateText);
router.post('/chat', optionalProtect, aiRateLimit, chatWithNews);
router.get('/:id/share', optionalProtect, getPostShare);
router.get('/:id', optionalProtect, getPost);
router.post('/:id/like', optionalProtect, toggleLike);
router.post('/:id/bookmark', protect, toggleBookmark);
router.post('/:id/seen', optionalProtect, markPostSeen);
router.post('/:id/report', optionalProtect, reportRateLimit, reportPost);
router.get('/:id/comments', getComments);
router.post('/:id/comments', optionalProtect, addComment);

module.exports = router;