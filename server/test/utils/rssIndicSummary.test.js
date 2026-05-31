const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  isIndicAiSummaryEnabled,
  isIndicFrancLang,
  isPrimarilyIndicScript,
} = require('../../services/rssService');

describe('rssService indic AI summary', () => {
  it('isIndicFrancLang detects hin and tel', () => {
    assert.equal(isIndicFrancLang('hin'), true);
    assert.equal(isIndicFrancLang('tel'), true);
    assert.equal(isIndicFrancLang('eng'), false);
  });

  it('isIndicAiSummaryEnabled respects env flags', () => {
    const prevSkip = process.env.RSS_SKIP_AI_SUMMARY;
    const prevIndic = process.env.RSS_INDIC_AI_SUMMARY;
    const prevToken = process.env.HF_TOKEN;
    const prevProvider = process.env.AI_PROVIDER;

    process.env.RSS_SKIP_AI_SUMMARY = 'false';
    process.env.RSS_INDIC_AI_SUMMARY = 'true';
    process.env.AI_PROVIDER = 'ollama';
    delete process.env.HF_TOKEN;
    assert.equal(isIndicAiSummaryEnabled(), true);

    process.env.RSS_INDIC_AI_SUMMARY = 'false';
    assert.equal(isIndicAiSummaryEnabled(), false);

    if (prevSkip === undefined) delete process.env.RSS_SKIP_AI_SUMMARY;
    else process.env.RSS_SKIP_AI_SUMMARY = prevSkip;
    if (prevIndic === undefined) delete process.env.RSS_INDIC_AI_SUMMARY;
    else process.env.RSS_INDIC_AI_SUMMARY = prevIndic;
    if (prevToken === undefined) delete process.env.HF_TOKEN;
    else process.env.HF_TOKEN = prevToken;
    if (prevProvider === undefined) delete process.env.AI_PROVIDER;
    else process.env.AI_PROVIDER = prevProvider;
  });
});

describe('isPrimarilyIndicScript', () => {
  it('detects Telugu-heavy text', () => {
    assert.equal(isPrimarilyIndicScript('తెలుగు వార్తలు ఎన్నికలు'), true);
    assert.equal(isPrimarilyIndicScript('English headline about elections'), false);
  });
});
