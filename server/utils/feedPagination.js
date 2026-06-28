const MAX_FEED_SCAN = Math.max(
  200,
  Number(process.env.FEED_MAX_SCAN_ROWS || 800),
);

function parseFeedPagination(page, limit) {
  const pageNum = Math.max(1, parseInt(page, 10) || 1);
  const limitNum = Math.min(50, Math.max(1, parseInt(limit, 10) || 20));
  const skip = (pageNum - 1) * limitNum;
  return { pageNum, limitNum, skip };
}

/** Pagination meta compatible with Flutter (_hasMore = apiPage < apiPages). */
function buildFeedPaginationResponse(pageNum, limitNum, postsLength, hasMore) {
  const safePage = Math.max(1, pageNum);
  let pages = hasMore ? safePage + 1 : safePage;
  let total = (safePage - 1) * limitNum + postsLength;
  if (postsLength === 0 && safePage > 1) {
    pages = safePage;
    total = (safePage - 1) * limitNum;
  }
  return {
    page: safePage,
    pages,
    total,
    hasMore,
  };
}

function needsPostFetchLoop({
  langParam,
  excludePoliticsFeed,
  categorySlugFilter,
  sourceTypes,
}) {
  if (langParam === 'en') return true;
  if (excludePoliticsFeed) return true;
  if (categorySlugFilter === 'politics' || categorySlugFilter === 'local') return true;
  const list = String(sourceTypes || '')
    .split(',')
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);
  if (!list.length) {
    // hi/te use indexed SQL language filters — skip expensive scan loop for YouTube cap alone.
    if (langParam === 'hi' || langParam === 'te') return false;
    return true;
  }
  const isMixedFeed = list.includes('youtube') && list.length > 1;
  return isMixedFeed;
}

/**
 * Fetch feed rows, applying post-DB filters until the page is full or DB is exhausted.
 */
async function fetchFeedPagePosts({
  prisma,
  where,
  skip,
  limitNum,
  include,
  orderBy,
  mapRow,
  applyPostFilters,
}) {
  const batchSize = Math.max(limitNum * 2, 40);
  let dbOffset = skip;
  let collected = [];
  let scanned = 0;
  let dbExhausted = false;

  while (collected.length < limitNum && scanned < MAX_FEED_SCAN) {
    // eslint-disable-next-line no-await-in-loop
    const rows = await prisma.newsPost.findMany({
      where,
      include,
      orderBy,
      skip: dbOffset,
      take: batchSize,
    });
    if (!rows.length) {
      dbExhausted = true;
      break;
    }
    scanned += rows.length;
    dbOffset += rows.length;

    let batch = rows.map(mapRow);
    batch = applyPostFilters(batch);
    collected.push(...batch);

    if (rows.length < batchSize) {
      dbExhausted = true;
      break;
    }
  }

  const posts = collected.slice(0, limitNum);
  let hasMore = false;
  if (posts.length === limitNum) {
    if (!dbExhausted || collected.length > limitNum) {
      hasMore = true;
    } else {
      const probe = await prisma.newsPost.findMany({
        where,
        skip: dbOffset,
        take: 1,
        select: { id: true },
      });
      hasMore = probe.length > 0;
    }
  }

  return { posts, hasMore };
}

module.exports = {
  parseFeedPagination,
  buildFeedPaginationResponse,
  needsPostFetchLoop,
  fetchFeedPagePosts,
  MAX_FEED_SCAN,
};
