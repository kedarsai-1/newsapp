const mongoose = require('mongoose');
const Category = require('../models/Category');
const NewsPost = require('../models/NewsPost');
const memoryCache = require('../utils/memoryCache');
const { applyLanguageFilter } = require('../utils/feedLanguageFilter');
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
    const empty =
      !data.live?.length && !data.upcoming?.length && !(data.ipl || []).length;
    const noIplLive =
      !(data.live || []).some((m) => /ipl|indian premier league/i.test(`${m.tournament || ''}`))
      && !(data.upcoming || []).some((m) => /ipl|indian premier league/i.test(`${m.tournament || ''}`));
    let message = empty
      ? 'No live or upcoming matches right now. Pull to refresh in a few minutes.'
      : data.warning || null;
    if (!empty && noIplLive && !(data.ipl || []).length) {
      message =
        'No live IPL match right now. The current season may be over — check back when IPL fixtures resume.';
    }

    return res.json({
      success: true,
      live: data.live,
      upcoming: data.upcoming,
      ipl: data.ipl || [],
      iplSectionTitle: data.iplSectionTitle || 'IPL',
      iplSeasonYear: data.iplSeasonYear || null,
      cached: true,
      stale: Boolean(data.stale),
      warning: data.warning || null,
      message,
      fetchedAt: data.fetchedAt,
    });
  } catch (e) {
    console.error('[sports] live', e.message);
    const rateLimited = /blocked|limit|quota|exceeded/i.test(e.message);
    return res.status(502).json({
      success: false,
      message: rateLimited
        ? 'Cricket API daily limit reached. Scores will return after the quota resets (usually within an hour).'
        : 'Could not load live cricket scores.',
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

function parseFeedLanguage(req) {
  const raw = req.query.language;
  if (!raw || String(raw).toLowerCase() === 'all') return null;
  return String(raw).toLowerCase();
}

/** GET /api/sports/news — cricket/sports posts from existing news DB. */
const getNews = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = Math.min(30, Math.max(5, parseInt(req.query.limit, 10) || 15));
    const langParam = parseFeedLanguage(req);
    const cacheKey = `sports:news:${langParam || 'all'}:${page}:${limit}`;
    const cached = memoryCache.get(cacheKey);
    if (cached) {
      return res.json({ ...cached, cached: true });
    }

    const categoryId = await resolveSportsCategoryId();
    let query = { status: 'approved' };
    if (categoryId && mongoose.Types.ObjectId.isValid(categoryId)) {
      query.category = new mongoose.Types.ObjectId(categoryId);
    } else {
      query.$or = [
        { tags: /cricket|ipl|sports|wpl|t20|odi/i },
        { title: /cricket|ipl|wpl|t20|odi/i },
      ];
    }
    query = applyLanguageFilter(query, langParam);

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

module.exports = { getLive, getMatch, getNews };
