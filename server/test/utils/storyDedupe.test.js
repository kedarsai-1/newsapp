const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

const {
  canonicalizeUrl,
  normalizeTitle,
  titleFingerprint,
  summariesAreNearDuplicates,
} = require('../../utils/storyDedupe');

describe('storyDedupe', () => {
  it('canonicalizeUrl strips utm params and www', () => {
    const a = canonicalizeUrl('https://www.example.com/path/?utm_source=x&id=1');
    const b = canonicalizeUrl('https://example.com/path?id=1');
    assert.equal(a, b);
  });

  it('normalizeTitle collapses case and punctuation', () => {
    const a = normalizeTitle('Breaking: PM Visits City!');
    const b = normalizeTitle('breaking pm visits city');
    assert.equal(a, b);
  });

  it('titleFingerprint is stable for equivalent titles', () => {
    const fp1 = titleFingerprint('Election Results 2024');
    const fp2 = titleFingerprint('election results 2024');
    assert.equal(fp1, fp2);
  });

  it('summariesAreNearDuplicates detects overlapping summaries', () => {
    const s1 = 'The chief minister announced new policies for farmers across the state today in a press conference';
    const s2 = 'Today in a press conference the chief minister announced new policies for farmers across the state';
    assert.equal(summariesAreNearDuplicates(s1, s2), true);
  });
});
