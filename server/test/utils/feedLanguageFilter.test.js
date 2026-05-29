const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const {
  buildLanguageClause,
  applyLanguageFilter,
} = require('../../utils/feedLanguageFilter');

describe('feedLanguageFilter', () => {
  it('returns null clause when lang is missing', () => {
    assert.equal(buildLanguageClause(null), null);
    assert.equal(buildLanguageClause(undefined), null);
  });

  it('builds english clause', () => {
    assert.deepEqual(buildLanguageClause('en'), { language: 'en' });
  });

  it('builds telugu OR clause', () => {
    const clause = buildLanguageClause('te');
    assert.ok(clause.OR);
    assert.ok(clause.OR.some((c) => c.originalLanguage === 'tel'));
  });

  it('applyLanguageFilter merges AND clause into query', () => {
    const query = applyLanguageFilter({ status: 'approved' }, 'hi');
    assert.equal(query.status, 'approved');
    assert.ok(Array.isArray(query.AND));
    assert.ok(query.AND.length >= 1);
  });
});
