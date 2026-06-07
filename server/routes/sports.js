const express = require('express');
const sportsRateLimit = require('../middleware/sportsRateLimit');
const {
  getLive,
  getMatch,
  getNews,
  voteMatchPoll,
  getLeaderboard,
} = require('../controllers/sportsController');
const { protect, optionalProtect } = require('../middleware/authMiddleware');

const router = express.Router();

router.use(sportsRateLimit);

router.get('/live', getLive);
router.get('/news', getNews);
router.get('/leaderboard', optionalProtect, getLeaderboard);
router.get('/match/:id', optionalProtect, getMatch);
router.post('/match/:id/poll/vote', protect, voteMatchPoll);

module.exports = router;
