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

async function getCachedFeed(query) {
  if (!shouldCacheFeedQuery(query)) return null;
  const entry = await cacheService.get(feedCacheKey(query));
  if (!entry?.body) return null;
  return entry;
}

async function setCachedFeed(query, body) {
  if (!shouldCacheFeedQuery(query)) return;
  const ttlMs = feedTtlMs();
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
  politicalFeedTtlMs,
  getCachedPoliticalFeed,
  setCachedPoliticalFeed,
};
