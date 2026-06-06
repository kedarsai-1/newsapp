const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const cacheService = require('../../utils/cacheService');
const feedResponseCache = require('../../utils/feedResponseCache');

describe('feedResponseCache', () => {
  const saved = {};

  beforeEach(async () => {
    saved.FEED_CACHE_ENABLED = process.env.FEED_CACHE_ENABLED;
    await cacheService.clear();
  });

  afterEach(async () => {
    await cacheService.clear();
    if (saved.FEED_CACHE_ENABLED === undefined) delete process.env.FEED_CACHE_ENABLED;
    else process.env.FEED_CACHE_ENABLED = saved.FEED_CACHE_ENABLED;
  });

  it('skips cache for search queries', () => {
    assert.equal(feedResponseCache.shouldCacheFeedQuery({ page: '1' }), true);
    assert.equal(feedResponseCache.shouldCacheFeedQuery({ page: '1', search: 'modi' }), false);
  });

  it('stores and returns feed payload', async () => {
    const query = { page: '1', language: 'te' };
    const body = { success: true, posts: [] };
    await feedResponseCache.setCachedFeed(query, body);
    const hit = await feedResponseCache.getCachedFeed(query);
    assert.deepEqual(hit.body, body);
  });

  it('invalidateFeedCaches clears feed and categories', async () => {
    await feedResponseCache.setCachedFeed({ page: '1' }, { success: true, posts: [] });
    await feedResponseCache.setCachedCategories({ success: true, categories: [] });
    await feedResponseCache.invalidateFeedCaches();
    assert.equal(await feedResponseCache.getCachedFeed({ page: '1' }), null);
    assert.equal(await feedResponseCache.getCachedCategories(), null);
  });
});
