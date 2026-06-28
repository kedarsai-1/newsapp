const { createHash } = require('crypto');
const { Prisma, prisma } = require('../config/prisma');
const { reverseGeocode, forwardGeocode } = require('../utils/geocode');
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
const cacheService = require('../utils/cacheService');
const { getPublisherReferer } = require('../utils/publisherReferer');
const { fetchBestImageFallback } = require('../services/newsApiService');
const {
  ensureShareCodeForPost,
  buildSharePayload,
  resolvePostByShareCode,
  buildArticleUrl,
} = require('../utils/shareLinkService');
const { publisherKeyFromName } = require('../utils/publisherKey');
const { publisherMatchClause, buildPublishersOrFilter } = require('../utils/publisherFeedFilter');

/** Upstream image missing — return 404 so Flutter errorWidget / fallback runs. */
function sendImageFailure(res, status = 404) {
  res.setHeader('Cache-Control', 'public, max-age=60');
  res.setHeader('X-Image-Cache', 'MISS');
  return res.status(status).type('text/plain').send('Image unavailable');
}

async function fetchImageBuffer(url, headers, signal) {
  const upstream = await fetch(url, { redirect: 'follow', signal, headers });
  if (!upstream.ok) return { ok: false, status: upstream.status };
  const ct = (upstream.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
  const buf = Buffer.from(await upstream.arrayBuffer());
  if (buf.length > 5 * 1024 * 1024) return { ok: false, status: 413 };
  const outType = ct && ct.startsWith('image/') ? ct : 'image/jpeg';
  return { ok: true, buf, contentType: outType };
}
const {
  getShortsExcludeCategoryIds,
  prismaShortsExcludePoliticsClause,
  filterPostsForShortsFeed,
} = require('../utils/shortsFeedFilter');
const { prismaExcludeNonGeoFeedSourcesClause } = require('../utils/feedSourceLocation');
const { capYoutubeInMixedFeed } = require('../utils/youtubeCap');
const {
  parseFeedPagination,
  buildFeedPaginationResponse,
  needsPostFetchLoop,
  fetchFeedPagePosts,
} = require('../utils/feedPagination');
const {
  HINDI_SCOPE_KEYS,
  HINDI_POLITICS_SCOPE_VALUES,
  hindiScopeTitleOrClause,
} = require('../config/hindiRegionalScopes');

const VALID_FEED_LANGUAGES = new Set(['en', 'hi', 'te']);
const VALID_POLITICS_SCOPES = new Set([
  'andhra', 'telangana', 'india', 'international', 'north', 'states', 'delhi', 'all',
  ...HINDI_SCOPE_KEYS,
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
  /** SQL NOT IN excludes NULL — keep untagged ingest rows (YouTube, legacy RSS). */
  const allowOriginalLanguages = (codes) => ({
    OR: [
      { originalLanguage: null },
      { NOT: { originalLanguage: { in: codes } } },
    ],
  });
  if (lang === 'en') {
    return {
      language: 'en',
      AND: [
        { NOT: { language: { in: ['hi', 'te'] } } },
        allowOriginalLanguages(['hin', 'tel', 'hi', 'te']),
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

/** Prisma rejects null inside `{ in: [...] }` on String? fields — use explicit OR branches. */
function politicsScopeIndiaOrUnset() {
  return {
    OR: [
      { politicsScope: 'india' },
      { politicsScope: null },
    ],
  };
}

function politicsScopeAllowedForLanguage(scope, langParam) {
  const ps = String(scope || '').toLowerCase().trim();
  if (!ps || ps === 'all') return true;
  if (!langParam) return true;
  const teScopes = new Set(['andhra', 'telangana', 'india', 'international']);
  const hiScopes = new Set(['india', 'international', ...HINDI_POLITICS_SCOPE_VALUES]);
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
              in: [
                'andhra', 'telangana', 'international',
                ...HINDI_POLITICS_SCOPE_VALUES,
              ],
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
    const northScopes = ['north', 'states', ...HINDI_SCOPE_KEYS];
    const titleClauses = HINDI_SCOPE_KEYS.flatMap((scope) => hindiScopeTitleOrClause(scope));
    return {
      OR: [
        { politicsScope: { in: northScopes } },
        {
          AND: [
            politicsScopeIndiaOrUnset(),
            { OR: titleClauses },
          ],
        },
      ],
    };
  }
  if (ps === 'states') {
    return { politicsScope: { in: ['states', 'north', ...HINDI_SCOPE_KEYS] } };
  }
  if (HINDI_SCOPE_KEYS.includes(ps)) {
    return {
      OR: [
        { politicsScope: ps },
        {
          AND: [
            politicsScopeIndiaOrUnset(),
            { OR: hindiScopeTitleOrClause(ps) },
          ],
        },
      ],
    };
  }
  if (ps === 'andhra') {
    return {
      OR: [
        { politicsScope: 'andhra' },
        {
          AND: [
            politicsScopeIndiaOrUnset(),
            {
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
        },
      ],
    };
  }
  if (ps === 'telangana') {
    return {
      OR: [
        { politicsScope: 'telangana' },
        {
          AND: [
            politicsScopeIndiaOrUnset(),
            {
              OR: [
                { title: containsInsensitive('telangana') },
                { title: containsInsensitive('తెలంగాణ') },
                { title: containsInsensitive('hyderabad') },
                { title: containsInsensitive('హైదరాబాద్') },
                { title: containsInsensitive('secunderabad') },
              ],
            },
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
      sort,
      following,
      publisher,
      publishers,
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
    if (req.query.district && String(req.query.district).trim().toLowerCase() !== 'all') {
      where.locationDistrict = containsInsensitive(String(req.query.district).trim());
    }
    if (req.query.mandal && String(req.query.mandal).trim().toLowerCase() !== 'all') {
      where.locationMandal = containsInsensitive(String(req.query.mandal).trim());
    }
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

    const sortParam = String(sort || '').toLowerCase().trim();
    const followingOnly = String(following || '').toLowerCase() === 'true';
    const publisherFilter = String(publisher || '').trim();

    if (publisherFilter) {
      const clause = publisherMatchClause(publisherFilter);
      if (clause) andFilters.push(clause);
    }

    const publishersFilter = buildPublishersOrFilter(publishers);
    if (publishersFilter) {
      andFilters.push(publishersFilter);
    }

    if (followingOnly) {
      if (!req.user?.id) {
        return res.status(401).json({ success: false, message: 'Login required for following feed.' });
      }
      const follows = await prisma.userPublisherFollow.findMany({
        where: { userId: req.user._id || req.user.id },
        select: { publisherKey: true, publisherName: true },
      });
      if (!follows.length) {
        return res.json({
          success: true,
          total: 0,
          page: pageNum,
          pages: 0,
          hasMore: false,
          posts: [],
          cached: false,
        });
      }
      andFilters.push({
        OR: follows.map((f) => publisherMatchClause(f.publisherName)).filter(Boolean),
      });
    }

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
    const regionalPolitics = ps === 'andhra' || ps === 'telangana' || ps === 'north'
      || HINDI_SCOPE_KEYS.includes(ps);
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
              ? { categoryId: localCategoryId, politicsScope: { in: ['north', 'states', 'delhi', ...HINDI_SCOPE_KEYS] } }
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

    const orderBy = sortParam === 'trending'
      ? [
          { views: 'desc' },
          { sourcePublishedAt: 'desc' },
          { createdAt: 'desc' },
        ]
      : [
          { isBreaking: 'desc' },
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

// GET /api/news/:id/share — Dailyhunt-style short link + formatted share text
const getPostShare = async (req, res) => {
  try {
    const postId = String(req.params.id || '').trim();
    if (!isValidUuid(postId)) {
      return respondInvalidPostId(res);
    }

    const post = await prisma.newsPost.findUnique({
      where: { id: postId },
      select: {
        id: true,
        title: true,
        status: true,
        sourceName: true,
        sourceType: true,
        youtubeChannelTitle: true,
        shareCode: true,
        reporter: { select: { name: true } },
        category: { select: { name: true } },
      },
    });

    if (!post || post.status !== 'approved') {
      return res.status(404).json({ success: false, message: 'Post not found' });
    }

    const shareCode = await ensureShareCodeForPost(post.id, post.shareCode);
    const payload = buildSharePayload(post, shareCode, req);

    return res.json({ success: true, ...payload });
  } catch (error) {
    console.error('[news] getPostShare error:', error.message);
    return res.status(500).json({ success: false, message: 'Failed to build share link' });
  }
};

// GET /n/:code — redirect short link to in-app article (nginx proxies here)
const redirectShareLink = async (req, res) => {
  try {
    const post = await resolvePostByShareCode(req.params.code);
    if (!post) {
      return res.status(404).type('text/plain').send('Link not found');
    }
    return res.redirect(302, buildArticleUrl(post.id, req));
  } catch (error) {
    console.error('[share] redirect error:', error.message);
    return res.status(500).type('text/plain').send('Share link unavailable');
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
      let viewCount = Number(cached.body.post?.views || 0);
      try {
        const updated = await prisma.newsPost.update({
          where: { id: postId },
          data: { views: { increment: 1 } },
          select: { views: true },
        });
        viewCount = updated.views;
      } catch (_) {
        viewCount += 1;
      }

      const postWithSeen = {
        ...cached.body.post,
        views: viewCount,
        seen: req.user && req.user.id ? true : false,
      };
      return res.json({ ...cached.body, post: postWithSeen, cached: true });
    }

    const post = await prisma.newsPost.findFirst({
      where: { id: postId, status: 'approved' },
      include: newsPostInclude,
    });

    if (!post) return res.status(404).json({ success: false, message: 'Post not found.' });

    let viewCount = Number(post.views || 0);
    try {
      const updated = await prisma.newsPost.update({
        where: { id: post.id },
        data: { views: { increment: 1 } },
        select: { views: true },
      });
      viewCount = updated.views;
    } catch (_) {
      viewCount += 1;
    }

    const payload = {
      success: true,
      post: sanitizeStoryTextFields(serializeNewsPost({ ...post, views: viewCount })),
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

// GET /api/news/publishers/following
const getFollowingPublishers = async (req, res) => {
  try {
    if (!req.user) {
      return res.json({ success: true, following: [] });
    }
    const userId = req.user._id || req.user.id;
    const rows = await prisma.userPublisherFollow.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      select: { publisherKey: true, publisherName: true, createdAt: true },
    });
    return res.json({ success: true, following: rows });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/news/publishers/follow
const togglePublisherFollow = async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Login required to follow publishers.' });
    }
    const userId = req.user._id || req.user.id;
    const publisherName = String(req.body?.publisherName || '').trim().slice(0, 200);
    const publisherKey = publisherKeyFromName(publisherName);
    if (!publisherKey || !publisherName) {
      return res.status(400).json({ success: false, message: 'publisherName is required.' });
    }
    const key = { userId_publisherKey: { userId, publisherKey } };
    const existing = await prisma.userPublisherFollow.findUnique({ where: key });
    if (existing) {
      await prisma.userPublisherFollow.delete({ where: key });
      return res.json({ success: true, following: false });
    }
    await prisma.userPublisherFollow.create({
      data: { userId, publisherKey, publisherName },
    });
    return res.json({ success: true, following: true });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
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

  const cacheKey = `imgproxy:${createHash('sha256').update(parsed.href).digest('hex')}`;
  const cacheTtlMs = Math.max(
    60_000,
    Number(process.env.PROXY_IMAGE_CACHE_TTL_MS || 24 * 60 * 60 * 1000),
  );
  if (process.env.PROXY_IMAGE_CACHE_ENABLED !== 'false') {
    try {
      const hit = await cacheService.get(cacheKey);
      if (hit?._binary && hit.data) {
        const buf = Buffer.from(hit.data, 'base64');
        res.setHeader('Content-Type', hit.contentType || 'image/jpeg');
        res.setHeader('Cache-Control', 'public, max-age=86400, stale-while-revalidate=3600');
        res.setHeader('X-Image-Cache', 'HIT');
        return res.send(buf);
      }
    } catch {
      /* fetch upstream */
    }
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
      clearTimeout(to);
      let articleUrl = null;
      if (refererOpt && typeof refererOpt === 'string') {
        try {
          const r = new URL(refererOpt);
          if (['http:', 'https:'].includes(r.protocol)) articleUrl = r.href;
        } catch { /* ignore */ }
      }
      if (
        articleUrl
        && (upstream.status === 404 || upstream.status === 403 || upstream.status === 410)
      ) {
        try {
          const fallbackUrl = await fetchBestImageFallback(articleUrl);
          if (fallbackUrl && fallbackUrl !== parsed.href) {
            const fb = await fetchImageBuffer(fallbackUrl, {
              ...baseHeaders,
              Referer: referer,
              Origin: referer,
            }, ac.signal);
            if (fb.ok) {
              if (process.env.PROXY_IMAGE_CACHE_ENABLED !== 'false') {
                cacheService.set(cacheKey, {
                  _binary: true,
                  contentType: fb.contentType,
                  data: fb.buf.toString('base64'),
                }, cacheTtlMs).catch(() => {});
              }
              res.setHeader('Content-Type', fb.contentType);
              res.setHeader('Cache-Control', 'public, max-age=86400, stale-while-revalidate=3600');
              res.setHeader('X-Image-Cache', 'FALLBACK');
              return res.send(fb.buf);
            }
          }
        } catch { /* placeholder below */ }
      }
      return sendImageFailure(res, upstream.status === 410 ? 410 : 404);
    }

    const ct = (upstream.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
    const looksImage = /\.(jpg|jpeg|png|gif|webp|avif|bmp)(\?|#|$)/i.test(parsed.pathname + parsed.search);
    const okCt =
      !ct
      || ct.startsWith('image/')
      || (looksImage && (ct === 'application/octet-stream' || ct === 'binary/octet-stream'));

    if (!okCt) {
      return sendImageFailure(res, 502);
    }

    const buf = Buffer.from(await upstream.arrayBuffer());
    if (buf.length > 5 * 1024 * 1024) {
      return sendImageFailure(res, 413);
    }

    const outType = ct && ct.startsWith('image/') ? ct : 'image/jpeg';
    if (process.env.PROXY_IMAGE_CACHE_ENABLED !== 'false') {
      cacheService.set(cacheKey, {
        _binary: true,
        contentType: outType,
        data: buf.toString('base64'),
      }, cacheTtlMs).catch(() => {});
    }
    res.setHeader('Content-Type', outType);
    res.setHeader('Cache-Control', 'public, max-age=86400, stale-while-revalidate=3600');
    res.setHeader('X-Image-Cache', 'MISS');
    res.send(buf);
  } catch (e) {
    clearTimeout(to);
    console.warn('[proxy-image] fetch failed:', e.message);
    return sendImageFailure(res, 502);
  }
};

const getReverseGeocode = async (req, res) => {
  try {
    const { lat } = req.query;
    const lon = req.query.lon ?? req.query.lng;
    if (!lat || !lon) {
      return res.status(400).json({ success: false, message: 'Latitude and longitude are required' });
    }
    const result = await reverseGeocode(lat, lon);
    return res.json({ success: true, location: result });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

const getForwardGeocode = async (req, res) => {
  try {
    const city = String(req.query.city || '').trim();
    if (!city) {
      return res.status(400).json({ success: false, message: 'City name is required' });
    }
    const state = String(req.query.state || '').trim() || undefined;
    const result = await forwardGeocode(city, { state });
    return res.json({ success: true, location: result });
  } catch (error) {
    return res.status(400).json({ success: false, message: error.message });
  }
};

function sanitizeLocalParam(value) {
  const s = String(value || '').trim();
  if (!s || s.toLowerCase() === 'all') return null;
  return s;
}

function buildLocalLocationTiers({
  city, district, mandal, constituency, state, politicsScope, lang,
}) {
  const c = sanitizeLocalParam(city);
  const d = sanitizeLocalParam(district);
  const m = sanitizeLocalParam(mandal);
  const constit = sanitizeLocalParam(constituency);
  const st = sanitizeLocalParam(state);
  const ps = String(politicsScope || '').trim().toLowerCase();
  const scopeWhere = (ps && ps !== 'all' && VALID_POLITICS_SCOPES.has(ps))
    ? politicsScopeWhere(ps, lang)
    : null;

  const tiers = [];
  const hasHyperlocal = !!(c || d || m || constit || st);

  if (m && d) {
    tiers.push({
      AND: [
        { locationMandal: { equals: m, mode: 'insensitive' } },
        { locationDistrict: { equals: d, mode: 'insensitive' } },
      ],
    });
  }
  if (m) {
    tiers.push({ locationMandal: { equals: m, mode: 'insensitive' } });
  }
  if (d && c) {
    tiers.push({
      AND: [
        { locationDistrict: { equals: d, mode: 'insensitive' } },
        { locationCity: { equals: c, mode: 'insensitive' } },
      ],
    });
  }
  if (d) {
    tiers.push({ locationDistrict: { equals: d, mode: 'insensitive' } });
  }
  if (c) {
    tiers.push({ locationCity: { equals: c, mode: 'insensitive' } });
  }
  if (constit) {
    tiers.push({ constituency: { equals: constit, mode: 'insensitive' } });
  }
  if (st) {
    tiers.push({ locationState: { equals: st, mode: 'insensitive' } });
  }
  if (hasHyperlocal && scopeWhere) {
    tiers.push(scopeWhere);
  }

  return { tiers, hasHyperlocal, scopeWhere };
}

/** @deprecated kept for tests — prefer buildLocalLocationTiers */
function buildLocalMetadataOrFilters(params) {
  const { tiers } = buildLocalLocationTiers(params);
  const orFilters = [];
  for (const tier of tiers) {
    if (tier.AND) orFilters.push(...tier.AND);
    else orFilters.push(tier);
  }
  const ps = String(params.politicsScope || '').trim().toLowerCase();
  const scopeWhere = (ps && ps !== 'all' && VALID_POLITICS_SCOPES.has(ps))
    ? politicsScopeWhere(ps, params.lang)
    : null;
  return { orFilters, scopeWhere };
}

async function fetchLocalPostsForTier({
  lang,
  tierWhere,
  skip,
  lim,
  hyperlocal = false,
  strictSource = true,
  city = null,
  district = null,
  mandal = null,
}) {
  const andFilters = [{ status: 'approved' }];
  if (lang) andFilters.push({ language: lang });
  andFilters.push(tierWhere);

  if (hyperlocal) {
    andFilters.push({
      NOT: {
        OR: [
          { sourceName: { contains: ' - Andhra Pradesh', mode: 'insensitive' } },
          { sourceName: { contains: ' - Telangana', mode: 'insensitive' } },
          { sourceName: { contains: ' - Uttar Pradesh', mode: 'insensitive' } },
          { sourceName: { contains: ' - Bihar', mode: 'insensitive' } },
          { sourceName: { contains: ' - Rajasthan', mode: 'insensitive' } },
          { sourceName: { contains: ' - Punjab', mode: 'insensitive' } },
          { sourceName: { contains: ' - Haryana', mode: 'insensitive' } },
          { sourceName: { contains: ' - States', mode: 'insensitive' } },
          { sourceName: { contains: ' - North', mode: 'insensitive' } },
        ],
      },
    });
    andFilters.push({
      NOT: { category: { slug: { in: ['entertainment', 'sports', 'technology', 'business'] } } },
    });
    andFilters.push(prismaExcludeNonGeoFeedSourcesClause());
    if (strictSource) {
      const placeTerms = [mandal, district, city]
        .map((v) => sanitizeLocalParam(v))
        .filter(Boolean);
      if (placeTerms.length) {
        andFilters.push({
          OR: placeTerms.map((term) => ({
            sourceName: { contains: term, mode: 'insensitive' },
          })),
        });
      }
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
    prisma.newsPost.count({ where: whereClause }),
  ]);
  return { posts: fetched, total: count };
}

async function fetchLocalPostsByMetadata({
  lang,
  tiers,
  hasHyperlocal,
  scopeWhere,
  skip,
  lim,
  city = null,
  district = null,
  mandal = null,
}) {
  if (tiers?.length) {
    for (const tierWhere of tiers) {
      let result = await fetchLocalPostsForTier({
        lang,
        tierWhere,
        skip,
        lim,
        hyperlocal: hasHyperlocal,
        strictSource: true,
        city,
        district,
        mandal,
      });
      if (result.total === 0 && hasHyperlocal) {
        result = await fetchLocalPostsForTier({
          lang,
          tierWhere,
          skip,
          lim,
          hyperlocal: hasHyperlocal,
          strictSource: false,
          city,
          district,
          mandal,
        });
      }
      if (result.total > 0) return result;
    }
    return { posts: [], total: 0 };
  }

  const andFilters = [{ status: 'approved' }];
  if (lang) andFilters.push({ language: lang });
  if (scopeWhere) andFilters.push(scopeWhere);

  if (!scopeWhere) {
    const localCat = await prisma.category.findFirst({
      where: { slug: 'local', isActive: true },
      select: { id: true },
    });
    if (localCat?.id) {
      andFilters.push({
        AND: [
          { categoryId: localCat.id },
          {
            OR: [
              { locationDistrict: { not: null } },
              { locationMandal: { not: null } },
            ],
            NOT: {
              OR: [
                { locationDistrict: { in: ['Andhra Pradesh', 'Telangana', 'Uttar Pradesh', 'Bihar', 'Rajasthan', 'Punjab', 'Haryana', 'Delhi'] } },
                { locationCity: { in: ['Andhra Pradesh', 'Telangana'] } },
              ],
            },
          },
        ],
      });
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
    prisma.newsPost.count({ where: whereClause }),
  ]);
  return { posts: fetched, total: count };
}

const getLocalNews = async (req, res) => {
  try {
    const {
      latitude,
      lat,
      longitude,
      lng,
      radius = 75,
      city,
      district,
      mandal,
      constituency,
      state,
      language,
      politicsScope,
      page = 1,
      limit = 20,
    } = req.query;

    const p = Math.max(1, parseInt(page, 10) || 1);
    const lim = Math.max(1, Math.min(50, parseInt(limit, 10) || 20));
    const skip = (p - 1) * lim;

    const queryLat = parseFloat(latitude || lat);
    const queryLng = parseFloat(longitude || lng);
    const queryRadius = Math.min(200, Math.max(5, parseFloat(radius) || 75));
    const lang = language && language !== 'all' ? String(language).toLowerCase() : null;

    const { tiers, hasHyperlocal, scopeWhere } = buildLocalLocationTiers({
      city,
      district,
      mandal,
      constituency,
      state,
      politicsScope,
      lang,
    });

    let posts = [];
    let total = 0;
    const hasGps = !isNaN(queryLat) && !isNaN(queryLng);

    const metaResult = await fetchLocalPostsByMetadata({
      lang,
      tiers,
      hasHyperlocal,
      scopeWhere,
      skip: hasGps ? 0 : skip,
      lim: hasGps ? lim * 2 : lim,
      city,
      district,
      mandal,
    });

    if (hasGps) {
      const langFilter = lang
        ? Prisma.sql`AND language = ${lang}`
        : Prisma.empty;
      const rows = await prisma.$queryRaw`
        SELECT id::text FROM news_posts
        WHERE status = 'approved'
          AND location_latitude IS NOT NULL
          AND location_longitude IS NOT NULL
          ${langFilter}
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
        LIMIT ${Math.min(200, lim * 3)}
      `;

      const radiusIds = rows.map((r) => r.id);
      const mergedIds = [...new Set([...metaResult.posts.map((x) => x.id), ...radiusIds])];
      total = mergedIds.length;

      if (mergedIds.length > 0) {
        const pageIds = mergedIds.slice(skip, skip + lim);
        const fetched = await prisma.newsPost.findMany({
          where: { id: { in: pageIds } },
          include: newsPostInclude,
        });
        posts = pageIds
          .map((id) => fetched.find((post) => post.id === id))
          .filter(Boolean);
      }
    } else {
      posts = metaResult.posts;
      total = metaResult.total;
    }

    const deduped = dedupeFeedPosts(posts.map(serializeNewsPost));
    const serialized = deduped.map(sanitizeStoryTextFields);
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

const REPORT_REASONS = new Set([
  'Misinformation',
  'Offensive content',
  'Spam or clickbait',
  'Copyright issue',
  'Other',
]);

const reportPost = async (req, res) => {
  try {
    const postId = String(req.params.id || '').trim();
    if (!isValidUuid(postId)) {
      return respondInvalidPostId(res);
    }

    const reason = String(req.body?.reason || '').trim();
    if (!reason || !REPORT_REASONS.has(reason)) {
      return res.status(400).json({
        success: false,
        message: 'A valid report reason is required.',
      });
    }

    const details = String(req.body?.details || '').trim().slice(0, 1000) || null;

    const postExists = await prisma.newsPost.findUnique({
      where: { id: postId },
      select: { id: true },
    });
    if (!postExists) {
      return res.status(404).json({ success: false, message: 'Post not found.' });
    }

    const userId = req.user?.id || req.user?._id || null;

    if (userId) {
      const existing = await prisma.postReport.findFirst({
        where: { postId, userId },
        select: { id: true },
      });
      if (existing) {
        return res.json({
          success: true,
          message: 'You already reported this story.',
        });
      }
    }

    await prisma.postReport.create({
      data: {
        postId,
        userId,
        reason,
        details,
      },
    });

    res.json({
      success: true,
      message: 'Report submitted. Our editors will review this story.',
    });
  } catch (error) {
    console.error('[news] reportPost error:', error.message);
    res.status(500).json({ success: false, message: 'Could not submit report.' });
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

    const queueSlot = aiProvider.acquireChatQueueSlot();
    const handlerTimeoutMs = aiProvider.chatHandlerTimeoutMs(queueSlot.queueIndex);
    const handlerTimer = setTimeout(() => {
      if (!res.headersSent) {
        res.status(504).json({
          success: false,
          message: 'AI chat timed out. Please try again.',
        });
      }
    }, handlerTimeoutMs);
    handlerTimer.unref?.();

    const clearHandlerTimer = () => clearTimeout(handlerTimer);
    res.on('finish', clearHandlerTimer);
    res.on('close', clearHandlerTimer);

    try {
      const ollamaStatus = await aiProvider.getOllamaChatStatus();
      if (res.headersSent) return;
      if (aiProvider.ollamaChatModelsConfirmedMissing(ollamaStatus)) {
        return res.status(503).json({
          success: false,
          message: 'Ollama chat is not ready. Pull the configured chat models and try again.',
          ai: ollamaStatus,
        });
      }
      if (!ollamaStatus.ok && ollamaStatus.transient) {
        console.warn(
          `[ai-chat] Ollama tags check transient (${ollamaStatus.error}); proceeding with chat`,
        );
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

      if (res.headersSent) return;

      try {
        return res.json({
          success: true,
          answer: result.answer,
          aiGenerated: result.aiGenerated,
          relatedArticles: result.relatedArticles,
          weather: result.weather,
          sourcesUsed: result.sourcesUsed,
        });
      } catch (sendErr) {
        if (sendErr?.code === 'ERR_HTTP_HEADERS_SENT') return;
        throw sendErr;
      }
    } finally {
      queueSlot.release();
    }
  } catch (error) {
    if (error?.code === 'ERR_HTTP_HEADERS_SENT') return;
    console.error('[ai-chat] Error in chatWithNews:', error.message);
    if (res.headersSent) return;
    if (error.message?.includes('_timeout')) {
      return res.status(504).json({
        success: false,
        message: 'AI chat timed out. Please try a shorter question.',
      });
    }
    return res.status(500).json({
      success: false,
      message: 'Failed to generate response. Please try again later.',
    });
  }
}

module.exports = {
  getFeed,
  getPost,
  getPostShare,
  redirectShareLink,
  getProxyImage,
  extractArticle,
  toggleLike,
  toggleBookmark,
  getBookmarks,
  getFollowingPublishers,
  togglePublisherFollow,
  getComments,
  addComment,
  translateText,
  getReverseGeocode,
  getForwardGeocode,
  getLocalNews,
  markPostSeen,
  reportPost,
  chatWithNews,
  isValidUuid,
  resolveCategoryFilter,
  VALID_FEED_LANGUAGES,
  politicsScopeAllowedForLanguage,
  politicsScopeWhere,
  buildFeedPostProcessor,
};