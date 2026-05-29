const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const {
  classifyByKeywords,
  isPoliticalLabel,
  detectLanguage,
} = require('../../utils/politicalKeywordFilter');

describe('politicalKeywordFilter', () => {
  it('rejects empty video text', () => {
    const result = classifyByKeywords({ title: '', description: '' });
    assert.equal(result.stage, 'reject');
    assert.equal(result.reason, 'empty_text');
  });

  it('accepts video with multiple political keywords', () => {
    const result = classifyByKeywords({
      title: 'Chief Minister election debate interview',
      description: 'parliament session coverage',
    });
    assert.equal(result.stage, 'accept');
    assert.equal(result.method, 'keyword');
    assert.ok(result.confidence >= 0.55);
  });

  it('rejects blacklist entertainment content', () => {
    const result = classifyByKeywords({
      title: 'New movie trailer song release',
      description: 'full video song lyrics',
    });
    assert.equal(result.stage, 'reject');
    assert.equal(result.reason, 'blacklist');
  });

  it('detectLanguage identifies telugu script', () => {
    assert.equal(detectLanguage('రాజకీయ వార్త'), 'te');
  });

  it('isPoliticalLabel recognizes configured labels', () => {
    assert.equal(isPoliticalLabel('political interview'), true);
    assert.equal(isPoliticalLabel('sports'), false);
  });
});
