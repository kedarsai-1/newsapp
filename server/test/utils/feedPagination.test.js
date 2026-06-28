const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  parseFeedPagination,
  buildFeedPaginationResponse,
  needsPostFetchLoop,
} = require('../../utils/feedPagination');
const { validateCategoryInput } = require('../../utils/categoryValidation');
const { politicsScopeAllowedForLanguage, politicsScopeWhere } = require('../../controllers/newsController');

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

    const emptyFar = buildFeedPaginationResponse(99999, 1, 0, false);
    assert.equal(emptyFar.pages, 99999);
    assert.equal(emptyFar.total, 99998);
    assert.equal(emptyFar.hasMore, false);
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

function collectPoliticsScopeInValues(node, out = []) {
  if (!node || typeof node !== 'object') return out;
  if (Object.prototype.hasOwnProperty.call(node, 'politicsScope')) {
    const ps = node.politicsScope;
    if (ps && typeof ps === 'object' && Array.isArray(ps.in)) {
      out.push(ps.in);
    }
  }
  for (const value of Object.values(node)) {
    if (Array.isArray(value)) value.forEach((v) => collectPoliticsScopeInValues(v, out));
    else if (value && typeof value === 'object') collectPoliticsScopeInValues(value, out);
  }
  return out;
}

describe('politicsScopeWhere', () => {
  it('never puts null inside Prisma `in` filters', () => {
    for (const scope of ['andhra', 'telangana', 'north', 'india', 'international']) {
      const clause = politicsScopeWhere(scope, scope === 'north' ? 'hi' : 'te');
      assert.ok(clause, `expected clause for ${scope}`);
      for (const values of collectPoliticsScopeInValues(clause)) {
        assert.ok(!values.includes(null), `null in politicsScope.in for ${scope}`);
      }
    }
  });
});
