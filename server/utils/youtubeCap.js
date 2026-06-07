/**
 * Filters and caps the number of YouTube posts in a mixed news feed.
 */

function capYoutubeInMixedFeed(posts, sourceTypes) {
  if (!Array.isArray(posts)) return [];

  let isMixedFeed = false;
  if (sourceTypes) {
    const list = String(sourceTypes)
      .split(',')
      .map((s) => s.trim().toLowerCase())
      .filter(Boolean);
    if (list.includes('youtube') && list.length > 1) {
      isMixedFeed = true;
    }
  } else {
    isMixedFeed = true;
  }

  if (!isMixedFeed) {
    return posts;
  }

  let youtubeCount = 0;
  const maxYoutube = Number(process.env.MAX_YOUTUBE_IN_MIXED_FEED || 2);
  return posts.filter((post) => {
    if (post.sourceType === 'youtube' || post.youtube) {
      youtubeCount++;
      return youtubeCount <= maxYoutube;
    }
    return true;
  });
}

module.exports = { capYoutubeInMixedFeed };
