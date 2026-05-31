const { describe, it, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const memoryCache = require('../../utils/memoryCache');
const feedResponseCache = require('../../utils/feedResponseCache');

describe('feedResponseCache', () => {
  const saved = {};

  beforeEach(() => {
    saved.FEED_CACHE_ENABLED = process.env.FEED_CACHE_ENABLED;
    memoryCache.clear();
  });

  afterEach(() => {
    memoryCache.clear();
    if (saved.FEED_CACHE_ENABLED === undefined) delete process.env.FEED_CACHE_ENABLED;
    else process.env.FEED_CACHE_ENABLED = saved.FEED_CACHE_ENABLED;
  });

  it('skips cache for search queries', () => {
    assert.equal(feedResponseCache.shouldCacheFeedQuery({ page: '1' }), true);
    assert.equal(feedResponseCache.shouldCacheFeedQuery({ page: '1', search: 'modi' }), false);
  });

  it('stores and returns feed payload', () => {
    const query = { page: '1', language: 'te' };
    const body = { success: true, posts: [] };
    feedResponseCache.setCachedFeed(query, body);
    const hit = feedResponseCache.getCachedFeed(query);
    assert.deepEqual(hit.body, body);
  });

  it('invalidateFeedCaches clears feed and categories', () => {
    feedResponseCache.setCachedFeed({ page: '1' }, { success: true, posts: [] });
    feedResponseCache.setCachedCategories({ success: true, categories: [] });
    feedResponseCache.invalidateFeedCaches();
    assert.equal(feedResponseCache.getCachedFeed({ page: '1' }), null);
    assert.equal(feedResponseCache.getCachedCategories(), null);
  });
});
