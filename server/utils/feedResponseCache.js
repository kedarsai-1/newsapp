/**
 * In-process TTL cache for public read APIs (single Node instance / Contabo VPS).
 * Invalidated when cron ingest emits feed_updated.
 */
const memoryCache = require('./memoryCache');

const FEED_PREFIX = 'feed:';
const POST_PREFIX = 'post:';
const CATEGORIES_KEY = 'categories:active';

function feedCacheEnabled() {
  return process.env.FEED_CACHE_ENABLED !== 'false';
}

function feedTtlMs() {
  return Math.max(5000, Number(process.env.FEED_CACHE_TTL_MS || 45_000));
}

function categoriesTtlMs() {
  return Math.max(60_000, Number(process.env.CATEGORIES_CACHE_TTL_MS || 300_000));
}

function postTtlMs() {
  return Math.max(10_000, Number(process.env.POST_CACHE_TTL_MS || 120_000));
}

function maxCachedFeedPage() {
  return Math.max(1, Number(process.env.FEED_CACHE_MAX_PAGE || 3));
}

/** Stable cache key from feed query params. */
function feedCacheKey(query = {}) {
  const normalized = {};
  for (const [k, v] of Object.entries(query)) {
    if (v === undefined || v === null || v === '') continue;
    normalized[k] = String(v);
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

function getCachedFeed(query) {
  if (!shouldCacheFeedQuery(query)) return null;
  const entry = memoryCache.get(feedCacheKey(query));
  if (!entry?.body) return null;
  return entry;
}

function setCachedFeed(query, body) {
  if (!shouldCacheFeedQuery(query)) return;
  const ttlMs = feedTtlMs();
  memoryCache.set(feedCacheKey(query), { body, ttlMs }, ttlMs);
}

function getCachedCategories() {
  return memoryCache.get(CATEGORIES_KEY);
}

function setCachedCategories(body) {
  const ttlMs = categoriesTtlMs();
  memoryCache.set(CATEGORIES_KEY, { body, ttlMs }, ttlMs);
}

function getCachedPost(id) {
  return memoryCache.get(`${POST_PREFIX}${id}`);
}

function setCachedPost(id, body) {
  if (process.env.POST_CACHE_ENABLED === 'false') return;
  const ttlMs = postTtlMs();
  memoryCache.set(`${POST_PREFIX}${id}`, { body, ttlMs }, ttlMs);
}

function invalidateFeedCaches() {
  memoryCache.deleteByPrefix(FEED_PREFIX);
  memoryCache.deleteByPrefix(POST_PREFIX);
  memoryCache.del(CATEGORIES_KEY);
}

function cacheControlHeader(ttlMs, { private: isPrivate = true } = {}) {
  const sec = Math.max(1, Math.floor(ttlMs / 1000));
  const scope = isPrivate ? 'private' : 'public';
  return `${scope}, max-age=${sec}, stale-while-revalidate=${Math.min(sec * 2, 120)}`;
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
  feedTtlMs,
  categoriesTtlMs,
  postTtlMs,
};
