const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { capYoutubeInMixedFeed } = require('../../utils/youtubeCap');

describe('youtubeCap', () => {
  const posts = [
    { id: 1, title: 'Article 1', sourceType: 'api' },
    { id: 2, title: 'Video 1', sourceType: 'youtube', youtube: { videoId: 'v1' } },
    { id: 3, title: 'Article 2', sourceType: 'rss' },
    { id: 4, title: 'Video 2', sourceType: 'youtube', youtube: { videoId: 'v2' } },
    { id: 5, title: 'Article 3', sourceType: 'manual' },
    { id: 6, title: 'Video 3', sourceType: 'youtube', youtube: { videoId: 'v3' } },
    { id: 7, title: 'Video 4', sourceType: 'youtube', youtube: { videoId: 'v4' } },
    { id: 8, title: 'Video 5', sourceType: 'youtube', youtube: { videoId: 'v5' } },
  ];

  it('caps YouTube posts to 2 in a mixed feed when sourceTypes is a comma-separated list including youtube and others', () => {
    const result = capYoutubeInMixedFeed(posts, 'api,manual,rss,youtube');
    // We expect 2 youtube videos (id 2, 4) and all non-youtube articles (id 1, 3, 5).
    // Total should be 5 posts.
    assert.equal(result.length, 5);
    const youtubePosts = result.filter(p => p.sourceType === 'youtube');
    assert.equal(youtubePosts.length, 2);
    assert.deepEqual(youtubePosts.map(p => p.id), [2, 4]);
  });

  it('caps YouTube posts to 2 when sourceTypes is not specified (mixed feed by default)', () => {
    const result = capYoutubeInMixedFeed(posts, undefined);
    assert.equal(result.length, 5);
    const youtubePosts = result.filter(p => p.sourceType === 'youtube');
    assert.equal(youtubePosts.length, 2);
  });

  it('does NOT cap YouTube posts if sourceTypes is only youtube (dedicated feed)', () => {
    const youtubeOnlyPosts = posts.filter(p => p.sourceType === 'youtube');
    const result = capYoutubeInMixedFeed(youtubeOnlyPosts, 'youtube');
    assert.equal(result.length, 5);
  });

  it('respects MAX_YOUTUBE_IN_MIXED_FEED env variable if set', () => {
    const prevMax = process.env.MAX_YOUTUBE_IN_MIXED_FEED;
    process.env.MAX_YOUTUBE_IN_MIXED_FEED = '2';
    try {
      const result = capYoutubeInMixedFeed(posts, 'api,youtube');
      const youtubePosts = result.filter(p => p.sourceType === 'youtube');
      assert.equal(youtubePosts.length, 2);
      assert.deepEqual(youtubePosts.map(p => p.id), [2, 4]);
    } finally {
      if (prevMax === undefined) {
        delete process.env.MAX_YOUTUBE_IN_MIXED_FEED;
      } else {
        process.env.MAX_YOUTUBE_IN_MIXED_FEED = prevMax;
      }
    }
  });
});
