/**
 * Runs the full language pipeline: RSS/API news → YouTube (shorts) → political (interviews).
 */
const { normalizeLanguage } = require('../config/ingestLanguages');
const { runIngestion } = require('./newsIngestionService');
const { runYoutubeIngestion } = require('./youtubeIngestionService');
const { runPoliticalVideoIngestion } = require('./politicalVideoIngestionService');

async function runLanguageIngestion(language, { triggeredBy = 'language-pipeline' } = {}) {
  const lang = normalizeLanguage(language);
  if (!lang) {
    return { success: false, error: 'language is required (en, hi, or te)' };
  }

  const baseTrigger = `${triggeredBy}:${lang}`;
  console.log(`[ingest:${lang}] pipeline start (${baseTrigger}) ${new Date().toISOString()}`);

  const news = await runIngestion({
    languages: [lang],
    triggeredBy: `${baseTrigger}:news`,
    includeYoutube: false,
    includePolitical: false,
  });

  const youtube = await runYoutubeIngestion({
    languages: [lang],
    triggeredBy: `${baseTrigger}:youtube`,
  });

  const political = await runPoliticalVideoIngestion({
    languages: [lang],
    triggeredBy: `${baseTrigger}:political`,
  });

  const success = (news.success || news.skipped)
    && (youtube.success || youtube.skipped)
    && (political.success || political.skipped);

  const summary = {
    language: lang,
    triggeredBy: baseTrigger,
    news: {
      success: news.success,
      skipped: news.skipped,
      inserted: news.stats?.inserted ?? 0,
      fetched: news.stats?.fetched ?? 0,
    },
    youtube: {
      success: youtube.success,
      skipped: youtube.skipped,
      inserted: youtube.stats?.youtubeInserted ?? 0,
      shorts: youtube.stats?.youtubeShortsInserted ?? 0,
    },
    political: {
      success: political.success,
      skipped: political.skipped,
      saved: political.stats?.saved ?? 0,
      interviews: political.stats?.interviewsSaved ?? 0,
    },
  };

  console.log(
    `[ingest:${lang}] pipeline done: news +${summary.news.inserted} `
      + `youtube +${summary.youtube.inserted} (shorts ${summary.youtube.shorts}) `
      + `political +${summary.political.saved} (interviews ${summary.political.interviews})`,
  );

  return { success, stats: summary, news, youtube, political };
}

module.exports = { runLanguageIngestion };
