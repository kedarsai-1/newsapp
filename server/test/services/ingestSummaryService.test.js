const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  isSummaryBudgetAvailable,
  summaryMinBudgetMs,
  createSummaryStats,
} = require('../../services/ingestSummaryService');
const { requireImageEnabled } = require('../../utils/resolveIngestImage');

describe('ingestSummaryService', () => {
  it('createSummaryStats initializes counters', () => {
    const s = createSummaryStats();
    assert.equal(s.summaryAiOk, 0);
    assert.equal(s.summarySkippedBudget, 0);
  });

  it('isSummaryBudgetAvailable respects RSS_SKIP_AI_SUMMARY', () => {
    const prev = process.env.RSS_SKIP_AI_SUMMARY;
    process.env.RSS_SKIP_AI_SUMMARY = 'true';
    assert.equal(isSummaryBudgetAvailable(null), false);
    process.env.RSS_SKIP_AI_SUMMARY = 'false';
    process.env.AI_PROVIDER = 'ollama';
    assert.equal(isSummaryBudgetAvailable(null), true);
    if (prev === undefined) delete process.env.RSS_SKIP_AI_SUMMARY;
    else process.env.RSS_SKIP_AI_SUMMARY = prev;
  });

  it('summaryMinBudgetMs returns positive value', () => {
    assert.ok(summaryMinBudgetMs() >= 20_000);
  });
});

describe('resolveIngestImage', () => {
  it('requireImageEnabled follows env', () => {
    const prev = process.env.RSS_REQUIRE_IMAGE;
    process.env.RSS_REQUIRE_IMAGE = 'true';
    assert.equal(requireImageEnabled(), true);
    process.env.RSS_REQUIRE_IMAGE = 'false';
    assert.equal(requireImageEnabled(), false);
    if (prev === undefined) delete process.env.RSS_REQUIRE_IMAGE;
    else process.env.RSS_REQUIRE_IMAGE = prev;
  });
});
