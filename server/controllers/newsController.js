const mongoose = require('mongoose');
const NewsPost = require('../models/NewsPost');
const User = require('../models/User');
const Category = require('../models/Category');
const Comment = require('../models/Comment');
const { stripNewsWireTruncationMarkers } = require('../utils/stripNewsWireTruncation');
const { extractReadableArticle } = require('../services/articleExtractionService');
const { translateTextForFeed } = require('../services/rssService');

function cleanTextForClient(input) {
  return String(input || '')
    .replace(/&nbsp;|&#160;|&#xa0;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/\u00a0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Same filter as find(), but with ObjectId fields cast for aggregation $match. */
function feedMatchForAggregate(query) {
  const m = { ...query };
  if (m.category != null) {
    const id = String(m.category);
    if (mongoose.Types.ObjectId.isValid(id)) {
      m.category = new mongoose.Types.ObjectId(id);
    }
  }
  return m;
}

function sanitizeStoryTextFields(post) {
  const o = post && typeof post.toObject === 'function' ? post.toObject() : post;
  if (!o || typeof o !== 'object') return o;
  if (typeof o.body === 'string') {
    o.body = cleanTextForClient(stripNewsWireTruncationMarkers(o.body));
  }
  if (typeof o.summary === 'string') {
    o.summary = cleanTextForClient(stripNewsWireTruncationMarkers(o.summary));
  }
  return o;
}

// GET /api/news/extract?url=https://...
// Extract readable content from publisher pages (best-effort).
const extractArticle = async (req, res) => {
  try {
    const target = req.query.url;
    if (!target || typeof target !== 'string') {
      return res.status(400).json({ success: false, message: 'Missing url' });
    }
    const out = await extractReadableArticle(target, {
      timeoutMs: process.env.EXTRACT_TIMEOUT_MS,
      maxBytes: process.env.EXTRACT_MAX_BYTES,
      cacheTtlMs: process.env.EXTRACT_CACHE_TTL_MS,
    });
    if (!out.success) {
      return res.status(502).json(out);
    }
    return res.json(out);
  } catch (e) {
    return res.status(500).json({ success: false, message: 'Extraction failed.' });
  }
};

// GET /api/news/feed  — paginated, filterable by category and city
const getFeed = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      category,
      city,
      search,
      language,
      constituency,
      politicsScope,
      breaking,
      featured,
      days,
      sourceTypes,
    } = req.query;

    const query = { status: 'approved' };
    if (category) query.category = category;
    if (city) query['location.city'] = new RegExp(city, 'i');
    if (constituency && String(constituency).trim().toLowerCase() !== 'all') {
      query.constituency = new RegExp(`^${String(constituency).trim()}$`, 'i');
    }
    const ps = String(politicsScope || '').toLowerCase().trim();
    if (ps && ps !== 'all' && ['andhra', 'telangana', 'india', 'international'].includes(ps)) {
      query.politicsScope = ps;
    }

    const langParam =
      language && String(language).toLowerCase() !== 'all'
        ? String(language).toLowerCase()
        : null;

    if (breaking === 'true') query.isBreaking = true;
    if (featured === 'true') query.isFeatured = true;

    // Restrict feed to specific sources (e.g. NewsAPI + reporter/manual).
    // Example: ?sourceTypes=api,manual
    if (sourceTypes) {
      const allowed = new Set(['api', 'manual', 'rss', 'html']);
      const list = String(sourceTypes)
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .filter(Boolean)
        .filter((s) => allowed.has(s));
      if (list.length) {
        // Treat missing/null sourceType as "manual" (older docs may not have it).
        if (list.includes('manual')) {
          query.$and = [
            ...(query.$and || []),
            {
              $or: [
                { sourceType: { $in: list } },
                { sourceType: { $exists: false } },
                { sourceType: null },
              ],
            },
          ];
        } else {
          query.sourceType = { $in: list };
        }
      }
    }

    const searchOr = search
      ? [
          { title: new RegExp(search, 'i') },
          { body: new RegExp(search, 'i') },
          { tags: new RegExp(search, 'i') },
        ]
      : null;

    /** ISO 639-1 feed filter + franc ISO 639-3 (`tel`/`hin`) so RSS/API rows still match. */
    const languageClause = (() => {
      if (!langParam) return null;
      if (langParam === 'en') {
        return {
          $or: [
            { language: 'en' },
            { language: { $exists: false } },
            { language: null },
          ],
        };
      }
      if (langParam === 'te') {
        return {
          $or: [
            { language: 'te' },
            { originalLanguage: 'tel' },
          ],
        };
      }
      if (langParam === 'hi') {
        return {
          $or: [
            { language: 'hi' },
            { originalLanguage: 'hin' },
          ],
        };
      }
      return { language: langParam };
    })();

    const filterAnd = [...(query.$and || [])];
    if (searchOr) filterAnd.push({ $or: searchOr });
    if (languageClause) filterAnd.push(languageClause);
    if (filterAnd.length) query.$and = filterAnd;

    // Optional freshness window.
    // IMPORTANT: For "manual" posts we typically want to keep them visible even if older.
    // So when days is set, apply cutoff only to non-manual sources (e.g. NewsAPI).
    const daysNum = Number(days);
    if (Number.isFinite(daysNum) && daysNum > 0) {
      const cutoff = new Date(Date.now() - daysNum * 24 * 60 * 60 * 1000);
      query.$and = [
        ...(query.$and || []),
        {
          $or: [
            // Manual (reporter) posts: no cutoff.
            { sourceType: 'manual' },
            { sourceType: { $exists: false } },
            { sourceType: null },
            // Ingested sources: use published time when available, otherwise createdAt.
            { sourcePublishedAt: { $gte: cutoff } },
            { sourcePublishedAt: null, createdAt: { $gte: cutoff } },
            { sourcePublishedAt: { $exists: false }, createdAt: { $gte: cutoff } },
          ],
        },
      ];
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const lim = parseInt(limit);
    const match = feedMatchForAggregate(query);
    const total = await NewsPost.countDocuments(match);

    const userColl = User.collection.collectionName;
    const catColl = Category.collection.collectionName;

    const postsRaw = await NewsPost.aggregate([
      { $match: match },
      {
        $addFields: {
          _feedSort: {
            $ifNull: [
              '$sourcePublishedAt',
              { $ifNull: ['$scrapedAt', '$createdAt'] },
            ],
          },
        },
      },
      { $sort: { _feedSort: -1, _id: -1 } },
      { $skip: skip },
      { $limit: lim },
      {
        $lookup: {
          from: userColl,
          localField: 'reporter',
          foreignField: '_id',
          pipeline: [{ $project: { name: 1, avatar: 1 } }],
          as: '_reporterArr',
        },
      },
      {
        $lookup: {
          from: catColl,
          localField: 'category',
          foreignField: '_id',
          pipeline: [{ $project: { name: 1, slug: 1, icon: 1, color: 1 } }],
          as: '_categoryArr',
        },
      },
      {
        $set: {
          reporter: { $arrayElemAt: ['$_reporterArr', 0] },
          category: { $arrayElemAt: ['$_categoryArr', 0] },
        },
      },
      {
        $unset: ['_reporterArr', '_categoryArr', '_feedSort', 'likedBy', 'rejectionReason'],
      },
    ]);

    res.json({
      success: true,
      total,
      page: parseInt(page),
      pages: Math.ceil(total / parseInt(limit)),
      posts: postsRaw.map(sanitizeStoryTextFields),
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/news/:id — single article
const getPost = async (req, res) => {
  try {
    const post = await NewsPost.findOne({ _id: req.params.id, status: 'approved' })
      .populate('reporter', 'name avatar bio')
      .populate('category', 'name slug icon color');

    if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });

    // Increment view count (fire and forget)
    NewsPost.findByIdAndUpdate(post._id, { $inc: { views: 1 } }).exec();

    res.json({ success: true, post: sanitizeStoryTextFields(post) });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/news/:id/like
const toggleLike = async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Login required to like posts.' });
    }
    const post = await NewsPost.findById(req.params.id);
    if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });

    const userId = req.user._id;
    const alreadyLiked = post.likedBy.includes(userId);

    if (alreadyLiked) {
      post.likedBy.pull(userId);
      post.likes = Math.max(0, post.likes - 1);
    } else {
      post.likedBy.push(userId);
      post.likes += 1;
    }

    await post.save();
    res.json({ success: true, likes: post.likes, liked: !alreadyLiked });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/news/:id/bookmark
const toggleBookmark = async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Login required to bookmark posts.' });
    }
    const user = req.user;
    const postId = req.params.id;
    const isBookmarked = user.bookmarks.includes(postId);

    if (isBookmarked) {
      await User.findByIdAndUpdate(user._id, { $pull: { bookmarks: postId } });
    } else {
      await User.findByIdAndUpdate(user._id, { $addToSet: { bookmarks: postId } });
    }

    res.json({ success: true, bookmarked: !isBookmarked });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/news/bookmarks — user's saved posts
