/**
 * In-process TTL cache for public read APIs (single Node instance / Contabo VPS).
 * Invalidated when cron ingest emits feed_updated.
 */
const cacheService = require('./cacheService');

const FEED_PREFIX = 'feed:';
const POST_PREFIX = 'post:';
const POLITICAL_FEED_PREFIX = 'political-feed:';
const CATEGORIES_KEY = 'categories:active';

function feedCacheEnabled() {
  return process.env.FEED_CACHE_ENABLED !== 'false';
}

function feedTtlMs() {
  return Math.max(5000, Number(process.env.FEED_CACHE_TTL_MS || 45_000));
}

function feedTtlForQuery(query = {}) {
  if (
    String(query.hasVideo || '').toLowerCase() === 'true'
    && String(query.sourceTypes || '').toLowerCase() === 'youtube'
  ) {
    return Math.max(30_000, Number(process.env.SHORTS_FEED_CACHE_TTL_MS || 180_000));
  }
  const lang = String(query.language || '').toLowerCase();
  if (lang === 'hi' || lang === 'te') {
    return Math.max(5000, Number(process.env.FEED_INDIC_CACHE_TTL_MS || 90_000));
  }
  return feedTtlMs();
}

function categoriesTtlMs() {
  return Math.max(60_000, Number(process.env.CATEGORIES_CACHE_TTL_MS || 300_000));
}

function postTtlMs() {
  return Math.max(10_000, Number(process.env.POST_CACHE_TTL_MS || 120_000));
}

function politicalFeedTtlMs() {
  return Math.max(5000, Number(process.env.POLITICAL_FEED_CACHE_TTL_MS || 45_000));
}

function maxCachedFeedPage() {
  return Math.max(1, Number(process.env.FEED_CACHE_MAX_PAGE || 3));
}

const FEED_CACHE_PARAMS = new Set([
  'page',
  'limit',
  'language',
  'category',
  'city',
  'constituency',
  'politicsScope',
  'breaking',
  'featured',
  'days',
  'sourceTypes',
  'hasVideo',
  'politicalOnly',
  'excludePolitics',
  'sort',
  'following',
  'publisher',
  'publishers',
]);

function normalizeFeedCacheValue(key, value) {
  const str = String(value).trim();
  if (!str) return null;
  if (str === 'false' || str === '0') return null;
  if (key === 'limit') {
    const n = parseInt(str, 10);
    return Number.isFinite(n) && n > 0 ? String(Math.min(n, 50)) : '20';
  }
  if (key === 'page') {
    const n = parseInt(str, 10);
    return Number.isFinite(n) && n > 0 ? String(n) : '1';
  }
  return str;
}

/** Stable cache key from whitelisted feed query params. */
function feedCacheKey(query = {}) {
  const normalized = {};
  for (const [k, v] of Object.entries(query)) {
    if (!FEED_CACHE_PARAMS.has(k)) continue;
    const normalizedValue = normalizeFeedCacheValue(k, v);
    if (!normalizedValue) continue;
    normalized[k] = normalizedValue;
  }
  const parts = Object.keys(normalized).sort().map((k) => `${k}=${normalized[k]}`);
  return `${FEED_PREFIX}${parts.join('&')}`;
}

function shouldCacheFeedQuery(query = {}) {
  if (!feedCacheEnabled()) return false;
  if (query.search && String(query.search).trim()) return false;
  const page = parseInt(query.page, 10) || 1;
  if (page > maxCachedFeedPage()) return false;
  return true;
}

async function getCachedFeed(query) {
  if (!shouldCacheFeedQuery(query)) return null;
  const entry = await cacheService.get(feedCacheKey(query));
  if (!entry?.body) return null;
  return entry;
}

async function setCachedFeed(query, body) {
  if (!shouldCacheFeedQuery(query)) return;
  const ttlMs = feedTtlForQuery(query);
  await cacheService.set(feedCacheKey(query), { body, ttlMs }, ttlMs);
}

async function getCachedCategories() {
  return await cacheService.get(CATEGORIES_KEY);
}

