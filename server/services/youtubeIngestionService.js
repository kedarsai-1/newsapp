const bcrypt = require('bcryptjs');
const { Prisma, prisma } = require('../config/prisma');
const { canonicalizeUrl, hashUrl, normalizeTitle } = require('../utils/storyDedupe');
const { createNewsPost } = require('../utils/prismaNewsPost');
const {
  getYoutubeSearchPlan,
  getYoutubeChannelsByLanguage,
} = require('../config/youtubeIngestPlan');
const {
  resolveIngestLanguages,
  filterByLanguages,
} = require('../config/ingestLanguages');
const { emitFeedUpdated } = require('./feedSocket');
const {
  isYoutubeQuotaError,
  isYoutubeQuotaBlocked,
  markYoutubeQuotaBlocked,
  formatBlockedUntil,
} = require('../utils/youtubeQuota');

const SYSTEM_REPORTER_EMAIL = process.env.SCRAPER_SYSTEM_EMAIL || 'scraper@newsnow.local';
const SYSTEM_REPORTER_PASSWORD = process.env.SCRAPER_SYSTEM_PASSWORD || 'change_me_123';
const DEFAULT_CATEGORY_SLUG = process.env.YOUTUBE_DEFAULT_CATEGORY
  || process.env.SCRAPER_DEFAULT_CATEGORY
  || 'entertainment';
const SCRAPER_AUTO_APPROVE = process.env.SCRAPER_AUTO_APPROVE !== 'false';
const YOUTUBE_API_BASE = 'https://www.googleapis.com/youtube/v3';

function parseIso8601Duration(iso) {
  const m = String(iso || '').match(
    /PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/,
  );
  if (!m) return null;
  const h = Number(m[1] || 0);
  const min = Number(m[2] || 0);
  const s = Number(m[3] || 0);
  return h * 3600 + min * 60 + s;
}

function thumbnailUrl(videoId) {
  return `https://i.ytimg.com/vi/${videoId}/maxresdefault.jpg`;
}

function watchUrl(videoId) {
  return `https://www.youtube.com/watch?v=${videoId}`;
}

function embedUrl(videoId) {
  return `https://www.youtube.com/embed/${videoId}`;
}

function channelUrl(channelId) {
  if (!channelId) return null;
  return `https://www.youtube.com/channel/${channelId}`;
}

