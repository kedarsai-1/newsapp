const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  normalizeLanguages,
  resolveIngestLanguages,
  lockKeyForLanguages,
  filterByLanguages,
  getIngestBudgetMs,
} = require('../../config/ingestLanguages');

describe('ingestLanguages', () => {
  it('normalizeLanguages keeps en hi te only', () => {
    assert.deepEqual(normalizeLanguages(['en', 'hi', 'xx', 'TE']), ['en', 'hi', 'te']);
  });

  it('lockKeyForLanguages uses single lang or global', () => {
    assert.equal(lockKeyForLanguages(['te']), 'te');
    assert.equal(lockKeyForLanguages(['en', 'hi', 'te']), 'global');
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
});
