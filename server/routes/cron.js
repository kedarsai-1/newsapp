const express = require('express');
const {
  requireCronSecret,
  runNewsIngestionCron,
  runYoutubeIngestionCron,
  runPoliticalVideosCron,
  runLanguageIngestionCron,
  runRetentionCleanupCron,
  getCronStatus,
} = require('../controllers/cronController');

const router = express.Router();

router.use(requireCronSecret);

router.get('/status', getCronStatus);
router.route('/news-ingestion').get(runNewsIngestionCron).post(runNewsIngestionCron);
router.route('/youtube-ingestion').get(runYoutubeIngestionCron).post(runYoutubeIngestionCron);
router.route('/political-videos').get(runPoliticalVideosCron).post(runPoliticalVideosCron);
router.route('/language-ingestion/:lang').get(runLanguageIngestionCron).post(runLanguageIngestionCron);
router.route('/language-ingestion').get(runLanguageIngestionCron).post(runLanguageIngestionCron);
router.route('/retention-cleanup').get(runRetentionCleanupCron).post(runRetentionCleanupCron);

module.exports = router;
