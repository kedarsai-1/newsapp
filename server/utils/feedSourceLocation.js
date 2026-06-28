/**
 * Parse hyperlocal hints from RSS source labels like "TV9 Telugu - Guntur".
 * Rejects state-wide and topical (Politics, World, …) feed tails.
 */

const STATE_WIDE_FEED_TAILS = new Set([
  'Andhra Pradesh',
  'Telangana',
  'Uttar Pradesh',
  'Bihar',
  'Rajasthan',
  'Punjab',
  'Haryana',
  'States',
  'North',
  'India',
  'National',
  'International',
]);

/** Topic/category tails — not geographic place names. */
const NON_GEO_FEED_TAILS = new Set([
  'Politics',
  'World',
  'Business',
  'Entertainment',
  'Sports',
  'Sport',
  'Technology',
  'Health',
  'Lifestyle',
  'Education',
  'Crime',
  'Weather',
  'General',
  'Latest',
  'Top Stories',
  'Breaking',
  'Videos',
  'Shorts',
]);

function feedSourceTail(sourceName) {
  const src = String(sourceName || '').trim();
  const dash = src.lastIndexOf(' - ');
  if (dash === -1) return null;
  const tail = src.slice(dash + 3).trim();
  if (!tail || tail.length > 80) return null;
  return tail;
}

function isStateWideFeedTail(tail) {
  return tail != null && STATE_WIDE_FEED_TAILS.has(tail);
}

function isNonGeoFeedTail(tail) {
  return tail != null && NON_GEO_FEED_TAILS.has(tail);
}

function isHyperlocalFeedSource(sourceName) {
  const tail = feedSourceTail(sourceName);
  if (!tail) return false;
  if (isStateWideFeedTail(tail) || isNonGeoFeedTail(tail)) return false;
  return true;
}

function isStateWideFeedSource(sourceName) {
  const tail = feedSourceTail(sourceName);
  if (tail === null) return String(sourceName || '').includes(' - ');
  return isStateWideFeedTail(tail);
}

function isNonGeoFeedSource(sourceName) {
  const tail = feedSourceTail(sourceName);
  return tail != null && isNonGeoFeedTail(tail);
}

/** Extract trailing city/place from feed labels like "Amar Ujala - Lucknow". */
function cityFromSourceName(sourceName) {
  const tail = feedSourceTail(sourceName);
  if (!tail) return null;
  if (isStateWideFeedTail(tail) || isNonGeoFeedTail(tail)) return null;
  return tail;
}

/** Prisma NOT clause: exclude topical RSS sources from hyperlocal results. */
function prismaExcludeNonGeoFeedSourcesClause() {
  return {
    NOT: {
      OR: [...NON_GEO_FEED_TAILS].map((tail) => ({
        sourceName: { contains: ` - ${tail}`, mode: 'insensitive' },
      })),
    },
  };
}

module.exports = {
  STATE_WIDE_FEED_TAILS,
  NON_GEO_FEED_TAILS,
  feedSourceTail,
  isStateWideFeedTail,
  isNonGeoFeedTail,
  isHyperlocalFeedSource,
  isStateWideFeedSource,
  isNonGeoFeedSource,
  cityFromSourceName,
  prismaExcludeNonGeoFeedSourcesClause,
};
