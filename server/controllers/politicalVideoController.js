const mongoose = require('mongoose');
const NewsPost = require('../models/NewsPost');
const { POLITICAL_LABELS } = require('../config/politicalVideoConfig');
const { runPoliticalVideoIngestion } = require('../services/politicalVideoIngestionService');

function toClientRow(post) {
  const o = post.toObject ? post.toObject() : post;
  const thumb =
    o.media?.[0]?.thumbnail
    || o.media?.[0]?.url
    || (o.youtube?.videoId ? `https://i.ytimg.com/vi/${o.youtube.videoId}/hqdefault.jpg` : null);
  return {
    id: String(o._id),
    title: o.title,
    thumbnail: thumb,
    videoId: o.youtube?.videoId || null,
    category: o.videoCategory || null,
    language: o.language || 'en',
    channelName: o.youtube?.channelTitle || o.sourceName || 'YouTube',
    publishedAt: o.sourcePublishedAt || o.createdAt,
    embedUrl: o.youtube?.embedUrl || null,
    watchUrl: o.youtube?.watchUrl || o.sourceUrl || null,
    classificationMethod: o.videoClassificationMethod || null,
    classificationScore: o.videoClassificationScore ?? null,
    post: o,
  };
}

/** GET /api/political-videos/feed — vertical political reels (YouTube embed only). */
const getPoliticalFeed = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      language,
      category,
    } = req.query;

    const query = {
      status: 'approved',
      sourceType: 'youtube',
      'youtube.videoId': { $exists: true, $nin: [null, ''] },
      videoCategory: { $in: POLITICAL_LABELS },
    };

    if (language && String(language).toLowerCase() !== 'all') {
      query.language = String(language).toLowerCase();
    }
    if (category && POLITICAL_LABELS.includes(String(category).toLowerCase())) {
      query.videoCategory = String(category).toLowerCase();
    }

    const lim = Math.min(50, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (Math.max(1, parseInt(page, 10) || 1) - 1) * lim;

    const [rows, total] = await Promise.all([
      NewsPost.find(query)
        .sort({ sourcePublishedAt: -1, createdAt: -1 })
        .skip(skip)
        .limit(lim)
        .populate('category', 'name slug')
        .lean(),
      NewsPost.countDocuments(query),
    ]);

    const videos = rows.map(toClientRow);

    return res.json({
      success: true,
      videos,
      posts: rows,
      page: parseInt(page, 10) || 1,
      pages: Math.ceil(total / lim) || 1,
      total,
    });
  } catch (e) {
    return res.status(500).json({ success: false, message: e.message });
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
};
