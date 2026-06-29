const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  VALID_FEED_LANGUAGES,
  politicsScopeAllowedForLanguage,
} = require('../../controllers/newsController');

// languageWhere is not exported, so we test VALID_FEED_LANGUAGES + politicsScopeAllowedForLanguage
// which are the public interface to language filtering logic.

describe('languageWhere exports (VALID_FEED_LANGUAGES)', () => {
  it('includes all six production languages', () => {
    assert.ok(VALID_FEED_LANGUAGES.has('en'));
    assert.ok(VALID_FEED_LANGUAGES.has('hi'));
    assert.ok(VALID_FEED_LANGUAGES.has('te'));
    assert.ok(VALID_FEED_LANGUAGES.has('ta'));
    assert.ok(VALID_FEED_LANGUAGES.has('kn'));
    assert.ok(VALID_FEED_LANGUAGES.has('bn'));
    assert.ok(VALID_FEED_LANGUAGES.has('ml'));
    assert.equal(VALID_FEED_LANGUAGES.size, 7);
  });

  it('rejects invalid language codes', () => {
    assert.ok(!VALID_FEED_LANGUAGES.has('xx'));
    assert.ok(!VALID_FEED_LANGUAGES.has('mr'));
    assert.ok(!VALID_FEED_LANGUAGES.has(''));
  });
});

describe('politicsScopeAllowedForLanguage', () => {
  it('allows all for null/undefined scope', () => {
    assert.equal(politicsScopeAllowedForLanguage(null, 'ta'), true);
    assert.equal(politicsScopeAllowedForLanguage(undefined, 'kn'), true);
    assert.equal(politicsScopeAllowedForLanguage('all', 'bn'), true);
    assert.equal(politicsScopeAllowedForLanguage('', 'ml'), true);
  });

  it('allows tamilnadu scope for ta', () => {
    assert.equal(politicsScopeAllowedForLanguage('tamilnadu', 'ta'), true);
    assert.equal(politicsScopeAllowedForLanguage('india', 'ta'), true);
    assert.equal(politicsScopeAllowedForLanguage('international', 'ta'), true);
    assert.equal(politicsScopeAllowedForLanguage('andhra', 'ta'), false);
    assert.equal(politicsScopeAllowedForLanguage('telangana', 'ta'), false);
  });

  it('allows karnataka scope for kn', () => {
    assert.equal(politicsScopeAllowedForLanguage('karnataka', 'kn'), true);
    assert.equal(politicsScopeAllowedForLanguage('india', 'kn'), true);
    assert.equal(politicsScopeAllowedForLanguage('international', 'kn'), true);
    assert.equal(politicsScopeAllowedForLanguage('tamilnadu', 'kn'), false);
  });

  it('allows westbengal scope for bn', () => {
    assert.equal(politicsScopeAllowedForLanguage('westbengal', 'bn'), true);
    assert.equal(politicsScopeAllowedForLanguage('india', 'bn'), true);
    assert.equal(politicsScopeAllowedForLanguage('international', 'bn'), true);
    assert.equal(politicsScopeAllowedForLanguage('karnataka', 'bn'), false);
  });

  it('allows kerala scope for ml', () => {
    assert.equal(politicsScopeAllowedForLanguage('kerala', 'ml'), true);
    assert.equal(politicsScopeAllowedForLanguage('india', 'ml'), true);
    assert.equal(politicsScopeAllowedForLanguage('international', 'ml'), true);
    assert.equal(politicsScopeAllowedForLanguage('tamilnadu', 'ml'), false);
  });

  it('existing te/hi/en scopes still work', () => {
    assert.equal(politicsScopeAllowedForLanguage('andhra', 'te'), true);
    assert.equal(politicsScopeAllowedForLanguage('telangana', 'te'), true);
    assert.equal(politicsScopeAllowedForLanguage('india', 'hi'), true);
    assert.equal(politicsScopeAllowedForLanguage('international', 'en'), true);
  });
});
