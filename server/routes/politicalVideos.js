const express = require('express');
const {
  getPoliticalFeed,
  triggerIngest,
} = require('../controllers/politicalVideoController');
const { requireCronSecret } = require('../controllers/cronController');

const router = express.Router();

router.get('/feed', getPoliticalFeed);
router.post('/ingest', requireCronSecret, triggerIngest);

module.exports = router;
