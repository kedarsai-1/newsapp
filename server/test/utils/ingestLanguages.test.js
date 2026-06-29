const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  normalizeLanguages,
  resolveIngestLanguages,
  lockKeyForLanguages,
  filterByLanguages,
  getIngestBudgetMs,
  isParallelLanguageIngestEnabled,
  isPerLanguageIngestEnabled,
} = require('../../config/ingestLanguages');

describe('ingestLanguages', () => {
  it('normalizeLanguages keeps en hi te only', () => {
    assert.deepEqual(normalizeLanguages(['en', 'hi', 'xx', 'TE']), ['en', 'hi', 'te']);
  });

  it('lockKeyForLanguages uses single lang or global', () => {
    assert.equal(lockKeyForLanguages(['te']), 'te');
    // 'global' only when all 7 INGEST_LANGS are present
    assert.equal(lockKeyForLanguages(['en', 'hi', 'te', 'ta', 'kn', 'bn', 'ml']), 'global');
    // Partial list returns sorted join
    assert.equal(lockKeyForLanguages(['en', 'hi', 'te']), 'en+hi+te');
  });

  it('filterByLanguages filters channel list', () => {
    const rows = [
      { language: 'en', id: 1 },
      { language: 'hi', id: 2 },
      { language: 'te', id: 3 },
    ];
    assert.deepEqual(filterByLanguages(rows, ['hi']).map((r) => r.id), [2]);
  });

  it('resolveIngestLanguages prefers explicit languages', () => {
    const langs = resolveIngestLanguages({ languages: ['te'] });
    assert.deepEqual(langs, ['te']);
  });

  it('getIngestBudgetMs reads per-language override', () => {
    const prev = process.env.INGEST_MAX_RUNTIME_MS_TE;
    process.env.INGEST_MAX_RUNTIME_MS_TE = '12345';
    assert.equal(getIngestBudgetMs('te'), 12345);
    if (prev === undefined) delete process.env.INGEST_MAX_RUNTIME_MS_TE;
    else process.env.INGEST_MAX_RUNTIME_MS_TE = prev;
  });

  it('isParallelLanguageIngestEnabled defaults on with per-language mode', () => {
    const prevPer = process.env.INGEST_PER_LANGUAGE;
    const prevPar = process.env.INGEST_PARALLEL_LANGUAGES;
    process.env.INGEST_PER_LANGUAGE = 'true';
    delete process.env.INGEST_PARALLEL_LANGUAGES;
    assert.equal(isPerLanguageIngestEnabled(), true);
    assert.equal(isParallelLanguageIngestEnabled(), true);
    process.env.INGEST_PARALLEL_LANGUAGES = 'false';
    assert.equal(isParallelLanguageIngestEnabled(), false);
    if (prevPer === undefined) delete process.env.INGEST_PER_LANGUAGE;
    else process.env.INGEST_PER_LANGUAGE = prevPer;
    if (prevPar === undefined) delete process.env.INGEST_PARALLEL_LANGUAGES;
    else process.env.INGEST_PARALLEL_LANGUAGES = prevPar;
  });
});
