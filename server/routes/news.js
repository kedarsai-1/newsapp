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
} = require('../controllers/newsController');
const { optionalProtect } = require('../middleware/authMiddleware');

router.get('/feed', optionalProtect, getFeed);
router.get('/local', optionalProtect, getLocalNews);
router.get('/proxy-image', getProxyImage);
router.get('/extract', extractArticle);
router.get('/bookmarks', optionalProtect, getBookmarks);
router.post('/translate', optionalProtect, translateText);
router.post('/chat', optionalProtect, chatWithNews);
router.get('/:id', optionalProtect, getPost);
router.post('/:id/like', optionalProtect, toggleLike);
router.post('/:id/bookmark', optionalProtect, toggleBookmark);
router.post('/:id/seen', optionalProtect, markPostSeen);
router.get('/:id/comments', getComments);
router.post('/:id/comments', optionalProtect, addComment);

module.exports = router;