const getBookmarks = async (req, res) => {
  try {
    if (!req.user) {
      return res.json({ success: true, bookmarks: [] });
    }
    const user = await User.findById(req.user._id)
      .populate({
        path: 'bookmarks',
        populate: [
          { path: 'reporter', select: 'name avatar' },
          { path: 'category', select: 'name slug icon color' },
        ],
        match: { status: 'approved' },
      });

    const marks = user.bookmarks || [];
    res.json({
      success: true,
      bookmarks: marks.filter(Boolean).map(sanitizeStoryTextFields),
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/news/:id/comments
const getComments = async (req, res) => {
  try {
    const comments = await Comment.find({ post: req.params.id, isDeleted: false })
      .populate('user', 'name avatar')
      .sort({ createdAt: -1 })
      .limit(50);
    res.json({ success: true, comments });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/news/:id/comments
const addComment = async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Login required to comment.' });
    }
    const { text } = req.body;
    if (!text) return res.status(400).json({ success: false, message: 'Comment text required.' });

    const comment = await Comment.create({
      post: req.params.id,
      user: req.user._id,
      text,
    });

    await comment.populate('user', 'name avatar');
    res.status(201).json({ success: true, comment });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/news/translate
const translateText = async (req, res) => {
  try {
    const { text, targetLanguage } = req.body || {};
    const input = String(text || '').trim();
    const target = String(targetLanguage || '').trim().toLowerCase();

    if (!input) {
      return res.status(400).json({ success: false, message: 'text is required.' });
    }
    if (!['en', 'hi', 'te'].includes(target)) {
      return res.status(400).json({
        success: false,
        message: 'targetLanguage must be one of: en, hi, te.',
      });
    }

    const translatedText = await translateTextForFeed(input, target);
    return res.json({
      success: true,
      targetLanguage: target,
      translatedText: String(translatedText || input),
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

/** Public image proxy so the app can show hotlinked thumbnails (many sites block non-browser clients). */
const getProxyImage = async (req, res) => {
  const target = req.query.url;
  const refererOpt = req.query.referer;
  if (!target || typeof target !== 'string') {
    return res.status(400).type('text/plain').send('Missing url');
  }

  let parsed;
  try {
    parsed = new URL(target);
  } catch {
    return res.status(400).type('text/plain').send('Invalid url');
  }

  if (!['http:', 'https:'].includes(parsed.protocol)) {
    return res.status(400).type('text/plain').send('Invalid scheme');
  }

  const host = parsed.hostname.toLowerCase();
  if (
    host === 'localhost'
    || host.endsWith('.local')
    || host === 'metadata.google.internal'
    || /^(127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(host)
  ) {
    return res.status(403).type('text/plain').send('Forbidden host');
  }

  let referer = `${parsed.protocol}//${parsed.host}/`;
  if (refererOpt && typeof refererOpt === 'string') {
    try {
      const r = new URL(refererOpt);
      if (['http:', 'https:'].includes(r.protocol)) referer = r.href;
    } catch { /* keep default */ }
  }

  // The Hindu CDN often rejects article URLs as Referer; site root works for thgimgs.com.
  if (host === 'thgimgs.com' || host.endsWith('.thgimgs.com')) {
    referer = 'https://www.thehindu.com/';
  }

  const ac = new AbortController();
  const to = setTimeout(() => ac.abort(), 15000);
  try {
    const baseHeaders = {
      'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
      Accept: 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
    };

    // Attempt 1: include Referer (many CDNs require it)
    let upstream = await fetch(parsed.href, {
      redirect: 'follow',
      signal: ac.signal,
      headers: {
        ...baseHeaders,
        Referer: referer,
        Origin: referer,
      },
    });

    // Attempt 2: some hosts *block* unknown referers; retry without it for 403/401.
    if (!upstream.ok && (upstream.status === 401 || upstream.status === 403)) {
      upstream = await fetch(parsed.href, {
        redirect: 'follow',
        signal: ac.signal,
        headers: baseHeaders,
      });
    }
    clearTimeout(to);
    if (!upstream.ok) {
      return res
        .status(502)
        .type('text/plain')
        .send(`Upstream failed (${upstream.status})`);
    }

    const ct = (upstream.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
    const looksImage = /\.(jpg|jpeg|png|gif|webp|avif|bmp)(\?|#|$)/i.test(parsed.pathname + parsed.search);
    const okCt =
      !ct
      || ct.startsWith('image/')
      || (looksImage && (ct === 'application/octet-stream' || ct === 'binary/octet-stream'));

    if (!okCt) {
      return res.status(502).type('text/plain').send('Not an image');
    }

    const buf = Buffer.from(await upstream.arrayBuffer());
    if (buf.length > 5 * 1024 * 1024) {
      return res.status(413).type('text/plain').send('Too large');
    }

    const outType = ct && ct.startsWith('image/') ? ct : 'image/jpeg';
    res.setHeader('Content-Type', outType);
    res.setHeader('Cache-Control', 'public, max-age=3600');
    res.send(buf);
  } catch (e) {
    clearTimeout(to);
    return res.status(502).type('text/plain').send('Fetch failed');
  }
};

module.exports = {
  getFeed,
  getPost,
  getProxyImage,
  extractArticle,
  toggleLike,
  toggleBookmark,
  getBookmarks,
  getComments,
  addComment,
  translateText,
};