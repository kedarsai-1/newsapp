const { describe, it, before, beforeEach, afterEach, after } = require('node:test');
const assert = require('node:assert/strict');

// 1. Mock dependencies before requiring cronScheduler
const newsIngestion = require('../../services/newsIngestionService');
const youtubeIngestion = require('../../services/youtubeIngestionService');
const politicalVideoIngestion = require('../../services/politicalVideoIngestionService');
const languageIngestion = require('../../services/languageIngestionService');
const retentionCleanup = require('../../services/retentionCleanupService');
const politicalVideoClassifier = require('../../services/politicalVideoClassifierService');
const isRailwayModule = require('../../utils/isRailway');
const cron = require('node-cron');

// Save original node-cron schedule function
const originalCronSchedule = cron.schedule;

// Mutable mock functions
let mockRunIngestion = async () => ({ success: true, stats: {} });
let mockRunYoutubeIngestion = async () => ({ success: true, stats: {} });
let mockRunPoliticalVideoIngestion = async () => ({ success: true, stats: {} });
let mockRunLanguageIngestion = async () => ({ success: true, stats: {} });
let mockRunAllLanguageIngestionParallel = async () => ({ success: true, stats: {} });
let mockRunRetentionCleanup = async () => ({
  retentionDays: 18,
  news: { matched: 0, deletedPosts: 0, cutoff: new Date(), cloudinary: { images: {}, videos: {} } },
  cloudinaryFolders: { deleted: 0, folders: [] },
  localMedia: { scanned: 0, deleted: 0 },
});
let mockPreloadPoliticalClassifier = async () => {};
let mockIsMlEnabled = () => true;
let mockIsRailwayHost = () => false;

// Attach mock wrappers
newsIngestion.runIngestion = (...args) => mockRunIngestion(...args);
youtubeIngestion.runYoutubeIngestion = (...args) => mockRunYoutubeIngestion(...args);
politicalVideoIngestion.runPoliticalVideoIngestion = (...args) => mockRunPoliticalVideoIngestion(...args);
languageIngestion.runLanguageIngestion = (...args) => mockRunLanguageIngestion(...args);
languageIngestion.runAllLanguageIngestionParallel = (...args) => mockRunAllLanguageIngestionParallel(...args);
retentionCleanup.runRetentionCleanup = (...args) => mockRunRetentionCleanup(...args);
politicalVideoClassifier.preloadPoliticalClassifier = (...args) => mockPreloadPoliticalClassifier(...args);
politicalVideoClassifier.isMlEnabled = (...args) => mockIsMlEnabled(...args);
isRailwayModule.isRailwayHost = () => mockIsRailwayHost();

// Global register to track scheduled jobs
let scheduledJobs = [];
cron.schedule = (expression, callback) => {
  scheduledJobs.push({ expression, callback });
  return { start: () => {}, stop: () => {} };
};

// 2. Require the service under test
const cronScheduler = require('../../services/cronScheduler');

// Reset variables
let originalEnv = {};
let cronSchedulerStateReset = null;

