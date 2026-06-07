const cron = require('node-cron');
const { runIngestion } = require('./newsIngestionService');
const { runYoutubeIngestion } = require('./youtubeIngestionService');
const { runPoliticalVideoIngestion } = require('./politicalVideoIngestionService');
const { runLanguageIngestion, runAllLanguageIngestionParallel } = require('./languageIngestionService');
const { purgeOldNews } = require('./retentionCleanupService');
const { emitFeedUpdated } = require('./feedSocket');
const {
  preloadPoliticalClassifier,
  isMlEnabled,
} = require('./politicalVideoClassifierService');
const { isRailwayHost } = require('../utils/isRailway');
const {
  isPerLanguageIngestEnabled,
  isParallelLanguageIngestEnabled,
  getWorkerLanguages,
  cronForLanguage,
  defaultNewsCronForLanguage,
} = require('../config/ingestLanguages');

let started = false;

async function runScheduledIngestion(triggeredBy, languages) {
  console.log(`[scraper] ingestion start (${triggeredBy}) ${new Date().toISOString()}`);
  const result = await runIngestion({ triggeredBy, languages });
  if (result.skipped) {
    console.log(`[scraper] skipped (${triggeredBy}): ${result.message || 'ingestion already running'}`);
    return;
  }
  if (!result.success) {
    if (result.stats?.timedOut) {
      console.warn('[scraper] time budget hit:', result.error || result.message);
    } else {
      console.error('[scraper] run failed:', result.error || result.message);
    }
    return;
  }
  const s = result.stats || {};
  console.log(
    `[scraper] run completed (${triggeredBy}): langs=${(s.languages || []).join(',')} `
      + `inserted=${s.inserted ?? 0} fetched=${s.fetched ?? 0} `
      + `duplicates=${s.duplicates ?? 0} skippedNoImage=${s.skippedNoImage ?? 0} `
      + `categoryFiltered=${s.categoryFiltered ?? 0} failed=${s.failed ?? 0}`,
  );
  if (s.sourceRuns?.length) {
    console.log('[scraper] details:', JSON.stringify(s.sourceRuns));
  }
}

async function runScheduledYoutube(triggeredBy, languages) {
  console.log(`[youtube] ingestion start (${triggeredBy}) ${new Date().toISOString()}`);
  const result = await runYoutubeIngestion({ triggeredBy, languages });
  if (result.skipped) {
    console.log(`[youtube] skipped (${triggeredBy}): ${result.message || ''}`);
    return;
  }
  if (!result.success) {
    console.error('[youtube] run failed:', result.error);
    return;
  }
  const s = result.stats || {};
  console.log(
    `[youtube] run completed (${triggeredBy}): langs=${(s.languages || []).join(',')} `
      + `inserted=${s.youtubeInserted ?? 0} shorts=${s.youtubeShortsInserted ?? 0} `
      + `fetched=${s.youtubeFetched ?? 0} duplicates=${s.youtubeDuplicates ?? 0} `
      + `restricted=${s.youtubeSkippedRestricted ?? 0}`,
  );
  if ((s.youtubeInserted ?? 0) > 0) {
    emitFeedUpdated({ inserted: s.youtubeInserted, source: 'youtube', at: new Date() });
  }
}

async function runScheduledPoliticalVideo(triggeredBy, languages) {
  console.log(`[political-video] ingestion start (${triggeredBy})`);
  const result = await runPoliticalVideoIngestion({ triggeredBy, languages });
  if (result.skipped) {
    console.log(`[political-video] skipped: ${result.message || ''}`);
    return;
  }
  if (!result.success) {
    console.error('[political-video] failed:', result.error);
    return;
  }
  const s = result.stats || {};
  console.log(
    `[political-video] done: langs=${(s.languages || []).join(',')} saved=${s.saved ?? 0} `
      + `interviews=${s.interviewsSaved ?? 0} shorts=${s.shortsSaved ?? 0} `
      + `keyword=${s.keywordAccepted ?? 0} ml=${s.mlAccepted ?? 0}`,
  );
}

async function runScheduledLanguagePipeline(language, triggeredBy) {
  const result = await runLanguageIngestion(language, { triggeredBy });
  if (!result.success) {
    console.warn(`[ingest:${language}] pipeline issues:`, JSON.stringify(result.stats));
  }
  return result;
}

async function runScheduledAllLanguagesParallel(triggeredBy) {
  const result = await runAllLanguageIngestionParallel({ triggeredBy });
  if (!result.success) {
    console.warn('[ingest] parallel pipeline issues:', JSON.stringify(result.byLang));
  }
  return result;
}

