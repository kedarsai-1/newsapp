const { Prisma, prisma } = require('../config/prisma');
const { stripNewsWireTruncationMarkers } = require('../utils/stripNewsWireTruncation');
const {
  canonicalizeUrl,
  hashUrl,
  normalizeTitle,
  titleFingerprint,
  summaryFingerprint,
  summariesAreNearDuplicates,
} = require('../utils/storyDedupe');
const { extractReadableArticle } = require('../services/articleExtractionService');
const { translateTextForFeed } = require('../services/rssService');
const { filterPostsForCategory } = require('../utils/categoryRelevance');
const { POLITICAL_LABELS } = require('../config/politicalVideoConfig');
const {
  serializeNewsPost,
  serializeComment,
} = require('../utils/serializers');
const { newsPostInclude } = require('../utils/prismaNewsPost');

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

function titleWordSet(title) {
  const norm = normalizeTitle(title);
  if (!norm) return new Set();
  return new Set(norm.split(/\s+/).filter((w) => w.length > 2));
}

function titlesAreNearDuplicates(a, b) {
  const A = titleWordSet(a);
  const B = titleWordSet(b);
  if (A.size < 4 || B.size < 4) return false;
  let inter = 0;
  for (const w of A) {
    if (B.has(w)) inter += 1;
  }
  const ratio = inter / Math.min(A.size, B.size);
  return ratio >= 0.72;
}

/** Remove duplicate headlines/URLs/summaries within a single feed page response. */
function dedupeFeedPosts(rows) {
  const seen = new Set();
  const keptTitles = [];
  const keptSummaries = [];
  const out = [];
  for (const p of rows) {
    const urlKey = p.sourceUrlHash
      || (p.sourceUrl ? hashUrl(canonicalizeUrl(p.sourceUrl) || String(p.sourceUrl)) : '');
    const titleKey = p.titleNormalized || normalizeTitle(p.title);
    const fpKey = p.titleFingerprint || titleFingerprint(p.title);
    const sumKey = p.summaryFingerprint || summaryFingerprint(p.summary);
    const keys = [urlKey, fpKey, titleKey, sumKey].filter((k) => k && k.length > 8);
    if (keys.length && keys.some((k) => seen.has(k))) continue;
    if (keptTitles.some((t) => titlesAreNearDuplicates(t, p.title))) continue;
    const summaryText = String(p.summary || '').trim();
    if (
      summaryText.length >= 40
      && keptSummaries.some((s) => summariesAreNearDuplicates(s, summaryText))
    ) {
      continue;
    }
    for (const k of keys) seen.add(k);
    keptTitles.push(p.title);
    if (summaryText.length >= 40) keptSummaries.push(summaryText);
    out.push(p);
  }
  return out;
}

function containsInsensitive(value) {
  return { contains: String(value), mode: 'insensitive' };
}

function languageWhere(langParam) {
  if (!langParam) return null;
  const lang = String(langParam).toLowerCase();
  if (lang === 'en') {
    return { language: 'en' };
  }
  if (lang === 'te') {
    return {
      OR: [
        { language: 'te' },
        { originalLanguage: 'tel' },
        { sourceName: containsInsensitive('telugu') },
        { sourceName: containsInsensitive('eenadu') },
        { sourceName: containsInsensitive('sakshi') },
      ],
    };
  }
  if (lang === 'hi') {
    return {
      OR: [
        { language: 'hi' },
        { originalLanguage: 'hin' },
        { sourceName: containsInsensitive('hindi') },
        { sourceName: containsInsensitive('amar ujala') },
        { sourceName: containsInsensitive('jagran') },
        { sourceName: containsInsensitive('abp') },
      ],
    };
  }
  return { language: lang };
}

