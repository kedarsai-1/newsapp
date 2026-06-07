const { Prisma, prisma } = require('../config/prisma');
const { reverseGeocode } = require('../utils/geocode');
const { stripNewsWireTruncationMarkers } = require('../utils/stripNewsWireTruncation');
const {
  canonicalizeUrl,
  hashUrl,
  normalizeTitle,
  titleFingerprint,
  summaryFingerprint,
  summariesAreNearDuplicates,
  titlesAreNearDuplicates,
} = require('../utils/storyDedupe');
const { extractReadableArticle } = require('../services/articleExtractionService');
const { translateTextForFeed } = require('../services/rssService');
const { filterPostsForCategory } = require('../utils/categoryRelevance');
const { POLITICAL_LABELS } = require('../config/politicalVideoConfig');
const {
  serializeNewsPost,
  serializeFeedPost,
  serializeComment,
} = require('../utils/serializers');
const { decodeHtmlEntities } = require('../utils/decodeHtmlEntities');
const { newsPostInclude, feedListInclude } = require('../utils/prismaNewsPost');
const feedResponseCache = require('../utils/feedResponseCache');
const { getPublisherReferer } = require('../utils/publisherReferer');
const {
  getShortsExcludeCategoryIds,
  prismaShortsExcludePoliticsClause,
  filterPostsForShortsFeed,
} = require('../utils/shortsFeedFilter');
const { capYoutubeInMixedFeed } = require('../utils/youtubeCap');
const {
  parseFeedPagination,
  buildFeedPaginationResponse,
  needsPostFetchLoop,
  fetchFeedPagePosts,
} = require('../utils/feedPagination');

const VALID_FEED_LANGUAGES = new Set(['en', 'hi', 'te']);
const VALID_POLITICS_SCOPES = new Set([
  'andhra', 'telangana', 'india', 'international', 'north', 'states', 'delhi', 'all',
]);
const MAX_SEARCH_LENGTH = 200;
const MAX_COMMENT_LENGTH = 2000;
const MAX_TRANSLATE_TEXT_LENGTH = 5000;
const MAX_CHAT_MESSAGE_LENGTH = 2000;

