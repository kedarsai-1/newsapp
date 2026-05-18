const express = require('express');
const {
  getPoliticalFeed,
  triggerIngest,
} = require('../controllers/politicalVideoController');

const router = express.Router();

router.get('/feed', getPoliticalFeed);
router.post('/ingest', triggerIngest);

module.exports = router;