/** Politics tab scope filters — keeps AP/TG out of India/International buckets. */
function politicsScopeWhere(scope, langParam) {
  const ps = String(scope || '').toLowerCase().trim();
  if (!ps || ps === 'all') return null;

  if (ps === 'india') {
    return { OR: [{ politicsScope: { in: ['india', 'all'] } }, { politicsScope: null }] };
  }
  if (ps === 'international') {
    return { politicsScope: 'international' };
  }
  if (ps === 'north') {
    return {
      OR: [
        { politicsScope: { in: ['north', 'states', 'delhi'] } },
        { title: containsInsensitive('uttar pradesh') },
        { title: containsInsensitive('delhi') },
      ],
    };
  }
  if (ps === 'states' || ps === 'delhi') {
    return { politicsScope: ps };
  }
  if (ps === 'andhra') {
    return {
      OR: [
        { politicsScope: 'andhra' },
        { title: containsInsensitive('andhra') },
        { body: containsInsensitive('andhra') },
      ],
    };
  }
  if (ps === 'telangana') {
    return {
      OR: [
        { politicsScope: 'telangana' },
        { title: containsInsensitive('telangana') },
        { title: containsInsensitive('hyderabad') },
        { body: containsInsensitive('telangana') },
      ],
    };
  }
  return null;
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
      hasVideo,
      politicalOnly,
    } = req.query;

    const where = { status: 'approved' };
    const andFilters = [];
    if (String(politicalOnly || '').toLowerCase() === 'true') {
      where.videoCategory = { in: POLITICAL_LABELS };
      where.sourceType = 'youtube';
      where.youtubeVideoId = { not: null };
    }
    let categorySlugFilter = null;
    let politicsCategoryId = null;
    let localCategoryId = null;

    // Shorts / video feeds: only posts that include at least one video asset.
    if (String(hasVideo || '').toLowerCase() === 'true') {
      andFilters.push({
        OR: [
          { media: { some: { type: 'video', url: { not: '' } } } },
          { youtubeVideoId: { not: null } },
        ],
      });
    }
    if (category) {
      where.categoryId = String(category);
      if (String(category).length >= 20) {
        politicsCategoryId = String(category);
        const catDoc = await prisma.category.findUnique({ where: { id: String(category) }, select: { slug: true } });
        categorySlugFilter = catDoc?.slug ? String(catDoc.slug).toLowerCase() : null;
        if (categorySlugFilter === 'politics' || categorySlugFilter === 'local') {
          const localCat = await prisma.category.findFirst({ where: { slug: 'local', isActive: true }, select: { id: true } });
          if (localCat?.id) localCategoryId = localCat.id;
        }
      }
    }
    if (city) where.locationCity = containsInsensitive(city);
    if (constituency && String(constituency).trim().toLowerCase() !== 'all') {
      where.constituency = { equals: String(constituency).trim(), mode: 'insensitive' };
    }
    const langParam =
      language && String(language).toLowerCase() !== 'all'
        ? String(language).toLowerCase()
        : null;

    const politicsScopeParam = String(politicsScope || '').toLowerCase().trim();

    if (breaking === 'true') where.isBreaking = true;
    if (featured === 'true') where.isFeatured = true;

    // Restrict feed to specific sources (e.g. NewsAPI + reporter/manual).
    // Example: ?sourceTypes=api,manual
    if (sourceTypes) {
      const allowed = new Set(['api', 'manual', 'rss', 'html', 'youtube']);
      const list = String(sourceTypes)
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .filter(Boolean)
        .filter((s) => allowed.has(s));
      if (list.length) {
        // Treat missing/null sourceType as "manual" (older docs may not have it).
        if (list.includes('manual')) {
          andFilters.push({ sourceType: { in: list } });
        } else {
          where.sourceType = { in: list };
        }
      }
    }

    const searchOr = search
      ? [
          { title: containsInsensitive(search) },
          { body: containsInsensitive(search) },
          { sourceName: containsInsensitive(search) },
        ]
      : null;

    /** ISO 639-1 feed filter + franc ISO 639-3 (`tel`/`hin`) so RSS/API rows still match. */
    const languageClause = languageWhere(langParam);

    const filterAnd = [...andFilters];
    if (searchOr) filterAnd.push({ OR: searchOr });
    if (languageClause) filterAnd.push(languageClause);
    const ps = politicsScopeParam;
    const regionalPolitics = ps === 'andhra' || ps === 'telangana' || ps === 'north';
    if (ps && ps !== 'all' && ['andhra', 'telangana', 'india', 'international', 'north', 'states', 'delhi'].includes(ps)) {
      const teScopes = new Set(['andhra', 'telangana', 'india', 'international']);
      const hiScopes = new Set(['india', 'international', 'north', 'states', 'delhi']);
      const enHiScopes = new Set(['india', 'international']);
      const scopeOk = !langParam
        || (langParam === 'te' && teScopes.has(ps))
        || (langParam === 'hi' && hiScopes.has(ps))
        || (langParam === 'en' && enHiScopes.has(ps))
        || (langParam !== 'te' && langParam !== 'en' && langParam !== 'hi');
      if (scopeOk) {
        const scopeClause = politicsScopeWhere(ps, langParam);
        if (
          regionalPolitics
          && categorySlugFilter === 'politics'
          && politicsCategoryId
          && localCategoryId
        ) {
          delete where.categoryId;
          const localBranch =
            ps === 'north'
              ? { categoryId: localCategoryId, politicsScope: { in: ['north', 'states', 'delhi'] } }
              : { categoryId: localCategoryId, politicsScope: ps };
          const orBranches = [
            scopeClause
              ? { AND: [{ categoryId: politicsCategoryId }, scopeClause] }
              : { categoryId: politicsCategoryId },
            localBranch,
          ];
          filterAnd.push({ OR: orBranches });
        } else if (scopeClause) {
          filterAnd.push(scopeClause);
        }
      }
    }
    if (filterAnd.length) where.AND = filterAnd;

    // Optional freshness window.
    // IMPORTANT: For "manual" posts we typically want to keep them visible even if older.
    // So when days is set, apply cutoff only to non-manual sources (e.g. NewsAPI).
    const daysNum = Number(days);
    if (Number.isFinite(daysNum) && daysNum > 0) {
      const cutoff = new Date(Date.now() - daysNum * 24 * 60 * 60 * 1000);
      where.AND = [
        ...(where.AND || []),
        {
          OR: [
            // Manual (reporter) posts: no cutoff.
            { sourceType: 'manual' },
            // Ingested sources: use published time when available, otherwise createdAt.
            { sourcePublishedAt: { gte: cutoff } },
            { sourcePublishedAt: null, createdAt: { gte: cutoff } },
          ],
        },
      ];
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);
    const lim = parseInt(limit);
    const [total, rows] = await Promise.all([
      prisma.newsPost.count({ where }),
      prisma.newsPost.findMany({
        where,
        include: newsPostInclude,
        orderBy: [
          { sourcePublishedAt: 'desc' },
          { scrapedAt: 'desc' },
          { createdAt: 'desc' },
        ],
        skip,
        take: lim,
      }),
    ]);

    let posts = dedupeFeedPosts(rows.map((p) => serializeNewsPost(p))).map(sanitizeStoryTextFields);
    if (categorySlugFilter === 'politics' || categorySlugFilter === 'local') {
      posts = filterPostsForCategory(posts, categorySlugFilter, {
        politicsScope: politicsScopeParam,
      });
    }

    res.json({
      success: true,
      total,
      page: parseInt(page),
      pages: Math.ceil(total / parseInt(limit)),
      posts,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// GET /api/news/:id — single article
const getPost = async (req, res) => {
  try {
    const post = await prisma.newsPost.findFirst({
      where: { id: req.params.id, status: 'approved' },
      include: newsPostInclude,
    });

    if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });

    // Increment view count (fire and forget)
    prisma.newsPost.update({
      where: { id: post.id },
      data: { views: { increment: 1 } },
    }).catch(() => {});

    res.json({ success: true, post: sanitizeStoryTextFields(serializeNewsPost(post)) });
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
    const post = await prisma.newsPost.findUnique({ where: { id: req.params.id }, select: { id: true } });
    if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });

    const userId = req.user._id;
    const existing = await prisma.postLike.findUnique({
      where: { userId_postId: { userId, postId: post.id } },
    });
    const updated = await prisma.$transaction(async (tx) => {
      if (existing) {
        await tx.postLike.delete({ where: { userId_postId: { userId, postId: post.id } } });
        return tx.newsPost.update({
          where: { id: post.id },
          data: { likes: { decrement: 1 } },
          select: { likes: true },
        });
      }
      await tx.postLike.create({ data: { userId, postId: post.id } });
      return tx.newsPost.update({
        where: { id: post.id },
        data: { likes: { increment: 1 } },
        select: { likes: true },
      });
    });

    res.json({ success: true, likes: Math.max(0, updated.likes), liked: !existing });
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
    const postId = req.params.id;
    const post = await prisma.newsPost.findUnique({ where: { id: postId }, select: { id: true } });
    if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });
    const key = { userId_postId: { userId: req.user._id, postId } };
    const existing = await prisma.userBookmark.findUnique({ where: key });

    if (existing) {
      await prisma.userBookmark.delete({ where: key });
    } else {
      await prisma.userBookmark.create({ data: { userId: req.user._id, postId } });
    }

    res.json({ success: true, bookmarked: !existing });
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
    const rows = await prisma.userBookmark.findMany({
      where: { userId: req.user._id, post: { status: 'approved' } },
      include: { post: { include: newsPostInclude } },
      orderBy: { createdAt: 'desc' },
    });
    const marks = rows.map((row) => serializeNewsPost(row.post));
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
    const comments = await prisma.comment.findMany({
      where: { postId: req.params.id, isDeleted: false },
      include: { user: true },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
    res.json({ success: true, comments: comments.map(serializeComment) });
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

    const comment = await prisma.comment.create({
      data: {
        postId: req.params.id,
        userId: req.user._id,
        text,
      },
      include: { user: true },
    });

    res.status(201).json({ success: true, comment: serializeComment(comment) });
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
  if (host.includes('abplive.com')) referer = 'https://www.abplive.com/';
  if (host.includes('amarujala.com')) referer = 'https://www.amarujala.com/';
  if (host.includes('bhaskar.com')) referer = 'https://www.bhaskar.com/';
  if (host.includes('jagran.com')) referer = 'https://www.jagran.com/';
  if (host.includes('prabhatkhabar.com')) referer = 'https://www.prabhatkhabar.com/';
  if (host.includes('ndtv.com')) referer = 'https://www.ndtv.com/';
  if (host.includes('theprint.in')) referer = 'https://hindi.theprint.in/';
  if (host.includes('tv9telugu.com')) referer = 'https://www.tv9telugu.com/';
  if (host.includes('ntvtelugu.com')) referer = 'https://www.ntvtelugu.com/';
  if (host.includes('bbc.co.uk') || host.includes('bbci.co.uk')) referer = 'https://www.bbc.com/hindi';

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