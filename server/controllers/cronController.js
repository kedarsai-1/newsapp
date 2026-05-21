const {
  runIngestion,
  getIngestionStatus,
} = require('../services/newsIngestionService');
const { runYoutubeIngestion } = require('../services/youtubeIngestionService');
const { runPoliticalVideoIngestion } = require('../services/politicalVideoIngestionService');
const { purgeOldNews } = require('../services/retentionCleanupService');

function getRequestSecret(req) {
  const auth = req.get('authorization') || '';
  const bearer = auth.toLowerCase().startsWith('bearer ')
    ? auth.slice(7).trim()
    : '';

  const suppliedSecret = (
    bearer
    || req.get('x-cron-secret')
    || req.query?.secret
    || req.body?.secret
    || ''
  );

  return String(suppliedSecret).trim();
}

function requireCronSecret(req, res, next) {
  const configuredSecret = process.env.CRON_SECRET?.trim();

  if (!configuredSecret) {
    return res.status(503).json({
      success: false,
      message: 'CRON_SECRET is not configured.',
    });
  }

  if (getRequestSecret(req) !== configuredSecret) {
    return res.status(401).json({
      success: false,
      message: 'Unauthorized cron request.',
    });
  }

  return next();
}

function sendCronResult(res, result) {
  if (!result?.success && !result?.skipped) {
    return res.status(500).json(result);
  }
  return res.json(result);
}

const runNewsIngestionCron = async (req, res) => {
  try {
    if (process.env.SCRAPER_ENABLED === 'false') {
      return res.json({
        success: true,
        skipped: true,
        message: 'News ingestion disabled by SCRAPER_ENABLED=false.',
      });
    }

    const result = await runIngestion({ triggeredBy: 'api-cron:news' });
    return sendCronResult(res, result);
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

const runYoutubeIngestionCron = async (req, res) => {
  try {
    const result = await runYoutubeIngestion({ triggeredBy: 'api-cron:youtube' });

    if (result?.success && !result?.skipped && (result.stats?.youtubeInserted ?? 0) > 0) {
      req.io?.to('all').emit('feed_updated', {
        inserted: result.stats.youtubeInserted,
        at: new Date(),
      });
    }

    return sendCronResult(res, result);
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

const runPoliticalVideosCron = async (req, res) => {
  try {
    const triggeredBy = 'api-cron:political-videos';

    setImmediate(() => {
      runPoliticalVideoIngestion({ triggeredBy })
        .then((result) => {
          console.log('[political-video] background cron result:', JSON.stringify(result));
        })
        .catch((error) => {
          console.error('[political-video] background cron failed:', error.message);
        });
    });

    return res.status(202).json({
      success: true,
      accepted: true,
      message: 'Political video ingestion started.',
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

const runRetentionCleanupCron = async (req, res) => {
  try {
    if (process.env.RETENTION_ENABLED === 'false') {
      return res.json({
        success: true,
        skipped: true,
        message: 'Retention cleanup disabled by RETENTION_ENABLED=false.',
      });
    }

    const result = await purgeOldNews({
      retentionDays: Number(process.env.RETENTION_DAYS || 7),
      limit: Number(process.env.RETENTION_BATCH || 2000),
      keepManual: true,
      dryRun: process.env.RETENTION_DRY_RUN === 'true',
    });

    console.log(
      `[retention] api-cron: matched=${result.matched} deleted=${result.deletedPosts} cutoff=${result.cutoff.toISOString()}`,
    );

    return res.json(result);
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

const getCronStatus = async (req, res) => {
  try {
    return res.json({
      success: true,
      ingestion: getIngestionStatus(),
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = {
  requireCronSecret,
  runNewsIngestionCron,
  runYoutubeIngestionCron,
  runPoliticalVideosCron,
  runRetentionCleanupCron,
  getCronStatus,
};
