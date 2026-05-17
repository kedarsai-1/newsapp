const mongoose = require('mongoose');
const Category = require('../models/Category');
const NewsPost = require('../models/NewsPost');
const memoryCache = require('../utils/memoryCache');
const cricApi = require('../services/cricApiService');

const TTL_NEWS_MS = 10 * 60 * 1000;

function newsThumb(post) {
  const m = post.media?.[0];
  if (!m?.url) return null;
  if (m.type === 'image') return m.url;
  if (m.type === 'video' && post.youtube?.thumbnailUrl) return post.youtube.thumbnailUrl;
  return m.url;
}

function normalizeNewsPost(post) {
  const o = post.toObject ? post.toObject() : post;
  return {
    id: String(o._id),
    title: o.title,
    thumbnail: newsThumb(o),
    time: o.sourcePublishedAt || o.createdAt,
    source: o.sourceName || o.category?.name || 'Sports',
    hasVideo: Boolean(
      o.media?.some((x) => x.type === 'video') || o.youtube?.videoId,
    ),
    youtubeVideoId: o.youtube?.videoId || null,
    youtubeUrl: o.youtube?.videoId
      ? `https://www.youtube.com/watch?v=${o.youtube.videoId}`
      : null,
  };
}

async function resolveSportsCategoryId() {
  const cacheKey = 'sports:categoryId';
  const hit = memoryCache.get(cacheKey);
  if (hit) return hit;
  const cat = await Category.findOne({ slug: 'sports', isActive: true })
    .select('_id')
    .lean();
  const id = cat?._id ? String(cat._id) : null;
  memoryCache.set(cacheKey, id, TTL_NEWS_MS);
  return id;
}

/** GET /api/sports/live — live + upcoming (minimal payload). */
const getLive = async (req, res) => {
  try {
    if (!cricApi.hasKey()) {
      return res.json({
        success: true,
        live: [],
        upcoming: [],
        message: 'Configure CRICAPI_KEY on the server for live scores.',
        cached: false,
      });
    }
    const data = await cricApi.fetchCurrentMatches();
    return res.json({
      success: true,
      live: data.live,
      upcoming: data.upcoming,
      cached: true,
      fetchedAt: data.fetchedAt,
    });
  } catch (e) {
    console.error('[sports] live', e.message);
    return res.status(502).json({
      success: false,
      message: 'Could not load live cricket scores.',
    });
  }
};

/** GET /api/sports/match/:id — match detail (minimal). */
const getMatch = async (req, res) => {
  try {
    const { id } = req.params;
    if (!id) {
      return res.status(400).json({ success: false, message: 'Match id required.' });
    }
    if (!cricApi.hasKey()) {
      return res.status(503).json({
        success: false,
        message: 'CricAPI not configured.',
      });
    }
    const match = await cricApi.fetchMatchById(id);
    return res.json({ success: true, match });
  } catch (e) {
    console.error('[sports] match', e.message);
    return res.status(502).json({
      success: false,
      message: 'Could not load match details.',
    });
  }
};

/** GET /api/sports/news — cricket/sports posts from existing news DB. */
const getNews = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(30, Math.max(5, parseInt(req.query.limit, 10) || 15));
    const cacheKey = `sports:news:${page}:${limit}`;
    const cached = memoryCache.get(cacheKey);
    if (cached) {
      return res.json({ ...cached, cached: true });
    }

    const categoryId = await resolveSportsCategoryId();
    const query = { status: 'approved' };
    if (categoryId && mongoose.Types.ObjectId.isValid(categoryId)) {
      query.category = new mongoose.Types.ObjectId(categoryId);
    } else {
      query.$or = [
        { tags: /cricket|ipl|sports|wpl|t20|odi/i },
        { title: /cricket|ipl|wpl|t20|odi/i },
      ];
    }

    const skip = (page - 1) * limit;
    const [posts, total] = await Promise.all([
      NewsPost.find(query)
        .sort({ sourcePublishedAt: -1, createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .populate('category', 'name slug')
        .lean(),
      NewsPost.countDocuments(query),
    ]);

    const items = posts.map(normalizeNewsPost);
    const pages = Math.ceil(total / limit) || 1;
    const payload = {
      success: true,
      news: items,
      page,
      pages,
      total,
      cached: false,
    };
    memoryCache.set(cacheKey, payload, TTL_NEWS_MS);
    return res.json(payload);
  } catch (e) {
    console.error('[sports] news', e.message);
    return res.status(500).json({
      success: false,
      message: 'Could not load sports news.',
    });
  }
};

/** GET /api/sports/highlights — sports videos for YouTube thumbnails. */
const getHighlights = async (req, res) => {
  try {
    const limit = Math.min(12, parseInt(req.query.limit, 10) || 8);
    const cacheKey = `sports:highlights:${limit}`;
    const cached = memoryCache.get(cacheKey);
    if (cached) return res.json({ ...cached, cached: true });

    const categoryId = await resolveSportsCategoryId();
    const query = {
      status: 'approved',
      $or: [
        { 'youtube.videoId': { $exists: true, $ne: null } },
        { media: { $elemMatch: { type: 'video' } } },
      ],
    };
    if (categoryId) query.category = new mongoose.Types.ObjectId(categoryId);

    const posts = await NewsPost.find(query)
      .sort({ sourcePublishedAt: -1, createdAt: -1 })
      .limit(limit)
      .lean();

    const highlights = posts.map((p) => {
      const n = normalizeNewsPost(p);
      return {
        id: n.id,
        title: n.title,
        thumbnail: n.thumbnail,
        youtubeUrl: n.youtubeUrl,
        youtubeVideoId: n.youtubeVideoId,
        time: n.time,
      };
    });

    const payload = { success: true, highlights, cached: false };
    memoryCache.set(cacheKey, payload, TTL_NEWS_MS);
    return res.json(payload);
  } catch (e) {
    console.error('[sports] highlights', e.message);
    return res.status(500).json({ success: false, message: 'Could not load highlights.' });
  }
};

module.exports = { getLive, getMatch, getNews, getHighlights };