function cleanTextForClient(input) {
  return decodeHtmlEntities(
    String(input || '')
      .replace(/<[^>]*>/g, ' ')
      .replace(/\u00a0/g, ' '),
  );
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

function sanitizeSearchInput(value) {
  return String(value || '').replace(/\0/g, '').trim();
}

function containsInsensitive(value) {
  return { contains: sanitizeSearchInput(value), mode: 'insensitive' };
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function isValidUuid(value) {
  return UUID_RE.test(String(value || '').trim());
}

function respondInvalidPostId(res) {
  return res.status(400).json({ success: false, message: 'Invalid post id' });
}

function sendPostRouteError(res, error) {
  if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2023') {
    return respondInvalidPostId(res);
  }
  return res.status(500).json({ success: false, message: error.message });
}

async function resolveCategoryFilter(categoryParam) {
  const raw = String(categoryParam || '').trim();
  if (!raw) return null;

  if (isValidUuid(raw)) {
    const catDoc = await prisma.category.findUnique({
      where: { id: raw },
      select: { id: true, slug: true },
    });
    if (!catDoc) return { error: 'Invalid category.' };
    return {
      categoryId: catDoc.id,
      categorySlugFilter: catDoc.slug ? String(catDoc.slug).toLowerCase() : null,
    };
  }

  const slug = raw.toLowerCase();
  const catDoc = await prisma.category.findFirst({
    where: { slug, isActive: true },
    select: { id: true, slug: true },
  });
  if (!catDoc) return { error: 'Invalid category.' };
  return {
    categoryId: catDoc.id,
    categorySlugFilter: String(catDoc.slug).toLowerCase(),
  };
}

function languageWhere(langParam) {
  if (!langParam) return null;
  const lang = String(langParam).toLowerCase();
  if (lang === 'en') {
    return {
      language: 'en',
      AND: [
        { NOT: { language: { in: ['hi', 'te'] } } },
        { NOT: { originalLanguage: { in: ['hin', 'tel', 'hi', 'te'] } } },
        {
          NOT: {
            OR: [
              { sourceName: containsInsensitive('telugu') },
              { sourceName: containsInsensitive('eenadu') },
              { sourceName: containsInsensitive('sakshi') },
              { sourceName: containsInsensitive('tv9') },
              { sourceName: containsInsensitive('ntv') },
              { sourceName: containsInsensitive('v6') },
              { sourceName: containsInsensitive('velugu') },
              { sourceName: containsInsensitive('andhra jyothy') },
              { sourceName: containsInsensitive('mana telangana') },
              { sourceName: containsInsensitive('10tv') },
              { sourceName: containsInsensitive('123telugu') },
              { sourceName: containsInsensitive('hindi') },
              { sourceName: containsInsensitive('amar ujala') },
              { sourceName: containsInsensitive('jagran') },
              { sourceName: containsInsensitive('abp') },
              { sourceName: containsInsensitive('ndtv khabar') },
              { sourceName: containsInsensitive('prabhat') },
              { sourceName: containsInsensitive('bhaskar') },
              { sourceName: containsInsensitive('the print hindi') },
              { sourceName: containsInsensitive('bbc hindi') },
              { sourceName: containsInsensitive('print hindi') },
            ],
          },
        },
      ],
    };
  }
  if (lang === 'te') {
    return {
      OR: [
        { language: 'te' },
        { originalLanguage: 'tel' },
        { sourceName: containsInsensitive('telugu') },
        { sourceName: containsInsensitive('eenadu') },
        { sourceName: containsInsensitive('sakshi') },
        { sourceName: containsInsensitive('tv9') },
        { sourceName: containsInsensitive('ntv') },
        { sourceName: containsInsensitive('v6') },
        { sourceName: containsInsensitive('velugu') },
        { sourceName: containsInsensitive('andhra jyothy') },
        { sourceName: containsInsensitive('mana telangana') },
        { sourceName: containsInsensitive('10tv') },
        { sourceName: containsInsensitive('123telugu') },
      ],
    };
  }
  if (lang === 'hi') {
    return {
      OR: [
        { language: 'hi' },
        { originalLanguage: 'hin' },
      ],
    };
  }
  return null;
}

function politicsScopeAllowedForLanguage(scope, langParam) {
  const ps = String(scope || '').toLowerCase().trim();
  if (!ps || ps === 'all') return true;
  if (!langParam) return true;
  const teScopes = new Set(['andhra', 'telangana', 'india', 'international']);
  const hiScopes = new Set(['india', 'international', 'north', 'states', 'delhi']);
  const enHiScopes = new Set(['india', 'international']);
  if (langParam === 'te') return teScopes.has(ps);
  if (langParam === 'hi') return hiScopes.has(ps);
  if (langParam === 'en') return enHiScopes.has(ps);
  return true;
}

function applyEnglishScriptFilter(posts) {
  const hasDevanagari = (str) => /[\u0900-\u097F]/.test(str);
  const hasTelugu = (str) => /[\u0C00-\u0C7F]/.test(str);
  return posts.filter((p) => {
    const titleStr = p.title || '';
    return !hasDevanagari(titleStr) && !hasTelugu(titleStr);
  });
}

function buildFeedPostProcessor({
  langParam,
  sourceTypes,
  excludePoliticsFeed,
  categorySlugFilter,
  politicsScopeParam,
}) {
  return (posts) => {
    let out = posts;
    if (langParam === 'en') {
      out = applyEnglishScriptFilter(out);
    }
    out = capYoutubeInMixedFeed(out, sourceTypes);
    if (excludePoliticsFeed) {
      out = filterPostsForShortsFeed(out);
    }
    if (categorySlugFilter === 'politics' || categorySlugFilter === 'local') {
      out = filterPostsForCategory(out, categorySlugFilter, {
        politicsScope: politicsScopeParam,
      });
    }
    return out;
  };
}

function politicsScopeWhere(scope, langParam) {
  const ps = String(scope || '').toLowerCase().trim();
  if (!ps || ps === 'all') return null;

  if (ps === 'india') {
    return {
      AND: [
        {
          OR: [
            { politicsScope: { in: ['india', 'all'] } },
            { politicsScope: null },
          ],
        },
        {
          NOT: {
            politicsScope: {
              in: ['andhra', 'telangana', 'north', 'states', 'delhi', 'international'],
            },
          },
        },
      ],
    };
  }
  if (ps === 'international') {
    return { politicsScope: 'international' };
  }
  if (ps === 'north') {
    return {
      OR: [
        { politicsScope: { in: ['north', 'states', 'delhi'] } },
        {
          politicsScope: { in: ['india', null] },
          OR: [
            { title: containsInsensitive('uttar pradesh') },
            { title: containsInsensitive('delhi') },
            { title: containsInsensitive('उत्तर प्रदेश') },
            { title: containsInsensitive('दिल्ली') },
            { title: containsInsensitive('पंजाब') },
            { title: containsInsensitive('बिहार') },
          ],
        },
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
        {
          politicsScope: { in: ['india', null] },
          OR: [
            { title: containsInsensitive('andhra') },
            { title: containsInsensitive('ఆంధ్ర') },
            { title: containsInsensitive('amaravati') },
            { title: containsInsensitive('అమరావతి') },
            { title: containsInsensitive('vijayawada') },
            { title: containsInsensitive('విజయవాడ') },
            { title: containsInsensitive('visakhapatnam') },
            { title: containsInsensitive('vizag') },
          ],
        },
      ],
    };
  }
  if (ps === 'telangana') {
    return {
      OR: [
        { politicsScope: 'telangana' },
        {
          politicsScope: { in: ['india', null] },
          OR: [
            { title: containsInsensitive('telangana') },
            { title: containsInsensitive('తెలంగాణ') },
            { title: containsInsensitive('hyderabad') },
            { title: containsInsensitive('హైదరాబాద్') },
            { title: containsInsensitive('secunderabad') },
          ],
        },
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
const mapFeedRow = (row) => sanitizeStoryTextFields(serializeFeedPost(row));

const getFeed = async (req, res) => {
  try {
    const cached = await feedResponseCache.getCachedFeed(req.query);
    if (cached) {
      feedResponseCache.applyEdgeCacheHeaders(res, req, cached.ttlMs);
      let posts = cached.body.posts || [];
      if (req.user && req.user.id) {
        const seenRows = await prisma.postSeen.findMany({
          where: {
            userId: req.user.id,
            postId: { in: posts.map((p) => p.id) },
          },
          select: { postId: true },
        });
        const seenPostIds = new Set(seenRows.map((r) => r.postId));
        posts = posts.map((p) => (seenPostIds.has(p.id) ? { ...p, seen: true } : { ...p, seen: false }));
      } else if (posts.some((p) => p.seen !== false)) {
        posts = posts.map((p) => ({ ...p, seen: false }));
      }
      return res.json({ ...cached.body, posts, cached: true });
    }

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
      excludePolitics,
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
    const excludePoliticsFeed =
      String(excludePolitics || '').toLowerCase() === 'true'
      || (
        String(hasVideo || '').toLowerCase() === 'true'
        && String(politicalOnly || '').toLowerCase() !== 'true'
        && String(sourceTypes || '').toLowerCase() === 'youtube'
        && !category
      );
    if (excludePoliticsFeed) {
      const excludeCategoryIds = await getShortsExcludeCategoryIds(prisma);
      andFilters.push(prismaShortsExcludePoliticsClause(excludeCategoryIds));
      andFilters.push({
        OR: [
          { youtubeIsShort: true },
          {
            AND: [
              { youtubeVideoId: { not: null } },
              { youtubeIsShort: { not: false } },
            ],
          },
        ],
      });
    }
    if (category) {
      const resolved = await resolveCategoryFilter(category);
      if (resolved?.error) {
        return res.status(400).json({ success: false, message: resolved.error });
      }
      where.categoryId = resolved.categoryId;
      categorySlugFilter = resolved.categorySlugFilter;
      politicsCategoryId = resolved.categoryId;
      if (categorySlugFilter === 'politics' || categorySlugFilter === 'local') {
        const localCat = await prisma.category.findFirst({
          where: { slug: 'local', isActive: true },
          select: { id: true },
        });
        if (localCat?.id) localCategoryId = localCat.id;
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

    if (langParam && !VALID_FEED_LANGUAGES.has(langParam)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid language. Use en, hi, te, or all.',
      });
    }

    if (search && String(search).length > MAX_SEARCH_LENGTH) {
      return res.status(400).json({
        success: false,
        message: `Search query too long (max ${MAX_SEARCH_LENGTH} characters).`,
      });
    }

    const politicsScopeParam = String(politicsScope || '').toLowerCase().trim();
    if (politicsScopeParam && politicsScopeParam !== 'all' && !VALID_POLITICS_SCOPES.has(politicsScopeParam)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid politicsScope.',
      });
    }
    if (
      politicsScopeParam
      && politicsScopeParam !== 'all'
      && langParam
      && !politicsScopeAllowedForLanguage(politicsScopeParam, langParam)
    ) {
      return res.status(400).json({
        success: false,
        message: `politicsScope "${politicsScopeParam}" is not available for language "${langParam}".`,
      });
    }

    const { pageNum, limitNum, skip } = parseFeedPagination(page, limit);

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
    if (ps && ps !== 'all' && VALID_POLITICS_SCOPES.has(ps) && ps !== 'all') {
      const scopeOk = politicsScopeAllowedForLanguage(ps, langParam);
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

    const orderBy = [
      { sourcePublishedAt: 'desc' },
      { scrapedAt: 'desc' },
      { createdAt: 'desc' },
    ];
    const applyPostFilters = buildFeedPostProcessor({
      langParam,
      sourceTypes,
      excludePoliticsFeed,
      categorySlugFilter,
      politicsScopeParam,
    });

    let posts;
    let hasMore;
    const useFetchLoop = needsPostFetchLoop({
      langParam,
      excludePoliticsFeed,
      categorySlugFilter,
      sourceTypes,
    });

    if (useFetchLoop) {
      const fetched = await fetchFeedPagePosts({
        prisma,
        where,
        skip,
        limitNum,
        include: feedListInclude,
        orderBy,
        mapRow: mapFeedRow,
        applyPostFilters: (rows) => applyPostFilters(dedupeFeedPosts(rows)),
      });
      posts = fetched.posts;
      hasMore = fetched.hasMore;
    } else {
      const [rows] = await Promise.all([
        prisma.newsPost.findMany({
          where,
          include: feedListInclude,
          orderBy,
          skip,
          take: limitNum,
        }),
      ]);
      posts = applyPostFilters(dedupeFeedPosts(rows.map(mapFeedRow)));
      posts = applyPostFilters(posts);
      const probe = posts.length === limitNum
        ? await prisma.newsPost.findMany({
          where,
          skip: skip + limitNum,
          take: 1,
          select: { id: true },
        })
        : [];
      hasMore = posts.length === limitNum && probe.length > 0;
    }

    const pagination = buildFeedPaginationResponse(pageNum, limitNum, posts.length, hasMore);
    const payload = {
      success: true,
      total: pagination.total,
      page: pagination.page,
      pages: pagination.pages,
      hasMore: pagination.hasMore,
      posts,
      cached: false,
    };
    await feedResponseCache.setCachedFeed(req.query, payload);

    let finalPosts = posts;
    if (req.user && req.user.id) {
      const seenRows = await prisma.postSeen.findMany({
        where: {
          userId: req.user.id,
          postId: { in: posts.map((p) => p.id) },
        },
        select: { postId: true },
      });
      const seenPostIds = new Set(seenRows.map((r) => r.postId));
      finalPosts = posts.map((p) => ({ ...p, seen: seenPostIds.has(p.id) }));
    } else {
      finalPosts = posts.map((p) => (p.seen === false ? p : { ...p, seen: false }));
    }

    feedResponseCache.applyEdgeCacheHeaders(res, req, feedResponseCache.feedTtlForQuery(req.query));
    res.json({ ...payload, posts: finalPosts });
  } catch (error) {
    console.error('[news] getFeed error:', error.message);
    res.status(500).json({ success: false, message: 'Failed to load news feed.' });
  }
};

// GET /api/news/:id — single article
const getPost = async (req, res) => {
  try {
    const postId = String(req.params.id || '').trim();
    if (!isValidUuid(postId)) {
      return respondInvalidPostId(res);
    }

    // Mark as seen on detail fetch if logged in
    if (req.user && req.user.id) {
      await prisma.postSeen.upsert({
        where: { userId_postId: { userId: req.user.id, postId } },
        update: {},
        create: { userId: req.user.id, postId },
      }).catch((e) => {
        console.error('[news] failed to mark seen on getPost:', e.message);
      });
    }

    const cached = await feedResponseCache.getCachedPost(postId);
    if (cached) {
      feedResponseCache.applyEdgeCacheHeaders(res, req, cached.ttlMs);
      prisma.newsPost.update({
        where: { id: postId },
        data: { views: { increment: 1 } },
      }).catch(() => {});

      const postWithSeen = {
        ...cached.body.post,
        seen: req.user && req.user.id ? true : false,
      };
      return res.json({ ...cached.body, post: postWithSeen, cached: true });
    }

    const post = await prisma.newsPost.findFirst({
      where: { id: postId, status: 'approved' },
      include: newsPostInclude,
    });

    if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });

    // Increment view count (fire and forget)
    prisma.newsPost.update({
      where: { id: post.id },
      data: { views: { increment: 1 } },
    }).catch(() => {});

    const payload = {
      success: true,
      post: sanitizeStoryTextFields(serializeNewsPost(post)),
      cached: false,
    };
    await feedResponseCache.setCachedPost(postId, payload);

    const postWithSeen = {
      ...payload.post,
      seen: req.user && req.user.id ? true : false,
    };

    feedResponseCache.applyEdgeCacheHeaders(res, req, feedResponseCache.postTtlMs());
    res.json({ ...payload, post: postWithSeen });
  } catch (error) {
    sendPostRouteError(res, error);
  }
};

// POST /api/news/:id/like
const toggleLike = async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Login required to like posts.' });
    }
    const postId = String(req.params.id || '').trim();
    if (!isValidUuid(postId)) {
      return respondInvalidPostId(res);
    }
    const post = await prisma.newsPost.findUnique({ where: { id: postId }, select: { id: true } });
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
    const postId = String(req.params.id || '').trim();
    if (!isValidUuid(postId)) {
      return respondInvalidPostId(res);
    }
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
    const postId = String(req.params.id || '').trim();
    if (!isValidUuid(postId)) {
      return respondInvalidPostId(res);
    }
    const comments = await prisma.comment.findMany({
      where: { postId, isDeleted: false },
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
    const postId = String(req.params.id || '').trim();
    if (!isValidUuid(postId)) {
      return respondInvalidPostId(res);
    }
    const { text } = req.body;
    if (!text) return res.status(400).json({ success: false, message: 'Comment text required.' });
    const commentText = String(text).trim();
    if (!commentText) {
      return res.status(400).json({ success: false, message: 'Comment text required.' });
    }
    if (commentText.length > MAX_COMMENT_LENGTH) {
      return res.status(400).json({
        success: false,
        message: `Comment too long (max ${MAX_COMMENT_LENGTH} characters).`,
      });
    }

    const comment = await prisma.comment.create({
      data: {
        postId,
        userId: req.user._id,
        text: commentText,
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
    if (input.length > MAX_TRANSLATE_TEXT_LENGTH) {
      return res.status(400).json({
        success: false,
        message: `text too long (max ${MAX_TRANSLATE_TEXT_LENGTH} characters).`,
      });
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

  let referer = getPublisherReferer(parsed.hostname) || `${parsed.protocol}//${parsed.host}/`;
  if (refererOpt && typeof refererOpt === 'string') {
    try {
      const r = new URL(refererOpt);
      if (['http:', 'https:'].includes(r.protocol)) {
        referer = getPublisherReferer(r.href) || r.href;
      }
    } catch { /* keep CDN host default */ }
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

const getReverseGeocode = async (req, res) => {
  try {
    const { lat, lon } = req.query;
    if (!lat || !lon) {
      return res.status(400).json({ success: false, message: 'Latitude and longitude are required' });
    }
    const result = await reverseGeocode(lat, lon);
    return res.json({ success: true, location: result });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

const getLocalNews = async (req, res) => {
  try {
    const {
      latitude,
      lat,
      longitude,
      lng,
      radius = 50,
      city,
      constituency,
      state,
      language,
      page = 1,
      limit = 20,
    } = req.query;

    const p = Math.max(1, parseInt(page, 10) || 1);
    const lim = Math.max(1, Math.min(50, parseInt(limit, 10) || 20));
    const skip = (p - 1) * lim;

    const queryLat = parseFloat(latitude || lat);
    const queryLng = parseFloat(longitude || lng);
    const queryRadius = parseFloat(radius);
    const lang = language && language !== 'all' ? String(language).toLowerCase() : null;

    let posts = [];
    let total = 0;

    if (!isNaN(queryLat) && !isNaN(queryLng)) {
      // Fetch IDs within the radius limit using Haversine formula with LEAST/GREATEST clamp to avoid acos precision domain errors
      const rows = await prisma.$queryRaw`
        SELECT id::text FROM news_posts
        WHERE status = 'approved'
          AND location_latitude IS NOT NULL
          AND location_longitude IS NOT NULL
          AND (6371 * acos(LEAST(GREATEST(
            cos(radians(${queryLat})) * cos(radians(location_latitude)) *
            cos(radians(location_longitude) - radians(${queryLng})) +
            sin(radians(${queryLat})) * sin(radians(location_latitude))
          , -1.0), 1.0))) <= ${queryRadius}
        ORDER BY (6371 * acos(LEAST(GREATEST(
          cos(radians(${queryLat})) * cos(radians(location_latitude)) *
          cos(radians(location_longitude) - radians(${queryLng})) +
          sin(radians(${queryLat})) * sin(radians(location_latitude))
        , -1.0), 1.0))) ASC
        LIMIT ${lim} OFFSET ${skip}
      `;

      const totalRows = await prisma.$queryRaw`
        SELECT COUNT(*)::int as count FROM news_posts
        WHERE status = 'approved'
          AND location_latitude IS NOT NULL
          AND location_longitude IS NOT NULL
          AND (6371 * acos(LEAST(GREATEST(
            cos(radians(${queryLat})) * cos(radians(location_latitude)) *
            cos(radians(location_longitude) - radians(${queryLng})) +
            sin(radians(${queryLat})) * sin(radians(location_latitude))
          , -1.0), 1.0))) <= ${queryRadius}
      `;
      total = Number(totalRows[0]?.count || 0);

      const ids = rows.map(r => r.id);

      if (ids.length > 0) {
        let whereClause = { id: { in: ids } };
        if (lang) {
          whereClause.language = lang;
        }
        const fetched = await prisma.newsPost.findMany({
          where: whereClause,
          include: newsPostInclude,
        });

        // Retain the sorted order by distance
        posts = ids
          .map(id => fetched.find(post => post.id === id))
          .filter(Boolean);
      }
    } else {
      const andFilters = [{ status: 'approved' }];
      if (lang) {
        andFilters.push({ language: lang });
      }

      const orFilters = [];
      if (city && String(city).trim()) {
        orFilters.push({ locationCity: { equals: String(city).trim(), mode: 'insensitive' } });
      }
      if (constituency && String(constituency).trim() && String(constituency).toLowerCase() !== 'all') {
        orFilters.push({ constituency: { equals: String(constituency).trim(), mode: 'insensitive' } });
      }
      if (state && String(state).trim()) {
        orFilters.push({ locationState: { equals: String(state).trim(), mode: 'insensitive' } });
      }

      if (orFilters.length > 0) {
        andFilters.push({ OR: orFilters });
      } else {
        const localCat = await prisma.category.findFirst({
          where: { slug: 'local', isActive: true },
          select: { id: true }
        });
        if (localCat) {
          andFilters.push({ categoryId: localCat.id });
        }
      }

      const whereClause = { AND: andFilters };
      
      const [fetched, count] = await Promise.all([
        prisma.newsPost.findMany({
          where: whereClause,
          include: newsPostInclude,
          orderBy: [{ sourcePublishedAt: 'desc' }, { createdAt: 'desc' }],
          skip,
          take: lim,
        }),
        prisma.newsPost.count({ where: whereClause })
      ]);

      posts = fetched;
      total = count;
    }

    const serialized = posts.map(serializeNewsPost);
    const pages = Math.ceil(total / lim) || 1;

    return res.json({
      success: true,
      posts: serialized,
      page: p,
      pages,
      total,
    });
  } catch (e) {
    console.error('[news] local news failed:', e.message);
    return res.status(500).json({ success: false, message: 'Could not load local news.' });
  }
};

const markPostSeen = async (req, res) => {
  try {
    const postId = String(req.params.id || '').trim();
    if (!isValidUuid(postId)) {
      return respondInvalidPostId(res);
    }
    if (!req.user || !req.user.id) {
      return res.status(401).json({ success: false, message: 'Authorization required.' });
    }

    const postExists = await prisma.newsPost.findUnique({ where: { id: postId } });
    if (!postExists) {
      return res.status(404).json({ success: false, message: 'Post not found.' });
    }

    await prisma.postSeen.upsert({
      where: {
        userId_postId: {
          userId: req.user.id,
          postId: postId,
        },
      },
      update: {},
      create: {
        userId: req.user.id,
        postId: postId,
      },
    });

    res.json({ success: true, message: 'Post marked as seen.' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

async function chatWithNews(req, res) {
  try {
    const {
      message,
      language,
      latitude,
      longitude,
      lat,
      lng,
      city,
      state,
      country,
      articleId,
      category,
      history,
    } = req.body;

    if (!message || typeof message !== 'string' || !message.trim()) {
      return res.status(400).json({ success: false, message: 'Message is required.' });
    }
    const trimmedMessage = message.trim();
    if (trimmedMessage.length > MAX_CHAT_MESSAGE_LENGTH) {
      return res.status(400).json({
        success: false,
        message: `Message too long (max ${MAX_CHAT_MESSAGE_LENGTH} characters).`,
      });
    }
    if (articleId && !isValidUuid(String(articleId))) {
      return res.status(400).json({ success: false, message: 'Invalid articleId.' });
    }

    const aiProvider = require('../services/aiProvider');
    if (!aiProvider.isOllamaProvider()) {
      return res.status(503).json({
        success: false,
        message: 'AI chat requires Ollama. Set AI_PROVIDER=ollama on the server.',
      });
    }
    const ollamaStatus = await aiProvider.pingOllama();
    if (!ollamaStatus.ok) {
      return res.status(503).json({
        success: false,
        message: 'Ollama is not ready. Pull the configured models and try again.',
        ai: ollamaStatus,
      });
    }

    const { runNewsChat } = require('../services/newsChatService');
    const result = await runNewsChat({
      message: trimmedMessage,
      language,
      latitude,
      longitude,
      lat,
      lng,
      city,
      state,
      country,
      articleId,
      category,
      history,
    });

    return res.json({
      success: true,
      answer: result.answer,
      relatedArticles: result.relatedArticles,
      weather: result.weather,
      sourcesUsed: result.sourcesUsed,
    });
  } catch (error) {
    console.error('[ai-chat] Error in chatWithNews:', error.message);
    return res.status(500).json({
      success: false,
      message: 'Failed to generate response. Please try again later.',
    });
  }
}

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
  getReverseGeocode,
  getLocalNews,
  markPostSeen,
  chatWithNews,
  isValidUuid,
  resolveCategoryFilter,
  VALID_FEED_LANGUAGES,
  politicsScopeAllowedForLanguage,
  buildFeedPostProcessor,
};