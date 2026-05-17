const express = require('express');
const sportsRateLimit = require('../middleware/sportsRateLimit');
const {
  getLive,
  getMatch,
  getNews,
  getHighlights,
} = require('../controllers/sportsController');

const router = express.Router();

router.use(sportsRateLimit);

router.get('/live', getLive);
router.get('/news', getNews);
router.get('/highlights', getHighlights);
router.get('/match/:id', getMatch);

module.exports = router;