function scheduleParallelLanguagePipelines(isRailway, langs) {
  const cronExpr = process.env.SCRAPER_CRON || '*/5 * * * *';
  const runOnStart = isRailway
    ? process.env.SCRAPER_RUN_ON_START === 'true'
    : process.env.SCRAPER_RUN_ON_START !== 'false';

  cron.schedule(cronExpr, () => {
    runScheduledAllLanguagesParallel('scheduler:parallel').catch((e) =>
      console.error('[ingest] parallel scheduler error:', e),
    );
  });
  console.log(
    `[ingest] parallel pipeline scheduler active cron="${cronExpr}" `
      + `langs=${langs.join(',')} (en + hi + te run together each tick)`,
  );

  if (runOnStart) {
    setTimeout(() => {
      runScheduledAllLanguagesParallel('startup:parallel').catch((e) =>
        console.error('[ingest] parallel startup error:', e),
      );
    }, 2500);
    console.log(`[ingest] parallel startup scheduled for: ${langs.join(', ')}`);
  }
}

function scheduleStaggeredLanguagePipelines(isRailway, langs) {
  const runOnStart = isRailway
    ? process.env.SCRAPER_RUN_ON_START === 'true'
    : process.env.SCRAPER_RUN_ON_START !== 'false';

  for (const lang of langs) {
    const cronExpr = cronForLanguage('SCRAPER_CRON', lang, defaultNewsCronForLanguage);
    cron.schedule(cronExpr, () => {
      runScheduledLanguagePipeline(lang, `scheduler:${lang}`).catch((e) =>
        console.error(`[ingest:${lang}] scheduler error:`, e),
      );
    });
    console.log(
      `[ingest:${lang}] pipeline scheduler active cron="${cronExpr}" `
        + '(staggered — set INGEST_PARALLEL_LANGUAGES=true for parallel)',
    );
  }

  if (runOnStart) {
    setTimeout(async () => {
      console.log(`[ingest] starting startup pipelines sequentially for: ${langs.join(', ')}`);
      for (const lang of langs) {
        try {
          await runScheduledLanguagePipeline(lang, `startup:${lang}`);
        } catch (e) {
          console.error(`[ingest:${lang}] startup error:`, e);
        }
      }
    }, 2500);
    console.log(`[ingest] sequential startup scheduled for: ${langs.join(', ')}`);
  }
}

function schedulePerLanguagePipelines(isRailway) {
  const langs = getWorkerLanguages();
  if (isParallelLanguageIngestEnabled() && langs.length > 1) {
    scheduleParallelLanguagePipelines(isRailway, langs);
    return;
  }
  scheduleStaggeredLanguagePipelines(isRailway, langs);
}

async function runRetention(triggeredBy) {
  try {
    const out = await purgeOldNews({
      retentionDays: Number(process.env.RETENTION_DAYS || 7),
      limit: Number(process.env.RETENTION_BATCH || 2000),
      keepManual: true,
      dryRun: process.env.RETENTION_DRY_RUN === 'true',
    });
    console.log(
      `[retention] ${triggeredBy}: matched=${out.matched} deleted=${out.deletedPosts} cutoff=${out.cutoff.toISOString()}`,
    );
    if (out.matched) {
      console.log(
        `[retention] cloudinary images: attempted=${out.cloudinary.images.attempted} deleted=${out.cloudinary.images.deleted} skipped=${Boolean(out.cloudinary.images.skipped)}`,
      );
      console.log(
        `[retention] cloudinary videos: attempted=${out.cloudinary.videos.attempted} deleted=${out.cloudinary.videos.deleted} skipped=${Boolean(out.cloudinary.videos.skipped)}`,
      );
    }
  } catch (e) {
    console.error('[retention] failed:', e);
  }
}

