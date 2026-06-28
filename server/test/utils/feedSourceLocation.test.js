const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  cityFromSourceName,
  isNonGeoFeedSource,
  isHyperlocalFeedSource,
  isStateWideFeedSource,
} = require('../../utils/feedSourceLocation');

describe('feedSourceLocation', () => {
  it('extracts city from hyperlocal feed labels', () => {
    assert.equal(cityFromSourceName('TV9 Telugu - Guntur'), 'Guntur');
    assert.equal(cityFromSourceName('Amar Ujala - Lucknow'), 'Lucknow');
    assert.equal(cityFromSourceName('NTV Telugu - Palnadu'), 'Palnadu');
  });

  it('rejects topical and state-wide feed tails', () => {
    assert.equal(cityFromSourceName('NTV Telugu - Politics'), null);
    assert.equal(cityFromSourceName('NTV Telugu - World'), null);
    assert.equal(cityFromSourceName('NTV Telugu - Andhra Pradesh'), null);
    assert.equal(isNonGeoFeedSource('NTV Telugu - Politics'), true);
    assert.equal(isStateWideFeedSource('TV9 Telugu - Andhra Pradesh'), true);
    assert.equal(isHyperlocalFeedSource('TV9 Telugu - Guntur'), true);
    assert.equal(isHyperlocalFeedSource('NTV Telugu - Politics'), false);
  });
});
