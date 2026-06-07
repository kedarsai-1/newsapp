const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  parseFeedPagination,
  buildFeedPaginationResponse,
  needsPostFetchLoop,
} = require('../../utils/feedPagination');
const { validateCategoryInput } = require('../../utils/categoryValidation');
const { politicsScopeAllowedForLanguage } = require('../../controllers/newsController');

describe('feedPagination', () => {
  it('parseFeedPagination clamps invalid page and limit', () => {
    assert.deepEqual(parseFeedPagination(0, 999), { pageNum: 1, limitNum: 50, skip: 0 });
    assert.deepEqual(parseFeedPagination('2', '10'), { pageNum: 2, limitNum: 10, skip: 10 });
  });

  it('buildFeedPaginationResponse sets pages for Flutter hasMore contract', () => {
    const more = buildFeedPaginationResponse(1, 20, 20, true);
    assert.equal(more.pages, 2);
    assert.equal(more.hasMore, true);

    const last = buildFeedPaginationResponse(3, 20, 5, false);
    assert.equal(last.pages, 3);
    assert.equal(last.hasMore, false);
  });

  it('needsPostFetchLoop when post-filters apply', () => {
    assert.equal(needsPostFetchLoop({
      langParam: 'en',
      excludePoliticsFeed: false,
      categorySlugFilter: null,
      sourceTypes: 'api,manual',
    }), true);
    assert.equal(needsPostFetchLoop({
      langParam: null,
      excludePoliticsFeed: true,
      categorySlugFilter: null,
      sourceTypes: 'youtube',
    }), true);
    assert.equal(needsPostFetchLoop({
      langParam: 'hi',
      excludePoliticsFeed: false,
      categorySlugFilter: null,
      sourceTypes: 'api',
    }), false);
    assert.equal(needsPostFetchLoop({
      langParam: 'hi',
      excludePoliticsFeed: false,
      categorySlugFilter: null,
      sourceTypes: '',
    }), false);
    assert.equal(needsPostFetchLoop({
      langParam: 'te',
      excludePoliticsFeed: false,
      categorySlugFilter: null,
      sourceTypes: '',
    }), false);
    assert.equal(needsPostFetchLoop({
      langParam: null,
      excludePoliticsFeed: false,
      categorySlugFilter: null,
      sourceTypes: '',
    }), true);
  });
});

describe('categoryValidation', () => {
  it('rejects invalid slug format', () => {
    const out = validateCategoryInput({ name: 'Test', slug: 'Bad Slug!' });
    assert.ok(out.error);
  });

  it('accepts valid category input', () => {
    const out = validateCategoryInput({ name: 'Politics', slug: 'politics' });
    assert.equal(out.data.slug, 'politics');
  });
});

describe('politicsScopeAllowedForLanguage', () => {
  it('blocks incompatible scope/language pairs', () => {
    assert.equal(politicsScopeAllowedForLanguage('andhra', 'hi'), false);
    assert.equal(politicsScopeAllowedForLanguage('andhra', 'te'), true);
    assert.equal(politicsScopeAllowedForLanguage('north', 'en'), false);
  });
});
