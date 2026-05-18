/**
 * Political YouTube ingestion pipeline:
 * fetch → keyword → blacklist → MiniLM (uncertain only) → save political videos.
 */
const PoliticalVideo = require('../models/PoliticalVideo');
const NewsPost = require('../models/NewsPost');
const User = require('../models/User');
const Category = require('../models/Category');
const { getPoliticalYoutubeChannels } = require('../config/politicalVideoConfig');
const { classifyByKeywords, isPoliticalLabel } = require('../utils/politicalKeywordFilter');
const {
  preloadPoliticalClassifier,
  classifyVideosBatch,
} = require('./politicalVideoClassifierService');
const {
  fetchLatestFromChannels,
  filterEmbeddableVideos,
} = require('./youtubePoliticsFetchService');
const { thumbnailUrl, watchUrl, embedUrl } = require('./youtubeIngestionService');
const { emitFeedUpdated } = require('./feedSocket');
const { hashUrl, canonicalizeUrl, normalizeTitle } = require('../utils/storyDedupe');
const { isYoutubeQuotaBlocked } = require('../utils/youtubeQuota');

const SYSTEM_REPORTER_EMAIL = process.env.SCRAPER_SYSTEM_EMAIL || 'scraper@newsnow.local';
const SYSTEM_REPORTER_PASSWORD = process.env.SCRAPER_SYSTEM_PASSWORD || 'change_me_123';
const SCRAPER_AUTO_APPROVE = process.env.SCRAPER_AUTO_APPROVE !== 'false';

let ingestRunning = false;

async function ensureSystemReporter() {
  let reporter = await User.findOne({ email: SYSTEM_REPORTER_EMAIL });
  if (!reporter) {
    reporter = await User.create({
      name: 'Political Video Bot',
      email: SYSTEM_REPORTER_EMAIL,
      password: SYSTEM_REPORTER_PASSWORD,
      role: 'reporter',
      isVerified: true,
    });
  }
  return reporter;
}

async function getPoliticsCategory() {
  let cat = await Category.findOne({ slug: 'politics', isActive: true });
  if (!cat) {
    cat = await Category.findOne({ isActive: true }).sort({ order: 1 });
  }
  if (!cat) throw new Error('No active category. Seed categories first.');
  return cat;
}

async function existsVideo(videoId) {
  if (await PoliticalVideo.exists({ videoId })) return true;
  if (await NewsPost.exists({ 'youtube.videoId': videoId })) return true;
  return false;
}

async function savePoliticalVideo(video, classification) {
  const category = await getPoliticsCategory();
  const reporter = await ensureSystemReporter();

  const youtube = {
    videoId: video.videoId,
    channelId: video.channelId,
    channelTitle: video.channelName,
    embedUrl: embedUrl(video.videoId),
    watchUrl: watchUrl(video.videoId),
    channelUrl: video.channelId ? `https://www.youtube.com/channel/${video.channelId}` : null,
    durationSeconds: null,
    isShort: false,
    embeddable: true,
    privacyStatus: 'public',
  };

  const thumb = video.thumbnail || thumbnailUrl(video.videoId);
  const canonical = canonicalizeUrl(youtube.watchUrl);

  const newsDoc = {
    title: video.title,
    body: (video.description || video.title).slice(0, 2000),
    summary: (video.description || '').slice(0, 280) || null,
    reporter: reporter._id,
    category: category._id,
    media: [{
      type: 'video',
      url: youtube.watchUrl,
      thumbnail: thumb,
    }],
    status: SCRAPER_AUTO_APPROVE ? 'approved' : 'pending',
    approvedAt: SCRAPER_AUTO_APPROVE ? new Date() : null,
    tags: ['youtube', 'politics', classification.category].filter(Boolean),
    language: classification.language || video.language || 'en',
    sourceName: `YouTube · ${video.channelName}`,
    sourceUrl: youtube.watchUrl,
    sourceUrlHash: canonical ? hashUrl(canonical) : null,
    titleNormalized: normalizeTitle(video.title) || null,
    sourcePublishedAt: video.publishedAt,
    sourceType: 'youtube',
    youtube,
    videoCategory: classification.category,
    videoClassificationMethod: classification.method,
    videoClassificationScore: classification.confidence,
    politicsScope: 'india',
    scrapedAt: new Date(),
    scrapeConfidence: classification.confidence,
  };

  const post = await NewsPost.create(newsDoc);

  await PoliticalVideo.findOneAndUpdate(
    { videoId: video.videoId },
    {
      videoId: video.videoId,
      title: video.title,
      thumbnail: thumb,
      channelName: video.channelName,
      channelId: video.channelId,
      language: classification.language || video.language || 'en',
      publishedAt: video.publishedAt,
      category: classification.category,
      classificationMethod: classification.method,
      classificationScore: classification.confidence,
      description: (video.description || '').slice(0, 500),
      newsPostId: post._id,
    },
    { upsert: true, new: true },
  );

  return post;
}

