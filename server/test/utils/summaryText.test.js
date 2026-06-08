const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  normalizeSummarySource,
  truncateSummary,
  clipSummaryForStorage,
  clipSummaryForSnippet,
  isSuspiciousSummary,
} = require('../../utils/summaryText');

describe('summaryText', () => {
  it('returns empty for blank input', () => {
    assert.equal(truncateSummary(''), '');
    assert.equal(truncateSummary('   '), '');
  });

  it('returns text unchanged when within limit', () => {
    const s = 'Short summary.';
    assert.equal(truncateSummary(s, 300), s);
  });

  it('truncates at sentence boundary when possible', () => {
    const first = 'Alpha sentence ends here. ';
    const second = 'Beta sentence continues with more words.';
    const text = first + second.repeat(5);
    const out = truncateSummary(text, 100);
    assert.ok(out.endsWith('.') || out.endsWith('…'));
    assert.ok(out.length <= 100);
    assert.ok(!out.endsWith(' with'));
  });

  it('truncates at word boundary when no sentence fits', () => {
    const words = Array.from({ length: 80 }, (_, i) => `word${i}`).join(' ');
    const out = truncateSummary(words, 100);
    assert.ok(out.endsWith('…'));
    assert.ok(out.length <= 100);
    const body = out.slice(0, -1);
    assert.match(body, /word\d+$/);
  });

  it('never leaves mid-word cuts like political ingest bug', () => {
    const text = `${'A'.repeat(270)} Opposition leaders met in Delhi for talks.`;
    const out = truncateSummary(text, 280);
    assert.ok(!out.endsWith('leade'));
    assert.ok(out.endsWith('…') || out.endsWith('.'));
  });

  it('normalizeSummarySource strips hashtag runs and hash prefixes', () => {
    const raw = 'Breaking news here. #youtube #politics #political #interview #india #news';
    const norm = normalizeSummarySource(raw);
    assert.ok(!norm.includes('#'));
    assert.match(norm, /Breaking news here/);
  });

  it('handles YouTube-style hashtag-heavy descriptions', () => {
    const desc = `${'The meeting took place ahead of the INDIA bloc gathering scheduled for June. '.repeat(6)}`
      + '#youtube #politics #political interview #india #news #breaking #live';
    const out = truncateSummary(desc, 280);
    assert.ok(out.length <= 280);
    if (out.length >= 200) {
      assert.ok(out.endsWith('…') || /[.!?]$/.test(out.trim()));
    }
    assert.ok(!out.endsWith('leade'));
  });

  it('clipSummaryForStorage keeps text under storage cap', () => {
    const long = `${'Sentence one ends here. '.repeat(120)}Final.`;
    const out = clipSummaryForStorage(long);
    assert.ok(out.length <= 2000);
    assert.ok(out.endsWith('.') || out.endsWith('…'));
  });

  it('clipSummaryForSnippet truncates feed snippets', () => {
    const long = `${'Word '.repeat(200)}end.`;
    const out = clipSummaryForSnippet(long);
    assert.ok(out.length <= 300);
  });

  it('isSuspiciousSummary flags legacy hard cuts', () => {
    assert.equal(isSuspiciousSummary('Opposition leade'), false);
    assert.equal(
      isSuspiciousSummary(`${'x'.repeat(278)}leade`),
      true,
    );
    assert.equal(isSuspiciousSummary('Clean ending sentence.'), false);
  });
});

describe('newsApiService.summarize', () => {
  it('uses boundary-aware truncation not hard slice', () => {
    const { summarize } = require('../../services/newsApiService');
    const long = `${'Market analysts expect strong growth this quarter. '.repeat(8)}More text here.`;
    const out = summarize(long);
    assert.ok(out);
    assert.ok(out.length <= 2000);
    assert.ok(out.endsWith('…') || /[.!?]$/.test(out));
    assert.ok(!out.endsWith('...'));
  });
});
