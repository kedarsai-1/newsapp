const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  isYoutubeQuotaError,
  isYoutubeSearchQuotaError,
} = require('../../utils/youtubeQuota');

describe('youtubeQuota', () => {
  it('detects search-only quota errors separately from full API quota', () => {
    const searchErr = new Error(
      "YouTube API search: Quota exceeded for quota metric 'Search Queries' "
      + "and limit 'Search Queries per day'",
    );
    assert.equal(isYoutubeSearchQuotaError(searchErr), true);
    assert.equal(isYoutubeQuotaError(searchErr), false);
  });

  it('detects general quota errors', () => {
    const err = new Error('YouTube API channels: Quota exceeded');
    assert.equal(isYoutubeSearchQuotaError(err), false);
    assert.equal(isYoutubeQuotaError(err), true);
  });
});