async function runPoliticalVideoIngestion({ triggeredBy = 'political-cron' } = {}) {
  if (ingestRunning) {
    return { success: false, skipped: true, message: 'Political ingestion already running' };
  }
  if (process.env.POLITICAL_VIDEO_ENABLED === 'false') {
    return { success: true, skipped: true, message: 'Political video ingestion disabled' };
  }
  if (!process.env.YOUTUBE_API_KEY?.trim()) {
    return { success: false, error: 'YOUTUBE_API_KEY is not set' };
  }
  if (isYoutubeQuotaBlocked()) {
    return { success: true, skipped: true, message: 'YouTube quota cooldown' };
  }

  ingestRunning = true;
  const stats = {
    triggeredBy,
    fetched: 0,
    keywordAccepted: 0,
    mlClassified: 0,
    mlAccepted: 0,
    rejected: 0,
    duplicates: 0,
    saved: 0,
    blacklisted: 0,
    uncertain: 0,
  };

  try {
    if (process.env.POLITICAL_ML_ENABLED !== 'false') {
      await preloadPoliticalClassifier();
    }

    const channels = getPoliticalYoutubeChannels();
    const maxPerChannel = Math.min(
      25,
      Math.max(5, Number(process.env.POLITICAL_VIDEOS_PER_CHANNEL || 12)),
    );

    let candidates = await fetchLatestFromChannels(channels, maxPerChannel);
    stats.fetched = candidates.length;

    const fresh = [];
    for (const v of candidates) {
      // eslint-disable-next-line no-await-in-loop
      if (await existsVideo(v.videoId)) {
        stats.duplicates += 1;
      } else {
        fresh.push(v);
      }
    }

    const toEmbedCheck = [];
    const keywordAccepted = [];
    const uncertain = [];

    for (const video of fresh) {
      const kw = classifyByKeywords(video);
      if (kw.stage === 'reject') {
        stats.rejected += 1;
        if (kw.reason === 'blacklist') stats.blacklisted += 1;
        continue;
      }
      if (kw.stage === 'accept') {
        keywordAccepted.push({ video, classification: kw });
        stats.keywordAccepted += 1;
        toEmbedCheck.push(video);
      } else if (kw.stage === 'uncertain') {
        uncertain.push({ ...video, language: kw.language });
        stats.uncertain += 1;
      }
    }

    let mlAccepted = [];
    if (uncertain.length && process.env.POLITICAL_ML_ENABLED !== 'false') {
      stats.mlClassified = uncertain.length;
      const mlResults = await classifyVideosBatch(uncertain);
      for (const r of mlResults) {
        if (r.accepted && isPoliticalLabel(r.category)) {
          mlAccepted.push({
            video: r,
            classification: {
              category: r.category,
              method: 'ml',
              confidence: r.confidence,
              language: r.language,
            },
          });
          stats.mlAccepted += 1;
          toEmbedCheck.push(r);
        } else {
          stats.rejected += 1;
        }
      }
    } else {
      stats.rejected += uncertain.length;
    }

    const embeddable = await filterEmbeddableVideos(toEmbedCheck);
    const embeddableIds = new Set(embeddable.map((v) => v.videoId));

    const toSave = [
      ...keywordAccepted.filter((x) => embeddableIds.has(x.video.videoId)),
      ...mlAccepted.filter((x) => embeddableIds.has(x.video.videoId)),
    ];

    for (const row of toSave) {
      try {
        // eslint-disable-next-line no-await-in-loop
        await savePoliticalVideo(row.video, row.classification);
        stats.saved += 1;
      } catch (e) {
        console.warn('[political-video] save failed:', e.message);
      }
    }

    console.log(
      `[political-video] done (${triggeredBy}): fetched=${stats.fetched} saved=${stats.saved} `
        + `keyword=${stats.keywordAccepted} ml=${stats.mlAccepted} dup=${stats.duplicates} `
        + `rejected=${stats.rejected}`,
    );

    if (stats.saved > 0) {
      emitFeedUpdated({ inserted: stats.saved, type: 'political-video', at: new Date() });
    }

    return { success: true, stats };
  } catch (e) {
    console.error('[political-video] ingestion error:', e.message);
    return { success: false, error: e.message, stats };
  } finally {
    ingestRunning = false;
  }
}

module.exports = {
  runPoliticalVideoIngestion,
};
