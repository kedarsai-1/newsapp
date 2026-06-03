const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { getPublisherReferer } = require('../../utils/publisherReferer');

describe('getPublisherReferer', () => {
  it('returns site root for English publishers', () => {
    assert.equal(
      getPublisherReferer('https://timesofindia.indiatimes.com/foo'),
      'https://timesofindia.indiatimes.com/',
    );
    assert.equal(getPublisherReferer('thgimgs.com'), 'https://www.thehindu.com/');
  });

  it('returns site root for Hindi publishers', () => {
    assert.equal(getPublisherReferer('amarujala.com'), 'https://www.amarujala.com/');
    assert.equal(getPublisherReferer('bhaskar.com'), 'https://www.bhaskar.com/');
  });
});
