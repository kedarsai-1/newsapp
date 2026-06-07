const { prisma } = require('../config/prisma');
const { POLITICAL_LABELS } = require('../config/politicalVideoConfig');
const { runPoliticalVideoIngestion } = require('../services/politicalVideoIngestionService');
const { serializeNewsPost } = require('../utils/serializers');
const { newsPostInclude } = require('../utils/prismaNewsPost');
const feedResponseCache = require('../utils/feedResponseCache');
const {
  parseFeedPagination,
  buildFeedPaginationResponse,
} = require('../utils/feedPagination');

/** Vertical political reels — YouTube embeds up to ~60s. */
function politicalReelsWhere(extra = {}) {
  return {
    status: 'approved',
    sourceType: 'youtube',
    youtubeVideoId: { not: null },
    videoCategory: { in: POLITICAL_LABELS },
    OR: [
      { youtubeIsShort: true },
      { youtubeDurationSeconds: { lte: 60 } },
    ],
    ...extra,
  };
}

/** GET /api/political-videos/feed — vertical political reels (YouTube embed only). */
const getPoliticalFeed = async (req, res) => {
  try {
    const cached = await feedResponseCache.getCachedPoliticalFeed(req.query);
    if (cached) {
      res.set('Cache-Control', feedResponseCache.cacheControlHeader(cached.ttlMs));
      return res.json({ ...cached.body, cached: true });
    }

    const {
      page = 1,
      limit = 20,
      language,
      category,
    } = req.query;

    const where = politicalReelsWhere();

    if (language && String(language).toLowerCase() !== 'all') {
      where.language = String(language).toLowerCase();
    }
    if (category && POLITICAL_LABELS.includes(String(category).toLowerCase())) {
      where.videoCategory = String(category).toLowerCase();
    }

    const { pageNum, limitNum, skip } = parseFeedPagination(page, limit);

    const [rows, total] = await Promise.all([
      prisma.newsPost.findMany({
        where,
        include: newsPostInclude,
        orderBy: [{ sourcePublishedAt: 'desc' }, { createdAt: 'desc' }],
        skip,
        take: limitNum,
      }),
      prisma.newsPost.count({ where }),
    ]);

    const posts = rows.map(serializeNewsPost);
    const hasMore = skip + posts.length < total;
    const pagination = buildFeedPaginationResponse(pageNum, limitNum, posts.length, hasMore);

    const payload = {
      success: true,
      posts,
      page: pagination.page,
      pages: pagination.pages,
      total,
      hasMore: pagination.hasMore,
      cached: false,
    };

    await feedResponseCache.setCachedPoliticalFeed(req.query, payload);
    res.set('Cache-Control', feedResponseCache.cacheControlHeader(feedResponseCache.politicalFeedTtlMs()));
    return res.json(payload);
  } catch (e) {
    console.error('[political-videos] feed error:', e.message);
    return res.status(500).json({ success: false, message: 'Failed to load political videos.' });
  }
};

/** POST /api/political-videos/ingest — manual trigger (admin/cron). */
const triggerIngest = async (req, res) => {
  try {
    const result = await runPoliticalVideoIngestion({
      triggeredBy: req.body?.triggeredBy || 'api',
    });
    return res.json(result);
  } catch (e) {
    return res.status(500).json({ success: false, message: e.message });
  }
};

module.exports = {
  getPoliticalFeed,
  triggerIngest,
  politicalReelsWhere,
};