async function setCachedCategories(body) {
  const ttlMs = categoriesTtlMs();
  await cacheService.set(CATEGORIES_KEY, { body, ttlMs }, ttlMs);
}

async function getCachedPost(id) {
  return await cacheService.get(`${POST_PREFIX}${id}`);
}

async function setCachedPost(id, body) {
  if (process.env.POST_CACHE_ENABLED === 'false') return;
  const ttlMs = postTtlMs();
  await cacheService.set(`${POST_PREFIX}${id}`, { body, ttlMs }, ttlMs);
}

function politicalFeedCacheKey(query = {}) {
  const normalized = {};
  for (const [k, v] of Object.entries(query)) {
    if (v === undefined || v === null || v === '') continue;
    normalized[k] = String(v);
  }
  const parts = Object.keys(normalized).sort().map((k) => `${k}=${normalized[k]}`);
  return `${POLITICAL_FEED_PREFIX}${parts.join('&')}`;
}

function shouldCachePoliticalFeedQuery(query = {}) {
  if (process.env.POLITICAL_FEED_CACHE_ENABLED === 'false') return false;
  const page = parseInt(query.page, 10) || 1;
  return page <= maxCachedFeedPage();
}

async function getCachedPoliticalFeed(query) {
  if (!shouldCachePoliticalFeedQuery(query)) return null;
  const entry = await cacheService.get(politicalFeedCacheKey(query));
  if (!entry?.body) return null;
  return entry;
}

async function setCachedPoliticalFeed(query, body) {
  if (!shouldCachePoliticalFeedQuery(query)) return;
  const ttlMs = politicalFeedTtlMs();
  await cacheService.set(politicalFeedCacheKey(query), { body, ttlMs }, ttlMs);
}

async function invalidateFeedCaches() {
  await cacheService.deleteByPrefix(FEED_PREFIX);
  await cacheService.deleteByPrefix(POST_PREFIX);
  await cacheService.deleteByPrefix(POLITICAL_FEED_PREFIX);
  await cacheService.del(CATEGORIES_KEY);
}

function isAuthenticatedRequest(req) {
  if (req?.user?.id || req?.user?._id) return true;
  const auth = req?.headers?.authorization;
  return typeof auth === 'string' && auth.startsWith('Bearer ');
}

function edgeCacheEnabled() {
  return process.env.EDGE_CACHE_ENABLED !== 'false';
}

function cacheControlHeader(ttlMs, { private: isPrivate = true } = {}) {
  const sec = Math.max(1, Math.floor(ttlMs / 1000));
  const scope = isPrivate ? 'private' : 'public';
  return `${scope}, max-age=${sec}, stale-while-revalidate=${Math.min(sec * 2, 120)}`;
}

/**
 * Set browser + CDN cache headers for public read APIs.
 * Anonymous GETs are public-cacheable; authenticated responses stay private.
 */
function applyEdgeCacheHeaders(res, req, ttlMs, { forcePrivate = false } = {}) {
  const isPrivate = forcePrivate || isAuthenticatedRequest(req);
  const sec = Math.max(1, Math.floor(ttlMs / 1000));
  res.set('Cache-Control', cacheControlHeader(ttlMs, { private: isPrivate }));
  res.set('Vary', 'Authorization, Accept-Encoding');

  if (!isPrivate && edgeCacheEnabled()) {
    const cdnSec = Math.max(1, Number(process.env.CDN_CACHE_TTL_SEC || sec));
    res.set('CDN-Cache-Control', `max-age=${cdnSec}`);
    res.set('Surrogate-Control', `max-age=${cdnSec}`);
  }
}

module.exports = {
  feedCacheKey,
  shouldCacheFeedQuery,
  getCachedFeed,
  setCachedFeed,
  getCachedCategories,
  setCachedCategories,
  getCachedPost,
  setCachedPost,
  invalidateFeedCaches,
  cacheControlHeader,
  applyEdgeCacheHeaders,
  isAuthenticatedRequest,
  edgeCacheEnabled,
  feedTtlMs,
  feedTtlForQuery,
  categoriesTtlMs,
  postTtlMs,
  politicalFeedTtlMs,
  getCachedPoliticalFeed,
  setCachedPoliticalFeed,
};