function scheduleLegacyIngestion(isRailway) {
  const scrapingEnabled = process.env.SCRAPER_ENABLED !== 'false';
  const cronExpr = process.env.SCRAPER_CRON || '*/5 * * * *';
  const runOnStart = isRailway
    ? process.env.SCRAPER_RUN_ON_START === 'true'
    : process.env.SCRAPER_RUN_ON_START !== 'false';

  if (scrapingEnabled) {
    cron.schedule(cronExpr, () => {
      runScheduledIngestion('scheduler').catch((e) =>
        console.error('[scraper] scheduler error:', e),
      );
    });
    console.log(`[scraper] scheduler active with cron "${cronExpr}" (all languages combined)`);

    if (runOnStart) {
      setTimeout(() => {
        runScheduledIngestion('startup').catch((e) =>
          console.error('[scraper] startup ingestion error:', e),
        );
      }, 2500);
      console.log('[scraper] will run ingestion once ~2s after startup');
    }
  } else {
    console.log('[scraper] scheduler disabled by SCRAPER_ENABLED=false');
  }

  const youtubeEnabled = process.env.YOUTUBE_ENABLED !== 'false';
  const youtubeCronExpr = process.env.YOUTUBE_CRON || '0 */6 * * *';
  const youtubeRunOnStart =
    process.env.YOUTUBE_RUN_ON_START === 'true'
    || (!isRailway && process.env.YOUTUBE_RUN_ON_START !== 'false');

  if (youtubeEnabled && process.env.YOUTUBE_API_KEY?.trim()) {
    cron.schedule(youtubeCronExpr, () => {
      runScheduledYoutube('youtube-cron').catch((e) =>
        console.error('[youtube] scheduler error:', e),
      );
    });
    console.log(`[youtube] scheduler active with cron "${youtubeCronExpr}" (all languages)`);
    if (youtubeRunOnStart) {
      setTimeout(() => {
        runScheduledYoutube('youtube-startup').catch((e) =>
          console.error('[youtube] startup error:', e),
        );
      }, 5000);
    }
  } else {
    console.log('[youtube] scheduler disabled (YOUTUBE_ENABLED=false or missing YOUTUBE_API_KEY)');
  }

  const politicalVideoEnabled = process.env.POLITICAL_VIDEO_ENABLED !== 'false';
  const politicalCronExpr = process.env.POLITICAL_VIDEO_CRON || '*/15 * * * *';
  const politicalRunOnStart = process.env.POLITICAL_VIDEO_RUN_ON_START === 'true';

  if (politicalVideoEnabled && process.env.YOUTUBE_API_KEY?.trim()) {
    const mlMode = isMlEnabled()
      ? 'ml+keywords'
      : 'keywords-only (set POLITICAL_ML_ENABLED=true on Railway for MiniLM)';
    const shouldPreload =
      isMlEnabled()
      && (isRailway
        ? process.env.POLITICAL_ML_PRELOAD === 'true'
        : process.env.POLITICAL_ML_PRELOAD !== 'false');
    if (shouldPreload) {
      setTimeout(() => {
        preloadPoliticalClassifier().catch((e) =>
          console.warn('[political-ml] preload failed (will retry on cron):', e.message),
        );
      }, isRailway ? 120_000 : 15_000);
    }
    cron.schedule(politicalCronExpr, () => {
      runScheduledPoliticalVideo('political-cron').catch((e) =>
        console.error('[political-video] cron error:', e),
      );
    });
    console.log(`[political-video] scheduler active (${mlMode}) cron="${politicalCronExpr}"`);
    if (politicalRunOnStart && !isRailway) {
      setTimeout(() => {
        runScheduledPoliticalVideo('political-startup').catch((e) =>
          console.error('[political-video] startup error:', e),
        );
      }, 8000);
    }
  } else {
    console.log('[political-video] disabled');
  }
}

function startCronScheduler() {
  if (started) return;
  started = true;

  const isRailway = isRailwayHost();
  const perLanguage = isPerLanguageIngestEnabled();

  if (perLanguage) {
    console.log(
      `[ingest] per-language mode ON — workers: ${getWorkerLanguages().join(', ')} `
        + `parallel=${isParallelLanguageIngestEnabled() ? 'yes' : 'no (staggered crons)'} `
        + `(set INGEST_WORKER_LANG=en|hi|te for single-language deployment)`,
    );
    if (process.env.SCRAPER_ENABLED !== 'false') {
      schedulePerLanguagePipelines(isRailway);
    } else {
      console.log('[ingest] per-language pipelines disabled by SCRAPER_ENABLED=false');
    }
    if (process.env.POLITICAL_VIDEO_ENABLED !== 'false'
      && process.env.YOUTUBE_API_KEY?.trim()
      && isMlEnabled()
      && (isRailway
        ? process.env.POLITICAL_ML_PRELOAD === 'true'
        : process.env.POLITICAL_ML_PRELOAD !== 'false')) {
      setTimeout(() => {
        preloadPoliticalClassifier().catch((e) =>
          console.warn('[political-ml] preload failed:', e.message),
        );
      }, isRailway ? 120_000 : 15_000);
    }
  } else {
    scheduleLegacyIngestion(isRailway);
  }

  const retentionEnabled = process.env.RETENTION_ENABLED !== 'false';
  const retentionDays = Number(process.env.RETENTION_DAYS || 7);
  const retentionCron = process.env.RETENTION_CRON || '10 3 * * *';
  const retentionRunOnStart = process.env.RETENTION_RUN_ON_START === 'true';

  if (retentionEnabled) {
    cron.schedule(retentionCron, () => runRetention('scheduler'));
    console.log(`[retention] active with cron "${retentionCron}" days=${retentionDays}`);
    if (retentionRunOnStart) {
      setTimeout(() => runRetention('startup'), 4500);
      console.log('[retention] will run once on startup (RETENTION_RUN_ON_START=true)');
    }
  } else {
    console.log('[retention] disabled by RETENTION_ENABLED=false');
  }
}

module.exports = {
  startCronScheduler,
  runScheduledIngestion,
  runScheduledYoutube,
  runScheduledPoliticalVideo,
  runScheduledLanguagePipeline,
  runScheduledAllLanguagesParallel,
  runAllLanguageIngestionParallel,
};