async function youtubeGet(path, params) {
  const key = process.env.YOUTUBE_API_KEY?.trim();
  if (!key) {
    throw new Error('YOUTUBE_API_KEY is not set');
  }
  const qs = new URLSearchParams({ ...params, key });
  const url = `${YOUTUBE_API_BASE}/${path}?${qs.toString()}`;
  const res = await fetch(url, {
    headers: { Accept: 'application/json' },
    signal: AbortSignal.timeout(Number(process.env.YOUTUBE_API_TIMEOUT_MS || 20000)),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = data?.error?.message || res.statusText || `HTTP ${res.status}`;
    const reasons = (data?.error?.errors || []).map((e) => e?.reason).filter(Boolean);
    const err = new Error(`YouTube API ${path}: ${msg}`);
    err.youtubeReasons = reasons;
    throw err;
  }
  return data;
}

function isSearchEnabled() {
  return process.env.YOUTUBE_SEARCH_ENABLED === 'true';
}

function handleYoutubeQuotaHit(stats, context) {
  const until = markYoutubeQuotaBlocked();
  stats.quotaExceeded = true;
  stats.quotaBlockedUntil = until;
  if (!stats.quotaWarned) {
    stats.quotaWarned = true;
    console.warn(
      `[youtube] API quota exceeded${context ? ` (${context})` : ''} — `
        + `pausing all YouTube API calls until ${formatBlockedUntil(until)}. `
        + 'RSS ingestion is unaffected. Set YOUTUBE_SEARCH_ENABLED=false to avoid search quota use.',
    );
  }
}

async function ensureSystemReporter() {
  let reporter = await prisma.user.findUnique({ where: { email: SYSTEM_REPORTER_EMAIL } });
  if (!reporter) {
    reporter = await prisma.user.create({
      data: {
        name: 'News Ingestion Bot',
        email: SYSTEM_REPORTER_EMAIL,
        password: await bcrypt.hash(SYSTEM_REPORTER_PASSWORD, 10),
        role: 'reporter',
        isVerified: true,
      },
    });
  }
  return reporter;
}

async function getCategoryBySlug(slug) {
  let category = await prisma.category.findFirst({
    where: { slug: slug || DEFAULT_CATEGORY_SLUG, isActive: true },
    orderBy: { order: 'asc' },
  });
  if (!category) {
    category = await prisma.category.findFirst({
      where: { isActive: true },
      orderBy: [{ order: 'asc' }, { createdAt: 'asc' }],
    });
  }
  if (!category) {
    throw new Error('No active category found. Seed categories before running YouTube ingestion.');
  }
  return category;
}

async function isYoutubeDuplicate(videoId, item) {
  if (videoId) {
    if (await prisma.newsPost.findFirst({ where: { youtubeVideoId: videoId }, select: { id: true } })) return true;
  }
  const canonical = canonicalizeUrl(item?.sourceUrl || watchUrl(videoId));
  if (canonical) {
    const sourceUrlHash = hashUrl(canonical);
    if (await prisma.newsPost.findFirst({ where: { sourceUrlHash }, select: { id: true } })) return true;
  }
  return false;
}

function buildYoutubeMeta(videoId, snippet, status, contentDetails) {
  const durationSeconds = parseIso8601Duration(contentDetails?.duration);
  const channelId = snippet?.channelId || null;
  return {
    videoId,
    channelId,
    channelTitle: snippet?.channelTitle || 'YouTube',
    embedUrl: embedUrl(videoId),
    watchUrl: watchUrl(videoId),
    channelUrl: channelUrl(channelId),
    durationSeconds,
    isShort: durationSeconds != null && durationSeconds > 0 && durationSeconds <= 60,
    embeddable: status?.embeddable !== false,
    privacyStatus: status?.privacyStatus || 'public',
  };
}

function normalizeFromVideoResource(
  videoId,
  snippet,
  status,
  contentDetails,
  categorySlug,
  language = 'en',
) {
  const title = String(snippet?.title || '').trim();
  if (!title || title.toLowerCase() === 'private video' || title.toLowerCase() === 'deleted video') {
    return null;
  }
  const youtube = buildYoutubeMeta(videoId, snippet, status, contentDetails);
  if (!youtube.embeddable || youtube.privacyStatus !== 'public') {
    return { skip: 'restricted' };
  }
  const desc = String(snippet?.description || '').trim();
  const publishedAt = snippet?.publishedAt ? new Date(snippet.publishedAt) : new Date();
  const channelTitle = youtube.channelTitle;
  return {
    title: title.slice(0, 200),
    body: desc.slice(0, 2000) || title,
    summary: desc.slice(0, 280) || null,
    sourceUrl: youtube.watchUrl,
    sourcePublishedAt: publishedAt,
    sourceType: 'youtube',
    language: String(language || 'en').toLowerCase(),
    categorySlug,
    youtube,
    mediaUrl: thumbnailUrl(videoId),
    tags: ['youtube', categorySlug, language].filter(Boolean),
  };
}

async function fetchVideoDetails(videoIds) {
  if (!videoIds.length) return new Map();
  const out = new Map();
  const chunkSize = 50;
  for (let i = 0; i < videoIds.length; i += chunkSize) {
    const chunk = videoIds.slice(i, i + chunkSize);
    // eslint-disable-next-line no-await-in-loop
    const data = await youtubeGet('videos', {
      part: 'snippet,status,contentDetails',
      id: chunk.join(','),
    });
    for (const v of data.items || []) {
      if (v?.id) out.set(v.id, v);
    }
  }
  return out;
}

async function searchVideos(query, maxResults, relevanceLanguage = 'en') {
  const lang = String(relevanceLanguage || 'en').toLowerCase();
  const data = await youtubeGet('search', {
    part: 'snippet',
    type: 'video',
    q: query,
    order: 'date',
    regionCode: process.env.YOUTUBE_REGION_CODE || 'IN',
    relevanceLanguage: lang,
    maxResults: String(Math.min(50, Math.max(1, maxResults))),
    safeSearch: 'strict',
  });
  const ids = (data.items || [])
    .map((it) => it?.id?.videoId)
    .filter(Boolean);
  const details = await fetchVideoDetails(ids);
  const results = [];
  for (const id of ids) {
    const v = details.get(id);
    if (!v?.snippet) continue;
    results.push({
      videoId: id,
      snippet: v.snippet,
      status: v.status,
      contentDetails: v.contentDetails,
    });
  }
  return results;
}

async function getUploadsPlaylistId(channelId) {
  const data = await youtubeGet('channels', {
    part: 'contentDetails',
    id: channelId,
  });
  const ch = data.items?.[0];
  return ch?.contentDetails?.relatedPlaylists?.uploads || null;
}

async function fetchChannelUploads(channelId, maxResults) {
  const uploadsPlaylistId = await getUploadsPlaylistId(channelId);
  if (!uploadsPlaylistId) return [];
  const data = await youtubeGet('playlistItems', {
    part: 'snippet',
    playlistId: uploadsPlaylistId,
    maxResults: String(Math.min(50, Math.max(1, maxResults))),
  });
  const ids = (data.items || [])
    .map((it) => it?.snippet?.resourceId?.videoId)
    .filter(Boolean);
  const details = await fetchVideoDetails(ids);
  const results = [];
  for (const id of ids) {
    const v = details.get(id);
    if (!v?.snippet) continue;
    results.push({
      videoId: id,
      snippet: v.snippet,
      status: v.status,
      contentDetails: v.contentDetails,
    });
  }
  return results;
}

function toYoutubePostDoc(item, reporterId, categoryId, sourceName) {
  const y = item.youtube;
  const thumb = item.mediaUrl || thumbnailUrl(y.videoId);
  return {
    title: item.title.slice(0, 200),
    body: item.body || item.title,
    summary: item.summary,
    reporterId,
    categoryId,
    media: [{
      type: 'video',
      url: y.watchUrl,
      thumbnail: thumb,
      duration: y.durationSeconds,
    }],
    status: SCRAPER_AUTO_APPROVE ? 'approved' : 'pending',
    approvedAt: SCRAPER_AUTO_APPROVE ? new Date() : null,
    tags: item.tags || ['youtube'],
    language: item.language || 'en',
    sourceName,
    sourceUrl: y.watchUrl,
    sourceUrlHash: (() => {
      const c = canonicalizeUrl(y.watchUrl);
      return c ? hashUrl(c) : null;
    })(),
    titleNormalized: normalizeTitle(item.title) || null,
    sourcePublishedAt: item.sourcePublishedAt ? new Date(item.sourcePublishedAt) : null,
    sourceType: 'youtube',
    youtube: y,
    scrapedAt: new Date(),
    scrapeConfidence: 0.95,
  };
}

async function insertNormalizedItem(item, reporter, stats) {
  const normalized = normalizeFromVideoResource(
    item.videoId,
    item.snippet,
    item.status,
    item.contentDetails,
    item.categorySlug || DEFAULT_CATEGORY_SLUG,
    item.language || 'en',
  );
  if (!normalized) return false;
  if (normalized.skip === 'restricted') {
    stats.youtubeSkippedRestricted += 1;
    return false;
  }

  if (await isYoutubeDuplicate(normalized.youtube.videoId, normalized)) {
    stats.youtubeDuplicates += 1;
    return false;
  }

  const category = await getCategoryBySlug(normalized.categorySlug);
  const label = `YouTube · ${normalized.youtube.channelTitle}`;
  const doc = toYoutubePostDoc(normalized, reporter.id, category.id, label);
  try {
    await createNewsPost(doc);
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
      stats.youtubeDuplicates += 1;
      return false;
    }
    throw error;
  }
  stats.youtubeInserted += 1;
  stats.inserted += 1;
  if (normalized.youtube?.isShort) {
    stats.youtubeShortsInserted += 1;
  }
  return true;
}