describe('cronScheduler', () => {
  before(() => {
    // Save original env variables
    originalEnv = {
      SCRAPER_ENABLED: process.env.SCRAPER_ENABLED,
      SCRAPER_CRON: process.env.SCRAPER_CRON,
      SCRAPER_RUN_ON_START: process.env.SCRAPER_RUN_ON_START,
      YOUTUBE_ENABLED: process.env.YOUTUBE_ENABLED,
      YOUTUBE_CRON: process.env.YOUTUBE_CRON,
      YOUTUBE_RUN_ON_START: process.env.YOUTUBE_RUN_ON_START,
      YOUTUBE_API_KEY: process.env.YOUTUBE_API_KEY,
      POLITICAL_VIDEO_ENABLED: process.env.POLITICAL_VIDEO_ENABLED,
      POLITICAL_VIDEO_CRON: process.env.POLITICAL_VIDEO_CRON,
      POLITICAL_VIDEO_RUN_ON_START: process.env.POLITICAL_VIDEO_RUN_ON_START,
      RETENTION_ENABLED: process.env.RETENTION_ENABLED,
      RETENTION_CRON: process.env.RETENTION_CRON,
      RETENTION_RUN_ON_START: process.env.RETENTION_RUN_ON_START,
      INGEST_PER_LANGUAGE: process.env.INGEST_PER_LANGUAGE,
      INGEST_PARALLEL_LANGUAGES: process.env.INGEST_PARALLEL_LANGUAGES,
    };
  });

  after(() => {
    // Restore env variables
    for (const key in originalEnv) {
      if (originalEnv[key] === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = originalEnv[key];
      }
    }
    // Restore original node-cron
    cron.schedule = originalCronSchedule;
  });

  beforeEach(() => {
    scheduledJobs = [];
    
    // Clear the internal 'started' flag inside cronScheduler.js module state by altering cache or using a custom reset
    // Wait, cronScheduler exports startCronScheduler, but doesn't export the 'started' variable.
    // In Node.js, we can delete the module from require cache and re-require it to reset its local state!
    const modulePath = require.resolve('../../services/cronScheduler');
    delete require.cache[modulePath];
    // Re-require
    cronSchedulerStateReset = require('../../services/cronScheduler');

    // Default env setup for testing (Legacy mode)
    process.env.SCRAPER_ENABLED = 'true';
    process.env.SCRAPER_CRON = '*/5 * * * *';
    process.env.SCRAPER_RUN_ON_START = 'false';
    process.env.YOUTUBE_ENABLED = 'true';
    process.env.YOUTUBE_CRON = '0 */6 * * *';
    process.env.YOUTUBE_RUN_ON_START = 'false';
    process.env.YOUTUBE_API_KEY = 'mock-youtube-api-key';
    process.env.POLITICAL_VIDEO_ENABLED = 'true';
    process.env.POLITICAL_VIDEO_CRON = '*/15 * * * *';
    process.env.POLITICAL_VIDEO_RUN_ON_START = 'false';
    process.env.RETENTION_ENABLED = 'true';
    process.env.RETENTION_CRON = '10 3 * * *';
    process.env.RETENTION_RUN_ON_START = 'false';
    process.env.INGEST_PER_LANGUAGE = 'false';
    process.env.INGEST_PARALLEL_LANGUAGES = 'false';

    // Mock functions resets
    mockRunIngestion = async () => ({ success: true, stats: {} });
    mockRunYoutubeIngestion = async () => ({ success: true, stats: {} });
    mockRunPoliticalVideoIngestion = async () => ({ success: true, stats: {} });
    mockRunLanguageIngestion = async () => ({ success: true, stats: {} });
    mockRunAllLanguageIngestionParallel = async () => ({ success: true, stats: {} });
    mockRunRetentionCleanup = async () => ({
      retentionDays: 18,
      news: { matched: 0, deletedPosts: 0, cutoff: new Date(), cloudinary: { images: {}, videos: {} } },
      cloudinaryFolders: { deleted: 0, folders: [] },
      localMedia: { scanned: 0, deleted: 0 },
    });
    mockPreloadPoliticalClassifier = async () => {};
    mockIsMlEnabled = () => true;
    mockIsRailwayHost = () => false;
  });

  it('legacy mode: schedules scraping, youtube, politics, and retention', () => {
    cronSchedulerStateReset.startCronScheduler();

    // Verify scheduled counts
    // 1. Scraping: */5 * * * *
    // 2. Youtube: 0 */6 * * *
    // 3. Politics: */15 * * * *
    // 4. Retention: 10 3 * * *
    // 5. Morning brief: 30 1 * * *
    assert.equal(scheduledJobs.length, 5);

    const expressions = scheduledJobs.map(j => j.expression);
    assert.ok(expressions.includes('*/5 * * * *'));
    assert.ok(expressions.includes('0 */6 * * *'));
    assert.ok(expressions.includes('*/15 * * * *'));
    assert.ok(expressions.includes('10 3 * * *'));
    assert.ok(expressions.includes('30 1 * * *'));
  });

  it('legacy mode: triggers callbacks successfully', async () => {
    let ingestionTriggered = false;
    let youtubeTriggered = false;
    let politicalTriggered = false;
    let retentionTriggered = false;

    mockRunIngestion = async () => { ingestionTriggered = true; return { success: true }; };
    mockRunYoutubeIngestion = async () => { youtubeTriggered = true; return { success: true }; };
    mockRunPoliticalVideoIngestion = async () => { politicalTriggered = true; return { success: true }; };
    mockRunRetentionCleanup = async () => {
      retentionTriggered = true;
      return {
        retentionDays: 18,
        news: { matched: 0, deletedPosts: 0, cutoff: new Date(), cloudinary: { images: {}, videos: {} } },
        cloudinaryFolders: { deleted: 0, folders: [] },
        localMedia: { scanned: 0, deleted: 0 },
      };
    };

    cronSchedulerStateReset.startCronScheduler();

    // Trigger all scheduled callbacks
    for (const job of scheduledJobs) {
      await job.callback();
    }

    assert.equal(ingestionTriggered, true);
    assert.equal(youtubeTriggered, true);
    assert.equal(politicalTriggered, true);
    assert.equal(retentionTriggered, true);
  });

  it('per-language mode (parallel): schedules parallel language pipeline cron', () => {
    process.env.INGEST_PER_LANGUAGE = 'true';
    process.env.INGEST_PARALLEL_LANGUAGES = 'true';

    cronSchedulerStateReset.startCronScheduler();

    // 1. Parallel ingest: process.env.SCRAPER_CRON || '*/5 * * * *'
    // 2. Retention: 10 3 * * *
    // 3. Morning brief: 30 1 * * *
    assert.equal(scheduledJobs.length, 3);
    const expressions = scheduledJobs.map((j) => j.expression);
    assert.ok(expressions.includes('*/5 * * * *'));
    assert.ok(expressions.includes('10 3 * * *'));
    assert.ok(expressions.includes('30 1 * * *'));
  });

  it('per-language mode (staggered): schedules separate staggered crons per language', () => {
    process.env.INGEST_PER_LANGUAGE = 'true';
    process.env.INGEST_PARALLEL_LANGUAGES = 'false'; // staggered

    cronSchedulerStateReset.startCronScheduler();

    // 1. Staggered lang crons: en, hi, te
    // 2. Retention: 10 3 * * *
    // 3. Morning brief: 30 1 * * *
    assert.equal(scheduledJobs.length, 5);
    
    // Staggered expressions (15-min offset per language)
    const expressions = scheduledJobs.map(j => j.expression);
    assert.ok(expressions.includes('*/15 * * * *') || expressions.includes('*/5 * * * *')); // English
    assert.ok(expressions.includes('5-59/15 * * * *') || expressions.includes('1-59/5 * * * *')); // Hindi
    assert.ok(expressions.includes('10-59/15 * * * *') || expressions.includes('2-59/5 * * * *')); // Telugu
    assert.ok(expressions.includes('10 3 * * *')); // Retention
    assert.ok(expressions.includes('30 1 * * *')); // Morning brief
  });

  it('disabled scheduler flags suppress respective cron schedules', () => {
    process.env.SCRAPER_ENABLED = 'false';
    process.env.YOUTUBE_ENABLED = 'false';
    process.env.POLITICAL_VIDEO_ENABLED = 'false';
    process.env.RETENTION_ENABLED = 'false';
    process.env.MORNING_BRIEF_ENABLED = 'false';

    cronSchedulerStateReset.startCronScheduler();

    // All should be disabled, so no jobs should be registered!
    assert.equal(scheduledJobs.length, 0);
  });

  it('startCronScheduler prevents duplicate job scheduling on double invocation', () => {
    cronSchedulerStateReset.startCronScheduler();
    const firstRunJobsCount = scheduledJobs.length;

    // Call second time
    cronSchedulerStateReset.startCronScheduler();
    const secondRunJobsCount = scheduledJobs.length;

    // The job list length should remain unchanged
    assert.equal(firstRunJobsCount, secondRunJobsCount);
  });
});