/**
 * Ingest YouTube videos via Data API (metadata only — no video download).
 */
async function runYoutubeIngestion({ triggeredBy = 'youtube', languages } = {}) {
  const activeLanguages = resolveIngestLanguages({ languages });
  const stats = {
    triggeredBy,
    languages: activeLanguages,
    youtubeFetched: 0,
    youtubeInserted: 0,
    youtubeShortsInserted: 0,
    youtubeDuplicates: 0,
    youtubeSkippedRestricted: 0,
    youtubeFailed: 0,
    inserted: 0,
    sourceRuns: [],
  };

  if (process.env.YOUTUBE_ENABLED === 'false') {
    return { success: true, skipped: true, message: 'YouTube ingestion disabled', stats };
  }
  if (!process.env.YOUTUBE_API_KEY?.trim()) {
    return { success: false, error: 'YOUTUBE_API_KEY is not set', stats };
  }

  if (isYoutubeQuotaBlocked()) {
    return {
      success: true,
      skipped: true,
      message: 'YouTube API quota cooldown active',
      stats: { ...stats, quotaSkipped: true },
    };
  }

  const searchPerCategory = Math.min(
    25,
    Math.max(3, Number(process.env.YOUTUBE_SEARCH_PER_CATEGORY || 8)),
  );
  const channelMax = Math.min(
    25,
    Math.max(3, Number(process.env.YOUTUBE_CHANNEL_MAX_PER_RUN || 10)),
  );
  const targetInsertsPerSource = Math.max(
    1,
    Number(process.env.YOUTUBE_INSERTS_PER_SOURCE || 3),
  );

  try {
    const reporter = await ensureSystemReporter();
    const channels = filterByLanguages(
      getYoutubeChannelsByLanguage(),
      activeLanguages,
    );
    let quotaHit = false;

    console.log(
      `[youtube] begin (${triggeredBy}) langs=${activeLanguages.join(',')} channels=${channels.length}`,
    );

    for (const { channelId, language, categorySlug: channelCategorySlug } of channels) {
      if (quotaHit) break;
      let insertedFromChannel = 0;
      try {
        const videos = await fetchChannelUploads(channelId, channelMax);
        stats.youtubeFetched += videos.length;
        for (const v of videos) {
          if (insertedFromChannel >= targetInsertsPerSource) break;
          try {
            // eslint-disable-next-line no-await-in-loop
            const ok = await insertNormalizedItem(
              {
                ...v,
                categorySlug: channelCategorySlug || DEFAULT_CATEGORY_SLUG,
                language,
              },
              reporter,
              stats,
            );
            if (ok) insertedFromChannel += 1;
          } catch (e) {
            stats.youtubeFailed += 1;
            console.warn(`[youtube] channel ${channelId} item failed:`, e?.message || e);
          }
        }
        stats.sourceRuns.push({
          source: `YouTube:channel:${channelId}:${language}`,
          mode: 'youtube',
          count: videos.length,
          success: true,
        });
      } catch (e) {
        if (isYoutubeQuotaError(e)) {
          handleYoutubeQuotaHit(stats, `channel ${channelId}`);
          quotaHit = true;
          stats.sourceRuns.push({
            source: `YouTube:channel:${channelId}:${language}`,
            success: false,
            error: 'quotaExceeded',
          });
          break;
        }
        stats.youtubeFailed += 1;
        stats.sourceRuns.push({
          source: `YouTube:channel:${channelId}:${language}`,
          success: false,
          error: e.message,
        });
        console.warn(`[youtube] channel ${channelId} failed:`, e.message);
      }
    }

    if (isSearchEnabled() && !quotaHit) {
      const plans = filterByLanguages(getYoutubeSearchPlan(), activeLanguages);
      for (const plan of plans) {
        if (quotaHit) break;
        let insertedFromSearch = 0;
        try {
          const videos = await searchVideos(
            plan.query,
            searchPerCategory,
            plan.language || 'en',
          );
          stats.youtubeFetched += videos.length;
          for (const v of videos) {
            if (insertedFromSearch >= targetInsertsPerSource) break;
            try {
              // eslint-disable-next-line no-await-in-loop
              const ok = await insertNormalizedItem(
                {
                  ...v,
                  categorySlug: plan.categorySlug,
                  language: plan.language || 'en',
                },
                reporter,
                stats,
              );
              if (ok) insertedFromSearch += 1;
            } catch (e) {
              stats.youtubeFailed += 1;
              console.warn(`[youtube] search "${plan.query}" item failed:`, e?.message || e);
            }
          }
          stats.sourceRuns.push({
            source: `YouTube:search:${plan.categorySlug}:${plan.language || 'en'}`,
            mode: 'youtube',
            count: videos.length,
            success: true,
          });
        } catch (e) {
          if (isYoutubeQuotaError(e)) {
            handleYoutubeQuotaHit(stats, `search "${plan.query}"`);
            quotaHit = true;
            stats.sourceRuns.push({
              source: `YouTube:search:${plan.categorySlug}`,
              success: false,
              error: 'quotaExceeded',
            });
            break;
          }
          stats.youtubeFailed += 1;
          stats.sourceRuns.push({
            source: `YouTube:search:${plan.categorySlug}`,
            success: false,
            error: e.message,
          });
          console.warn(`[youtube] search "${plan.query}" failed:`, e.message);
        }
      }
    } else if (!isSearchEnabled()) {
      stats.youtubeSearchSkipped = true;
    }

    console.log(
      `[youtube] done (${triggeredBy}): langs=${activeLanguages.join(',')} `
        + `fetched=${stats.youtubeFetched} inserted=${stats.youtubeInserted} `
        + `shorts=${stats.youtubeShortsInserted} duplicates=${stats.youtubeDuplicates} `
        + `restricted=${stats.youtubeSkippedRestricted} failed=${stats.youtubeFailed}`,
    );
    if (stats.youtubeInserted > 0) {
      emitFeedUpdated({ inserted: stats.youtubeInserted, at: new Date() });
    }
    return { success: true, stats };
  } catch (error) {
    return { success: false, error: error.message, stats };
  }
}

module.exports = {
  runYoutubeIngestion,
  parseIso8601Duration,
  thumbnailUrl,
  watchUrl,
  embedUrl,
};
