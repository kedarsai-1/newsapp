const bcrypt = require('bcryptjs');
const { Prisma, prisma } = require('../config/prisma');
const {
  canonicalizeUrl,
  hashUrl,
  normalizeTitle,
  titleFingerprint,
  summaryFingerprint,
  summariesAreNearDuplicates,
} = require('../utils/storyDedupe');
const { decodeHtmlEntities } = require('../utils/decodeHtmlEntities');
const { clipSummaryForStorage, cleanArticlePlainText } = require('../utils/summaryText');
const { acceptPoliticsRssItem } = require('../utils/politicalStoryFilter');
const { passesIngestCategoryGate } = require('../utils/categoryRelevance');
const { isHyperlocalFeedSource, isNonGeoFeedSource } = require('../utils/feedSourceLocation');
const { inferPoliticsScope } = require('./politicalVideoIngestionService');
const { createNewsPost } = require('../utils/prismaNewsPost');
const {
  fetchNewsApiItems,
  fetchGNewsItems,
  fetchBestImageFallback,
  isUnusableFeedImageUrl,
} = require('./newsApiService');
const { newsApiIngestPlan } = require('../config/newsApiIngestPlan');
const { rehostExternalImageForIngest } = require('../utils/rehostExternalImage');
const { getRssFeeds } = require('../config/rssFeeds');
const {
  resolveIngestLanguages,
  lockKeyForLanguages,
  getIngestBudgetMs,
  INGEST_LANGS,
} = require('../config/ingestLanguages');
const {
  fetchRssItems,
  normalizeRssItem,
  resolveGoogleNewsPublisherUrl,
  summarizeInputFromItem,
  collectPlainTextForSummary,
  detectLanguage,
  prepareForSummaryFromIngestItem,
  prepareForSummarization,
  summarizeForRssIngest,
  extractiveSummaryNative,
  translateEnglishToFeedLanguage,
} = require('./rssService');
const {
  summarizeForIngest,
  isSummaryBudgetTight,
} = require('./ingestSummaryService');
const { extractReadableArticle } = require('./articleExtractionService');
const { classifyArticleLocalGeo, resolveFeedLocation, articleMentionsDistrict } = require('./districtClassifierService');

const STATE_LEVEL_DISTRICT_NAMES = new Set([
  'Andhra Pradesh',
  'Telangana',
  'Uttar Pradesh',
  'Bihar',
  'Rajasthan',
  'Punjab',
  'Haryana',
  'Delhi',
]);
const { forwardGeocode } = require('../utils/geocode');
const cacheService = require('../utils/cacheService');
const { runYoutubeIngestion } = require('./youtubeIngestionService');

let ingestState = {
  isRunning: false,
  lastRunAt: null,
  lastSuccessAt: null,
  lastSummary: null,
  lastError: null,
};

const ingestStateByLock = new Map();

function getIngestLockState(lockKey) {
  if (!ingestStateByLock.has(lockKey)) {
    ingestStateByLock.set(lockKey, {
      lockKey,
      isRunning: false,
      lastRunAt: null,
      lastSuccessAt: null,
      lastSummary: null,
      lastError: null,
    });
  }
  return ingestStateByLock.get(lockKey);
}

const { setIngestionSocket, emitFeedUpdated } = require('./feedSocket');

/** Hyperlocal city feeds must run before state-wide AP/TG local buckets (dedupe keeps first insert). */
function localFeedSpecificity(feed) {
  const cat = String(feed?.categorySlug || '').toLowerCase();
  if (cat !== 'local') return 0;
  const loc = resolveFeedLocation(feed);
  if (loc.locationCity && loc.locationDistrict) return 4;
  if (loc.locationDistrict || loc.locationCity) return 3;
  const ps = String(feed?.politicsScope || '').toLowerCase();
  if (ps === 'andhra' || ps === 'telangana') return 1;
  if (['up', 'bihar', 'rajasthan', 'punjab', 'haryana', 'delhi', 'north', 'states'].includes(ps)) {
    return 1;
  }
  return 2;
}

function sortLocalFeedsBySpecificity(feeds) {
  return [...feeds].sort((a, b) => localFeedSpecificity(b) - localFeedSpecificity(a));
}

/** District-tagged NTV / Amar Ujala / TV9 feeds — skip expensive geocode + AI summarization. */
function isHyperlocalDistrictRssFeed(feed, feedLoc) {
  const url = String(feed?.url || '');
  const hasDistrict = Boolean(feedLoc?.locationDistrict);
  return hasDistrict && (
    url.includes('ntvtelugu.com/')
    || url.includes('amarujala.com/rss/')
    || url.includes('tv9telugu.com/category/')
  );
}

/** Round-robin RSS feed cursor so large Hindi district lists complete across cron cycles. */
async function rotateFeedsForIngest(feeds, language) {
  const lang = String(language || '').toLowerCase();
  if (!lang || feeds.length <= 1) {
    return { feeds, commitRotation: async () => {} };
  }
  const key = `ingest:rssOffset:${lang}`;
  let offset = Number(await cacheService.get(key)) || 0;
  offset = ((offset % feeds.length) + feeds.length) % feeds.length;
  return {
    feeds: [...feeds.slice(offset), ...feeds.slice(0, offset)],
    async commitRotation(processedCount) {
      const n = Number(processedCount) || 0;
      if (n <= 0) return;
      const next = (offset + n) % feeds.length;
      await cacheService.set(key, next, 7 * 24 * 60 * 60 * 1000);
    },
  };
}

/** Round-robin across categorySlug so politics/sports/business all get processed each run. */
function interleaveFeedsByCategory(feeds) {
  const buckets = new Map();
  for (const f of feeds) {
    if (!f?.url) continue;
    const key = String(f.categorySlug || 'general').toLowerCase();
    if (!buckets.has(key)) buckets.set(key, []);
    buckets.get(key).push(f);
  }
  if (buckets.has('local')) {
    buckets.set('local', sortLocalFeedsBySpecificity(buckets.get('local')));
  }
  const keys = [...buckets.keys()];
  const out = [];
  let more = true;
  while (more) {
    more = false;
    for (const key of keys) {
      const arr = buckets.get(key);
      if (arr?.length) {
        out.push(arr.shift());
        more = true;
      }
    }
  }
  return out;
}

/**
 * Round-robin en → hi → te (then other langs) so a 12–20 min budget still ingests
 * regional feeds. Category-only interleave left ~60 English feeds ahead of Hindi/Telugu.
 */
function interleaveFeedsByLanguageAndCategory(feeds) {
  const langOrder = ['en', 'hi', 'te'];
  const byLang = new Map(langOrder.map((l) => [l, []]));
  const other = [];
  for (const f of feeds) {
    if (!f?.url) continue;
    const lang = String(f.language || 'en').toLowerCase();
    if (byLang.has(lang)) byLang.get(lang).push(f);
    else other.push(f);
  }
  const lists = [
    ...langOrder.map((l) => interleaveFeedsByCategory(byLang.get(l) || [])),
    interleaveFeedsByCategory(other),
  ].filter((list) => list.length > 0);

  const out = [];
  let more = true;
  while (more) {
    more = false;
    for (const list of lists) {
      if (list.length > 0) {
        out.push(list.shift());
        more = true;
      }
    }
  }
  return out;
}

/**
 * Hard wall-clock limit so a single run cannot hold `isRunning` forever (cron then skips every slot).
 * RSS-only runs with many feeds + og:image + body enrich + HF summarize can exceed 15–30+ minutes otherwise.
 * Set INGEST_MAX_RUNTIME_MS=0 for no limit (not recommended on PaaS).
 */
function createIngestBudget({ language } = {}) {
  const ms = getIngestBudgetMs(language);
  if (ms == null) {
    return {
      limitMs: null,
      throwIfExpired() {},
      describe: () => 'unlimited',
    };
  }
  const started = Date.now();
  return {
    limitMs: ms,
    started,
    remainingMs() {
      return ms - (Date.now() - started);
    },
    throwIfExpired(phase) {
      if (Date.now() - started > ms) {
        throw new Error(
          `[ingest${language ? `:${language}` : ''}] time budget exceeded (${ms}ms) at ${phase || '?'}. `
            + 'Set INGEST_MAX_RUNTIME_MS or INGEST_MAX_RUNTIME_MS_EN|HI|TE higher, '
            + 'or lower RSS_INSERTS_PER_FEED / RSS_SCAN_PER_FEED.',
        );
      }
    },
    describe: () => `${Math.round(ms / 1000)}s`,
  };
}

function rssFeedMinRemainingMs() {
  return Math.max(5000, Number(process.env.INGEST_RSS_FEED_MIN_REMAINING_MS || 20_000));
}

function rssItemMinRemainingMs() {
  return Math.max(3000, Number(process.env.INGEST_RSS_ITEM_MIN_REMAINING_MS || 10_000));
}

const SYSTEM_REPORTER_EMAIL = process.env.SCRAPER_SYSTEM_EMAIL || 'scraper@newsnow.local';
const SYSTEM_REPORTER_PASSWORD = process.env.SCRAPER_SYSTEM_PASSWORD || 'change_me_123';
const DEFAULT_CATEGORY_SLUG = process.env.SCRAPER_DEFAULT_CATEGORY || 'general';
const SCRAPER_AUTO_APPROVE = process.env.SCRAPER_AUTO_APPROVE !== 'false';
const NEWSAPI_MULTI_CATEGORY = process.env.NEWSAPI_MULTI_CATEGORY !== 'false';
const INGEST_REHOST_IMAGES = process.env.INGEST_REHOST_IMAGES !== 'false';

function stripMarkup(input = '') {
  return decodeHtmlEntities(
    String(input || '')
      .replace(/<script[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style[\s\S]*?<\/style>/gi, ' ')
      .replace(/<[^>]*>/g, ' '),
  );
}

function scriptRatio(text, re) {
  const t = String(text || '');
  const letters = (t.match(/[A-Za-z\u0900-\u097F\u0C00-\u0C7F]/g) || []).length;
  if (!letters) return 0;
  const scriptChars = (t.match(re) || []).length;
  return scriptChars / letters;
}

function matchesExpectedFeedLanguage(rawItem, feedLang) {
  const fl = String(feedLang || '').toLowerCase();
  if (fl !== 'hi' && fl !== 'te') return true;
  const sample = stripMarkup(
    `${rawItem?.title || ''} ${rawItem?.contentSnippet || rawItem?.content || rawItem?.summary || ''}`,
  ).slice(0, 1000);
  if (!sample) return true;
  const detected = detectLanguage(sample);
  if (fl === 'hi') {
    if (detected === 'hin') return true;
    return scriptRatio(sample, /[\u0900-\u097F]/g) >= 0.22;
  }
  if (detected === 'tel') return true;
  return scriptRatio(sample, /[\u0C00-\u0C7F]/g) >= 0.18;
}

/** Sports RSS: keep English feeds English-only; hi/te use script checks above. */
function matchesSportsRssLanguage(rawItem, feedLang, categorySlug) {
  if (String(categorySlug || '').toLowerCase() !== 'sports') {
    return matchesExpectedFeedLanguage(rawItem, feedLang);
  }
  const fl = String(feedLang || 'en').toLowerCase();
  const sample = stripMarkup(
    `${rawItem?.title || ''} ${rawItem?.contentSnippet || rawItem?.content || rawItem?.summary || ''}`,
  ).slice(0, 1000);
  if (!sample) return true;
  if (fl === 'en') {
    if (scriptRatio(sample, /[\u0900-\u097F]/g) >= 0.22) return false;
    if (scriptRatio(sample, /[\u0C00-\u0C7F]/g) >= 0.18) return false;
    return true;
  }
  return matchesExpectedFeedLanguage(rawItem, feedLang);
}

/** Resolve politicsScope — feed section is a hint; story text wins for regional vs world. */
function resolvePoliticsScope(item, feed) {
  const feedLang = String(feed.language || '').toLowerCase();
  const feedCat = String(feed.categorySlug || '').toLowerCase();
  const s = String(feed.politicsScope || '').toLowerCase();
  const valid = ['all', 'andhra', 'telangana', 'india', 'international', 'north', 'states', 'delhi', 'up', 'bihar', 'rajasthan', 'punjab', 'haryana'].includes(s)
    ? s
    : null;

  if (feedCat !== 'politics' && feedCat !== 'local') return null;

  const inferred = inferPoliticsScopeFromStory(item, null);

  if (feedCat === 'politics') {
    if (valid && valid !== 'all') {
      if (inferred && ['andhra', 'telangana', 'north', 'international', 'up', 'bihar', 'rajasthan', 'punjab', 'haryana', 'delhi'].includes(inferred)) {
        return inferred;
      }
      if (valid === 'international' && inferred !== 'international') return inferred;
      if (valid === 'india' && inferred === 'international') return 'international';
      return valid;
    }
    return inferred || 'india';
  }

  if (feedCat === 'local' && ['andhra', 'telangana', 'north', 'states', 'delhi', 'up', 'bihar', 'rajasthan', 'punjab', 'haryana'].includes(s)) return s;
  if (feedCat === 'local' && (feedLang === 'te' || feedLang === 'hi')) {
    return inferPoliticsScopeFromStory(item, s);
  }
  return null;
}

/** Infer india vs international vs AP/TG from story text when feed scope is broad. */
function inferPoliticsScopeFromStory(postLike, feedScope) {
  const fromFeed = String(feedScope || '').toLowerCase();
  if (['andhra', 'telangana', 'north', 'states', 'delhi', 'up', 'bihar', 'rajasthan', 'punjab', 'haryana'].includes(fromFeed)) {
    return fromFeed;
  }
  const title = stripMarkup(postLike?.title || '');
  const description = stripMarkup(
    `${postLike?.summary || ''} ${postLike?.body || ''}`,
  );
  return inferPoliticsScope(title, description);
}

async function ensureSystemReporter() {
  let reporter = await prisma.user.findUnique({ where: { email: SYSTEM_REPORTER_EMAIL } });
  if (!reporter) {
    reporter = await prisma.user.create({
      data: {
        name: 'News Ingestion Bot',
        email: SYSTEM_REPORTER_EMAIL,
        password: await bcrypt.hash(SYSTEM_REPORTER_PASSWORD, 10),
        role: 'reporter',
        isVerified: true,
      },
    });
  }
  return reporter;
}

async function getCategoryBySlug(slug) {
  let category = await prisma.category.findFirst({
    where: { slug: slug || DEFAULT_CATEGORY_SLUG, isActive: true },
    orderBy: { order: 'asc' },
  });
  if (!category) {
    category = await prisma.category.findFirst({
      where: { isActive: true },
      orderBy: [{ order: 'asc' }, { createdAt: 'asc' }],
    });
  }
  if (!category) {
    throw new Error('No active category found. Seed categories before running ingestion.');
  }
  return category;
}

function ingestLocationScore(fields = {}) {
  let score = 0;
  if (fields.locationMandal) score += 8;
  if (fields.locationDistrict) score += 4;
  if (fields.locationCity) score += 2;
  if (fields.locationLatitude != null && fields.locationLongitude != null) score += 1;
  if (fields.locationState) score += 0.5;
  if (fields.locationDistrict && STATE_LEVEL_DISTRICT_NAMES.has(fields.locationDistrict)) {
    score -= 4;
  }
  if (fields.locationCity && STATE_LEVEL_DISTRICT_NAMES.has(fields.locationCity)) {
    score -= 2;
  }
  return score;
}

function buildDuplicateOrClauses(item) {
  const windowStart = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const orClauses = [];

  const canonical = canonicalizeUrl(item.sourceUrl);
  if (canonical) {
    orClauses.push({ sourceUrlHash: hashUrl(canonical) });
  }

  const fp = titleFingerprint(item.title);
  if (fp) orClauses.push({ titleFingerprint: fp });

  const sumFp = summaryFingerprint(item.summary);
  if (sumFp) orClauses.push({ summaryFingerprint: sumFp });

  const titleNorm = normalizeTitle(item.title);
  if (titleNorm.length >= 8) {
    orClauses.push({
      titleNormalized: titleNorm,
      createdAt: { gte: windowStart },
    });
  }

  return orClauses;
}

async function findDuplicateForIngest(item) {
  const lang = String(item.language || 'en').toLowerCase();
  const langClause = lang && lang !== 'all' ? { language: lang } : {};
  const orClauses = buildDuplicateOrClauses(item);
  if (orClauses.length === 0) return null;

  return prisma.newsPost.findFirst({
    where: {
      ...langClause,
      OR: orClauses,
    },
    select: {
      id: true,
      categoryId: true,
      category: { select: { slug: true } },
      locationCity: true,
      locationDistrict: true,
      locationMandal: true,
      locationState: true,
      locationLatitude: true,
      locationLongitude: true,
      sourceName: true,
    },
  });
}

async function isDuplicate(item) {
  return Boolean(await findDuplicateForIngest(item));
}

async function maybeEnrichDuplicateLocation(existing, postFields, sourceName, { categoryId, categorySlug } = {}) {
  if (!existing?.id) return false;
  const oldScore = ingestLocationScore(existing);
  const newScore = ingestLocationScore(postFields);
  const moreSpecificSource = sourceName && String(sourceName).includes(' - ')
    && !String(existing.sourceName || '').includes(' - ');
  const promoteToLocal = String(categorySlug || '').toLowerCase() === 'local'
    && categoryId
    && postFields.locationDistrict
    && existing.categoryId !== categoryId;
  const existingSlug = String(existing.category?.slug || '').toLowerCase();
  const incomingSlug = String(categorySlug || '').toLowerCase();
  const promoteToSection = Boolean(
    categoryId
    && incomingSlug
    && incomingSlug !== 'general'
    && existingSlug === 'general'
    && sourceName
    && String(sourceName).includes(' - '),
  );
  if (newScore <= oldScore && !moreSpecificSource && !promoteToLocal && !promoteToSection) {
    return false;
  }

  const data = {};
  if (postFields.locationMandal && !existing.locationMandal) {
    data.locationMandal = postFields.locationMandal;
  }
  if (postFields.locationDistrict
    && (!existing.locationDistrict
      || STATE_LEVEL_DISTRICT_NAMES.has(existing.locationDistrict))) {
    data.locationDistrict = postFields.locationDistrict;
  }
  if (postFields.locationCity
    && (!existing.locationCity
      || STATE_LEVEL_DISTRICT_NAMES.has(existing.locationCity))) {
    data.locationCity = postFields.locationCity;
  }
  if (postFields.locationState && !existing.locationState) {
    data.locationState = postFields.locationState;
  }
  if (
    postFields.locationLatitude != null
    && postFields.locationLongitude != null
    && (existing.locationLatitude == null || existing.locationLongitude == null)
  ) {
    data.locationLatitude = postFields.locationLatitude;
    data.locationLongitude = postFields.locationLongitude;
    data.locationCountry = postFields.locationCountry || 'India';
    data.locationCapturedAt = postFields.locationCapturedAt || new Date();
  }
  if (sourceName && String(sourceName).includes(' - ')) {
    const preferHyperlocalSource = isHyperlocalFeedSource(sourceName)
      && isNonGeoFeedSource(existing.sourceName);
    if (preferHyperlocalSource || !String(existing.sourceName || '').includes(' - ')) {
      data.sourceName = sourceName;
    }
  }
  if (promoteToLocal || promoteToSection) {
    data.categoryId = categoryId;
  }
  if (Object.keys(data).length === 0) return false;

  await prisma.newsPost.update({
    where: { id: existing.id },
    data,
  });
  return true;
}

function recordInsertedArticle(stats, post) {
  if (!post?.title) return;
  if (!Array.isArray(stats.insertedArticles)) stats.insertedArticles = [];
  stats.insertedArticles.push({ id: post.id, title: post.title });
}

function toPostDoc(item, reporterId, categoryId, sourceName) {
  return {
    title: item.title.slice(0, 200),
    body: item.body || item.title,
    summary: item.summary,
    reporterId,
    categoryId,
    media: item.mediaUrl
      ? [{
        type: 'image',
        url: item.mediaUrl,
        ...(item.mediaPublicId ? { publicId: item.mediaPublicId } : {}),
      }]
      : [],
    status: SCRAPER_AUTO_APPROVE ? 'approved' : 'pending',
    approvedAt: SCRAPER_AUTO_APPROVE ? new Date() : null,
    tags: item.tags || [],
    language: item.language || 'en',
    originalLanguage: item.originalLanguage || null,
    sourceName,
    sourceUrl: item.sourceUrl || null,
    sourceUrlHash: (() => {
      const c = canonicalizeUrl(item.sourceUrl);
      return c ? hashUrl(c) : null;
    })(),
    titleNormalized: normalizeTitle(item.title) || null,
    titleFingerprint: titleFingerprint(item.title) || null,
    summaryFingerprint: summaryFingerprint(item.summary) || null,
    sourcePublishedAt: item.sourcePublishedAt ? new Date(item.sourcePublishedAt) : null,
    sourceType: item.sourceType,
    politicsScope: ['all', 'andhra', 'telangana', 'india', 'international', 'north', 'states', 'delhi', 'up', 'bihar', 'rajasthan', 'punjab', 'haryana'].includes(String(item.politicsScope || '').toLowerCase())
      ? String(item.politicsScope).toLowerCase()
      : null,
    constituency: item.constituency || 'Unknown',
    locationCity: item.locationCity || null,
    locationDistrict: item.locationDistrict || null,
    locationMandal: item.locationMandal || null,
    locationState: item.locationState || null,
    locationLatitude: item.locationLatitude ?? null,
    locationLongitude: item.locationLongitude ?? null,
    locationCountry: item.locationCountry || (item.locationCity ? 'India' : null),
    locationCapturedAt: item.locationCapturedAt || null,
    entities: Array.isArray(item.entities) ? item.entities : [],
    scrapedAt: new Date(),
    scrapeConfidence: item.scrapeConfidence,
  };
}

function summarizeForPost(text) {
  const cleaned = cleanArticlePlainText(String(text || ''), { stripHtml: true });
  if (!cleaned) return null;
  const extractive = extractiveSummaryNative(cleaned);
  if (extractive) return clipSummaryForStorage(extractive);
  return clipSummaryForStorage(cleaned);
}

/** AI/extractive summary for ingest; respects budget and chat-priority yield. */
async function summarizeIngestItem({
  item,
  rawRssItem = null,
  feedLang = 'en',
  budget = null,
}) {
  if (process.env.RSS_SKIP_AI_SUMMARY === 'true') return '';
  const prep = prepareForSummaryFromIngestItem(item, rawRssItem);
  if (!prep.textForSummary) return '';
  const result = await summarizeForIngest({
    text: prep.textForSummary,
    originalLang: prep.originalLang,
    feedLang,
    budget,
  });
  return result.summary || '';
}

function getIngestPlans() {
  if (!NEWSAPI_MULTI_CATEGORY) {
    return [{ categorySlug: DEFAULT_CATEGORY_SLUG, newsApiCategory: null }];
  }
  return newsApiIngestPlan;
}

/** Languages for API ingestion — scoped by run or env (en/te/hi). */
function getIngestLanguages(options = {}) {
  const active = resolveIngestLanguages(options);
  if (active.length) return active;

  const langs = new Set(['en', 'te', 'hi']);
  if (process.env.RSS_ENABLED !== 'false') {
    for (const feed of getRssFeeds()) {
      const l = String(feed.language || '').trim().toLowerCase();
      if (l) langs.add(l);
    }
  }
  return [...langs];
}

async function runIngestion({
  triggeredBy = 'scheduler',
  languages,
  categorySlugs,
  includeYoutube,
  includePolitical,
} = {}) {
  const activeLanguages = getIngestLanguages({ languages });
  const lockKey = lockKeyForLanguages(activeLanguages);
  const lockState = lockKey === 'global' ? ingestState : getIngestLockState(lockKey);

  if (lockState.isRunning) {
    return {
      success: false,
      skipped: true,
      message: `Ingestion already running (${lockKey}).`,
      state: lockState,
    };
  }

  lockState.isRunning = true;
  lockState.lastRunAt = new Date();
  lockState.lastError = null;
  if (lockKey === 'global') {
    ingestState.isRunning = true;
    ingestState.lastRunAt = lockState.lastRunAt;
    ingestState.lastError = null;
  }

  const budgetLang = activeLanguages.length === 1 ? activeLanguages[0] : null;

  const stats = {
    triggeredBy,
    languages: activeLanguages,
    lockKey,
    startedAt: new Date(),
    fetched: 0,
    inserted: 0,
    duplicates: 0,
    skippedNoImage: 0,
    categoryFiltered: 0,
    youtubeInserted: 0,
    youtubeDuplicates: 0,
    youtubeSkippedRestricted: 0,
    failed: 0,
    fallbacks: 0,
    languageFiltered: 0,
    politicsFiltered: 0,
    sourceRuns: [],
  };

  try {
    const useGNews = Boolean(process.env.GNEWS_API_KEY?.trim());
    const useNewsApi = Boolean(process.env.NEWSAPI_KEY?.trim());
    const rssEnabled = process.env.RSS_ENABLED !== 'false';
    const budget = createIngestBudget({ language: budgetLang });

    console.log(
      `[ingest] begin (${triggeredBy}) langs=${activeLanguages.join(',')} lock=${lockKey} `
        + `maxRuntime=${budget.describe()} api=${Boolean(useGNews || useNewsApi)} rss=${rssEnabled}`,
    );

    if (!useGNews && !useNewsApi && !rssEnabled) {
      const msg =
        'Enable RSS (RSS_ENABLED not false) or set GNEWS_API_KEY / NEWSAPI_KEY for API headlines.';
      ingestState.lastError = msg;
      stats.endedAt = new Date();
      return { success: false, error: msg, stats };
    }

    const reporter = await ensureSystemReporter();

    if (useGNews || useNewsApi) {
      const defaultProviderLabel = useGNews ? 'GNews' : 'NewsAPI';
      const gnewsFallbackWarned = { value: false };

      async function fetchApiItems(options) {
        if (!useGNews) {
          return { items: await fetchNewsApiItems(options), providerLabel: 'NewsAPI' };
        }
        try {
          return { items: await fetchGNewsItems(options), providerLabel: 'GNews' };
        } catch (error) {
          const msg = String(error?.message || '');
          const gnewsBlocked = /forbidden|403|401|invalid api key|unauthorized/i.test(msg);
          if (useNewsApi && gnewsBlocked) {
            if (!gnewsFallbackWarned.value) {
              gnewsFallbackWarned.value = true;
              console.warn(
                `[ingest] GNews unavailable (${msg}); falling back to NewsAPI for this run.`,
              );
            }
            return { items: await fetchNewsApiItems(options), providerLabel: 'NewsAPI' };
          }
          throw error;
        }
      }

      // Same language list for both providers so Telugu/Hindi feeds fill when using NewsAPI too (where supported).
      const ingestLanguages = activeLanguages;
      if (!useGNews) {
        console.log(
          '[ingest] NewsAPI: fetching en, te, hi per plan (unsupported langs return 0 articles). '
            + 'Prefer GNEWS_API_KEY for reliable regional headlines.',
        );
      }

      const plans = getIngestPlans();
      const perRequest = Math.min(
        100,
        Math.max(
          4,
          Number(
            process.env.GNEWS_ITEMS_PER_CATEGORY
              || process.env.NEWSAPI_ITEMS_PER_CATEGORY
              || Math.ceil(36 / Math.max(plans.length, 1)),
          ),
        ),
      );

      for (const ingestLang of ingestLanguages) {
        budget.throwIfExpired(`api:lang:${ingestLang}`);
        for (const plan of plans) {
          budget.throwIfExpired(`api:plan:${ingestLang}:${plan.categorySlug}`);
          let category;
          try {
            category = await getCategoryBySlug(plan.categorySlug);
          } catch {
            stats.sourceRuns.push({
              source: `${defaultProviderLabel}:${ingestLang}:${plan.categorySlug}`,
              success: false,
              error: `Category slug "${plan.categorySlug}" not found; seed categories.`,
            });
            continue;
          }

          const apiLabel = plan.newsApiCategory ?? 'mixed';
          try {
            const { items, providerLabel } = await fetchApiItems({
              newsApiCategory: plan.newsApiCategory,
              pageSize: perRequest,
              language: ingestLang,
            });
            stats.fetched += items.length;

            let itemIdx = 0;
            for (const item of items) {
              itemIdx += 1;
              if (itemIdx % 25 === 1) budget.throwIfExpired(`api:items:${ingestLang}:${plan.categorySlug}`);
              if (!item.title) {
                stats.failed += 1;
                continue;
              }
              if (await isDuplicate(item)) {
                stats.duplicates += 1;
                continue;
              }

              let apiSummary = item.summary;
              const apiAiSummary = await summarizeIngestItem({
                item,
                feedLang: ingestLang,
                budget,
              });
              if (apiAiSummary && String(apiAiSummary).trim()) {
                apiSummary = String(apiAiSummary).trim();
              }

              // Re-host external thumbnails on Cloudinary for reliability (no hotlink blocking).
              let postFields = { ...item, summary: apiSummary };
              let mediaUrl = item.mediaUrl;
              if (mediaUrl && isUnusableFeedImageUrl(mediaUrl)) mediaUrl = null;
              if (!mediaUrl && item.sourceUrl) {
                // eslint-disable-next-line no-await-in-loop
                mediaUrl = await fetchBestImageFallback(item.sourceUrl);
              }
              if (mediaUrl && !isUnusableFeedImageUrl(mediaUrl)) {
                postFields = { ...item, summary: apiSummary, mediaUrl };
                if (INGEST_REHOST_IMAGES) {
                  const reh = await rehostExternalImageForIngest(mediaUrl, {
                    referer: item.sourceUrl || null,
                  });
                  if (reh.ok && reh.url) {
                    postFields = {
                      ...postFields,
                      mediaUrl: reh.url,
                      mediaPublicId: reh.publicId || null,
                    };
                    stats.rehostOk = (stats.rehostOk || 0) + 1;
                    if (reh.backend === 'local') stats.rehostLocal = (stats.rehostLocal || 0) + 1;
                    if (reh.backend === 'cloudinary') stats.rehostCloudinary = (stats.rehostCloudinary || 0) + 1;
                  } else if (reh.reason) {
                    stats.rehostFailed = (stats.rehostFailed || 0) + 1;
                  }
                }
              } else {
                postFields = { ...item, summary: apiSummary, mediaUrl: null };
              }

              const label = `${providerLabel} · ${item.apiSourceName || 'headlines'}`;
              const { apiSourceName, ...postDocFields } = postFields;
              try {
                const created = await createNewsPost(toPostDoc(postDocFields, reporter.id, category.id, label));
                stats.inserted += 1;
                recordInsertedArticle(stats, created);
              } catch (error) {
                if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
                  stats.duplicates += 1;
                  continue;
                }
                throw error;
              }
            }

            stats.sourceRuns.push({
              source: `${providerLabel}:${ingestLang}:${plan.categorySlug}/${apiLabel}`,
              mode: 'api',
              count: items.length,
              success: true,
            });
          } catch (error) {
            stats.failed += 1;
            stats.sourceRuns.push({
              source: `${defaultProviderLabel}:${ingestLang}:${plan.categorySlug}/${apiLabel}`,
              success: false,
              error: error.message,
            });
          }
        }
      }
    } else {
      console.warn(
        '[ingest] No GNEWS_API_KEY or NEWSAPI_KEY — running RSS-only ingestion.',
      );
    }

    // RSS ingestion (second source): reliable thumbnails + extra coverage.
    if (rssEnabled) {
      const rssSource = getRssFeeds({ languages: activeLanguages, categorySlugs });
      const baseFeeds = activeLanguages.length === 1
        ? interleaveFeedsByCategory(rssSource)
        : interleaveFeedsByLanguageAndCategory(rssSource);
      const rotation = activeLanguages.length === 1
        ? await rotateFeedsForIngest(baseFeeds, activeLanguages[0])
        : { feeds: baseFeeds, commitRotation: async () => {} };
      const feeds = rotation.feeds;
      budget.throwIfExpired('rss:before-loop');
      const maxPerFeed = Math.min(
        50,
        Math.max(5, Number(process.env.RSS_ITEMS_PER_FEED || 25)),
      );
      const maxScanPerFeed = Math.min(
        100,
        Math.max(maxPerFeed, Number(process.env.RSS_SCAN_PER_FEED || 30)),
      );
      const targetInsertsPerFeed = Math.max(
        1,
        Number(process.env.RSS_INSERTS_PER_FEED || 6),
      );
      const langCounts = feeds.reduce((acc, f) => {
        const l = String(f.language || 'en').toLowerCase();
        acc[l] = (acc[l] || 0) + 1;
        return acc;
      }, {});
      console.log(
        `[ingest] RSS processing ${feeds.length} feeds `
          + `(langs=${activeLanguages.join(',')}, scan up to ${maxScanPerFeed}, `
          + `target ${targetInsertsPerFeed} new/feed; counts: ${JSON.stringify(langCounts)})`,
      );

      let feedIdx = 0;
      let feedsProcessed = 0;
      for (const feed of feeds) {
        feedIdx += 1;
        feedsProcessed += 1;
        budget.throwIfExpired(`rss:feed-start:${feedIdx}/${feeds.length}`);
        if (budget.limitMs != null && budget.remainingMs() < rssFeedMinRemainingMs()) {
          console.warn(
            `[ingest] RSS stopping early at feed ${feedIdx}/${feeds.length} `
              + `(${Math.round(budget.remainingMs())}ms budget left)`,
          );
          break;
        }
        if (!feed?.url) continue;
        let category;
        try {
          category = await getCategoryBySlug(feed.categorySlug || DEFAULT_CATEGORY_SLUG);
        } catch {
          stats.sourceRuns.push({
            source: `RSS:${feed.name || 'RSS'}:${feed.categorySlug || DEFAULT_CATEGORY_SLUG}`,
            success: false,
            error: `Category slug "${feed.categorySlug}" not found; seed categories.`,
          });
          continue;
        }

        try {
          const items = await fetchRssItems(feed.url);
          const feedCatSlug = String(feed.categorySlug || '').toLowerCase();
          const feedLoc = resolveFeedLocation(feed);
          const hyperlocalDistrictFeed = isHyperlocalDistrictRssFeed(feed, feedLoc);
          const scanLimit = hyperlocalDistrictFeed
            ? Math.min(12, maxScanPerFeed)
            : maxScanPerFeed;
          const slice = items.slice(0, scanLimit);
          stats.fetched += slice.length;
          let insertedThisFeed = 0;
          let feedGeoCoords = null;
          if (
            feedCatSlug === 'local'
            && (feedLoc.locationCity || feedLoc.locationDistrict)
            && !hyperlocalDistrictFeed
          ) {
            try {
              feedGeoCoords = await forwardGeocode(
                feedLoc.locationCity || feedLoc.locationDistrict,
                { state: feedLoc.locationState },
              );
            } catch {
              feedGeoCoords = null;
            }
          }

          const insertsTarget = hyperlocalDistrictFeed
            ? Math.min(2, targetInsertsPerFeed)
            : targetInsertsPerFeed;

          for (let ri = 0; ri < slice.length; ri++) {
            if (insertedThisFeed >= insertsTarget) break;
            if (ri % 10 === 0) {
              budget.throwIfExpired(`rss:${feedIdx}/${feeds.length}:${feed.name || 'feed'}`);
            }
            const raw = slice[ri];
            const item = normalizeRssItem(raw, feed);
            if (!item.title) {
              stats.failed += 1;
              continue;
            }
            const publishedAt = item.sourcePublishedAt
              ? new Date(item.sourcePublishedAt)
              : null;
            if (publishedAt && !Number.isNaN(publishedAt.getTime())) {
              const feedCatLower = String(feed.categorySlug || '').toLowerCase();
              const maxAgeDays = feedCatLower === 'politics'
                ? (String(feed.language || '').toLowerCase() === 'te' ? 21 : 12)
                : feedCatLower === 'local'
                  ? 90
                  : 28;
              if (Date.now() - publishedAt.getTime() > maxAgeDays * 24 * 60 * 60 * 1000) {
                stats.staleFiltered = (stats.staleFiltered || 0) + 1;
                continue;
              }
            }
            if (
              !matchesSportsRssLanguage(
                raw,
                feed.language || '',
                feed.categorySlug || '',
              )
            ) {
              stats.languageFiltered += 1;
              continue;
            }
            // hi/te politics feeds: strict noise filter only (cinema/sports/etc.), keep real politics.
            const feedLang = String(feed.language || '').toLowerCase();
            const feedCat = String(feed.categorySlug || '').toLowerCase();
            if (
              (feedLang === 'te' || feedLang === 'hi')
              && feedCat === 'politics'
              && !acceptPoliticsRssItem(item, feedLang, { fromPoliticsFeed: true })
            ) {
              stats.politicsFiltered += 1;
              continue;
            }
            if (
              String(feed.categorySlug || '').toLowerCase() !== 'general'
              && !passesIngestCategoryGate(item, feed.categorySlug, { feedUrl: feed.url })
            ) {
              stats.categoryFiltered += 1;
              continue;
            }

            const decodedBody = cleanArticlePlainText(
              collectPlainTextForSummary(item.body, summarizeInputFromItem(raw), item.title),
            );
            let displayTitle = decodeHtmlEntities(String(item.title || '')).slice(0, 200);

            const feedUrl = String(feed.url || '');
            const isHyperlocalDistrictFeed =
              !!feedLoc.locationDistrict
              && (
                feedUrl.includes('ntvtelugu.com/')
                || feedUrl.includes('amarujala.com/rss/')
                || feedUrl.includes('tv9telugu.com/category/')
              );

            if (
              feedCat === 'local'
              && feedLoc.locationDistrict
              && !isHyperlocalDistrictFeed
              && !articleMentionsDistrict(`${displayTitle} ${decodedBody}`, feedLoc)
            ) {
              stats.districtFiltered = (stats.districtFiltered || 0) + 1;
              continue;
            }

            // Resolve publisher URL before dedupe (Google News links differ per feed).
            let sourceUrl = item.sourceUrl || null;
            if (
              feed.resolvePublisherUrl
              && sourceUrl
              && String(sourceUrl).includes('news.google.com')
            ) {
              try {
                // eslint-disable-next-line no-await-in-loop
                const resolved = await resolveGoogleNewsPublisherUrl(sourceUrl, {
                  preferredHost: feed.preferredHost || null,
                });
                if (resolved) sourceUrl = resolved;
              } catch { /* ignore */ }
            }

            if (budget.limitMs != null && budget.remainingMs() < rssItemMinRemainingMs()) {
              break;
            }

            const prep = prepareForSummaryFromIngestItem(item, raw);
            const summaryInput = prep.textForSummary;
            const originalLang = prep.originalLang;
            const fallbackSummary = summarizeForPost(decodedBody)
              || summarizeForPost(decodeHtmlEntities(String(item.summary || '').trim()));

            let summaryPrimary = '';
            const budgetTight = isSummaryBudgetTight(budget) || hyperlocalDistrictFeed;
            if (
              !hyperlocalDistrictFeed
              && ['hi', 'te'].includes(feedLang)
              && originalLang === 'eng'
            ) {
              try {
                // eslint-disable-next-line no-await-in-loop
                const tr = await translateEnglishToFeedLanguage(
                  String(item.title || '').slice(0, 400),
                  feed.language,
                );
                if (tr && tr.trim()) displayTitle = tr.slice(0, 200);
              } catch { /* keep RSS title */ }
            }

            if (summaryInput && !budgetTight) {
              const sumResult = await summarizeForIngest({
                text: summaryInput,
                originalLang,
                feedLang,
                budget,
              });
              summaryPrimary = sumResult.summary || '';
              if (sumResult.source === 'ai_failed' || sumResult.source === 'chat_priority') {
                stats.fallbacks += 1;
              }
            }

            let postFields = {
              ...item,
              title: displayTitle,
              sourceUrl,
              body: decodedBody.slice(0, 10000) || displayTitle,
              summary: decodeHtmlEntities(summaryPrimary || fallbackSummary || item.summary || '')
                || fallbackSummary
                || summarizeForPost(decodedBody),
              originalLanguage: originalLang,
              politicsScope: resolvePoliticsScope(item, feed),
            };
            if (feedCat === 'local' || feedCat === 'politics') {
              const geo = await classifyArticleLocalGeo(raw, feed, {
                language: feedLang,
                categorySlug: feedCat,
              });
              postFields = {
                ...postFields,
                locationCity: geo.locationCity || feedLoc.locationCity,
                locationDistrict: geo.locationDistrict || feedLoc.locationDistrict,
                locationMandal: geo.locationMandal || feed.locationMandal || null,
                locationState: geo.locationState || feedLoc.locationState,
                constituency: geo.constituency || postFields.constituency || 'Unknown',
                entities: Array.isArray(geo.entities) ? geo.entities : [],
              };
            }

            // Dedupe after geo tags so city feeds can upgrade state-wide duplicates.
            // eslint-disable-next-line no-await-in-loop
            const duplicate = await findDuplicateForIngest({
              ...postFields,
              title: displayTitle,
              sourceUrl,
              language: feedLang || item.language || 'en',
            });
            if (duplicate) {
              const label = `RSS · ${feed.name || 'RSS'}`;
              // eslint-disable-next-line no-await-in-loop
              const upgraded = await maybeEnrichDuplicateLocation(duplicate, postFields, label, {
                categoryId: category.id,
                categorySlug: feedCat,
              });
              if (upgraded) {
                stats.locationUpgraded = (stats.locationUpgraded || 0) + 1;
              } else {
                stats.duplicates += 1;
              }
              continue;
            }
            if (feedGeoCoords && feedCat === 'local') {
              postFields = {
                ...postFields,
                locationLatitude: feedGeoCoords.latitude,
                locationLongitude: feedGeoCoords.longitude,
                locationCity: postFields.locationCity || feedGeoCoords.city,
                locationState: postFields.locationState || feedGeoCoords.state,
                locationCountry: 'India',
                locationCapturedAt: feedGeoCoords.capturedAt || new Date(),
              };
            }

            // Some RSS (notably Google News RSS, but also several publisher feeds) ship without
            // enclosure/media tags. Always try og:image from the article page as a safety net so
            // every card has a real image — feeds can opt out by setting `ogImageFallback: false`,
            // and the global `RSS_OG_FALLBACK=false` env still disables it everywhere.
            if (
              !postFields.mediaUrl
              && feed.ogImageFallback !== false
              && process.env.RSS_OG_FALLBACK !== 'false'
              && postFields.sourceUrl
            ) {
              try {
                // eslint-disable-next-line no-await-in-loop
                const og = await fetchBestImageFallback(postFields.sourceUrl);
                if (og && !isUnusableFeedImageUrl(og)) {
                  postFields = { ...postFields, mediaUrl: og };
                }
              } catch { /* ignore */ }
            }

            // Enrich short bodies from the source URL (full article → better AI summary).
            const bodyTooShort = String(postFields.body || '').trim().length < 400;
            const enrichForSummary =
              process.env.RSS_ENRICH_FOR_SUMMARY !== 'false' && bodyTooShort;
            const shouldEnrichBody =
              !budgetTight
              && postFields.sourceUrl
              && bodyTooShort
              && (
                process.env.RSS_ENRICH_BODY !== 'false'
                || enrichForSummary
              );
            if (shouldEnrichBody) {
              try {
                // eslint-disable-next-line no-await-in-loop
                const ext = await extractReadableArticle(postFields.sourceUrl, {
                  timeoutMs: Number(process.env.RSS_ENRICH_TIMEOUT_MS || 9000),
                  maxBytes: Number(process.env.RSS_ENRICH_MAX_BYTES || 900000),
                  cacheTtlMs: Number(process.env.RSS_ENRICH_CACHE_TTL_MS || 30 * 60 * 1000),
                });
                const full = cleanArticlePlainText(String(ext?.text || ''));
                if (ext?.success && full.length >= 80) {
                  let summaryAfterEnrich = '';
                  if (!budgetTight) {
                    const prepFull = prepareForSummarization(full);
                    if (prepFull.textForSummary) {
                      const enrichResult = await summarizeForIngest({
                        text: prepFull.textForSummary,
                        originalLang: prepFull.originalLang,
                        feedLang,
                        budget,
                      });
                      summaryAfterEnrich = enrichResult.summary || '';
                      if (
                        enrichResult.source === 'ai_failed'
                        || enrichResult.source === 'chat_priority'
                      ) {
                        stats.fallbacks += 1;
                      }
                    }
                    if (
                      (!postFields.originalLanguage || postFields.originalLanguage === 'und')
                      && prepFull.originalLang
                      && prepFull.originalLang !== 'und'
                    ) {
                      postFields = { ...postFields, originalLanguage: prepFull.originalLang };
                    }
                  }
                  if (!summaryAfterEnrich || !String(summaryAfterEnrich).trim()) {
                    summaryAfterEnrich =
                      (summaryPrimary && String(summaryPrimary).trim())
                      || extractiveSummaryNative(full)
                      || summarizeForPost(full)
                      || fallbackSummary;
                  }
                  postFields = {
                    ...postFields,
                    body: full.slice(0, 10000),
                    summary: String(summaryAfterEnrich).trim(),
                  };
                }
              } catch { /* ignore */ }
            }

            if (postFields.mediaUrl && isUnusableFeedImageUrl(postFields.mediaUrl)) {
              postFields = { ...postFields, mediaUrl: null };
            }

            // RSS HTML often embeds tracking pixels as the first <img>; retry og:image after stripping them.
            if (
              !postFields.mediaUrl
              && feed.ogImageFallback !== false
              && process.env.RSS_OG_FALLBACK !== 'false'
              && postFields.sourceUrl
            ) {
              try {
                // eslint-disable-next-line no-await-in-loop
                const og = await fetchBestImageFallback(postFields.sourceUrl);
                if (og && !isUnusableFeedImageUrl(og)) {
                  postFields = { ...postFields, mediaUrl: og };
                }
              } catch { /* ignore */ }
            }

            if (postFields.mediaUrl && INGEST_REHOST_IMAGES) {
              const reh = await rehostExternalImageForIngest(postFields.mediaUrl, {
                referer: postFields.sourceUrl || feed.url || null,
              });
              if (reh.ok && reh.url) {
                postFields = {
                  ...postFields,
                  mediaUrl: reh.url,
                  mediaPublicId: reh.publicId || null,
                };
                stats.rehostOk = (stats.rehostOk || 0) + 1;
                if (reh.backend === 'local') stats.rehostLocal = (stats.rehostLocal || 0) + 1;
                if (reh.backend === 'cloudinary') stats.rehostCloudinary = (stats.rehostCloudinary || 0) + 1;
              } else if (reh.reason) {
                stats.rehostFailed = (stats.rehostFailed || 0) + 1;
              }
            }

            // Skip stories with no usable thumbnail (RSS + og:image both failed).
            if (
              process.env.RSS_REQUIRE_IMAGE === 'true'
              && (!postFields.mediaUrl || isUnusableFeedImageUrl(postFields.mediaUrl))
            ) {
              stats.skippedNoImage += 1;
              continue;
            }

            const label = `RSS · ${feed.name || 'RSS'}`;
            const { apiSourceName, ...postDocFields } = postFields;
            try {
              const created = await createNewsPost(toPostDoc(postDocFields, reporter.id, category.id, label));
              stats.inserted += 1;
              insertedThisFeed += 1;
              recordInsertedArticle(stats, created);
            } catch (error) {
              if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
                stats.duplicates += 1;
                continue;
              }
              throw error;
            }
          }

          console.log(
            `[ingest] RSS ${feedIdx}/${feeds.length} done: ${feed.name || 'RSS'} `
              + `[${String(feed.language || 'en').toLowerCase()}] `
              + `(scanned ${slice.length}, +${insertedThisFeed} new)`,
          );

          stats.sourceRuns.push({
            source: `RSS:${feed.name || 'RSS'}:${feed.categorySlug || DEFAULT_CATEGORY_SLUG}`,
            mode: 'rss',
            count: slice.length,
            success: true,
          });
        } catch (error) {
          stats.failed += 1;
          stats.sourceRuns.push({
            source: `RSS:${feed.name || 'RSS'}:${feed.categorySlug || DEFAULT_CATEGORY_SLUG}`,
            success: false,
            error: error.message,
          });
        }
      }
      try {
        await rotation.commitRotation(feedsProcessed);
      } catch (e) {
        console.warn('[ingest] RSS rotation cursor save failed:', e.message);
      }
    }

    // YouTube: optional during scraper runs (dedicated YOUTUBE_CRON handles it by default).
    const youtubeWithScraper = includeYoutube !== false
      && process.env.YOUTUBE_INGEST_WITH_SCRAPER === 'true';
    if (process.env.YOUTUBE_ENABLED !== 'false' && youtubeWithScraper) {
      try {
        budget.throwIfExpired('youtube:start');
        const yt = await runYoutubeIngestion({
          triggeredBy: `${triggeredBy}:youtube`,
          languages: activeLanguages,
        });
        if (yt?.stats) {
          stats.youtubeInserted = yt.stats.youtubeInserted || 0;
          stats.youtubeDuplicates = yt.stats.youtubeDuplicates || 0;
          stats.youtubeSkippedRestricted = yt.stats.youtubeSkippedRestricted || 0;
          stats.inserted += yt.stats.youtubeInserted || 0;
          stats.youtubeFetched = yt.stats.youtubeFetched || 0;
          if (Array.isArray(yt.stats.sourceRuns)) {
            stats.sourceRuns.push(...yt.stats.sourceRuns);
          }
        }
        if (!yt.success && !yt.skipped) {
          stats.failed += 1;
          console.warn('[ingest] YouTube ingestion failed:', yt.error);
        }
      } catch (e) {
        stats.failed += 1;
        console.warn('[ingest] YouTube ingestion error:', e?.message || e);
      }
    }

    stats.endedAt = new Date();
    if (stats.fetched === 0 && stats.inserted === 0) {
      console.warn(
        '[ingest] no articles fetched or inserted this run — typical causes: '
          + 'RSS_ENABLED=false, RSS_FEEDS_JSON=[] (now falls back to defaults), '
          + 'outbound RSS blocked on host, empty GNews/NewsAPI responses, '
          + 'or all items duplicates vs DB.',
      );
    }
    if (stats.rehostOk || stats.rehostFailed) {
      console.log(
        `[ingest] image rehost: ok=${stats.rehostOk || 0} `
          + `local=${stats.rehostLocal || 0} cloudinary=${stats.rehostCloudinary || 0} `
          + `failed=${stats.rehostFailed || 0}`,
      );
    }
    if (stats.rehostOk || stats.rehostFailed) {
      console.log(
        `[ingest] image rehost: ok=${stats.rehostOk || 0} `
          + `local=${stats.rehostLocal || 0} cloudinary=${stats.rehostCloudinary || 0} `
          + `failed=${stats.rehostFailed || 0}`,
      );
    }
    ingestState.lastSuccessAt = stats.endedAt;
    ingestState.lastSummary = stats;
    lockState.lastSuccessAt = stats.endedAt;
    lockState.lastSummary = stats;
    if (stats.inserted > 0) {
      emitFeedUpdated({
        inserted: stats.inserted,
        at: stats.endedAt,
        articles: stats.insertedArticles,
      });
    }
    return { success: true, stats };
  } catch (error) {
    ingestState.lastError = error.message;
    lockState.lastError = error.message;
    stats.endedAt = new Date();
    if (String(error.message || '').includes('time budget exceeded')) {
      stats.timedOut = true;
      console.warn('[ingest]', error.message);
    }
    return { success: false, error: error.message, stats };
  } finally {
    lockState.isRunning = false;
    if (lockKey === 'global') {
      ingestState.isRunning = false;
    }
  }
}

function getIngestionStatus() {
  return {
    global: { ...ingestState },
    byLock: Object.fromEntries(
      [...ingestStateByLock.entries()].map(([k, v]) => [k, { ...v }]),
    ),
    perLanguage: Object.fromEntries(
      INGEST_LANGS.map((lang) => [lang, { ...getIngestLockState(lang) }]),
    ),
  };
}

module.exports = {
  runIngestion,
  getIngestionStatus,
  setIngestionSocket,
  emitFeedUpdated,
  interleaveFeedsByCategory,
  interleaveFeedsByLanguageAndCategory,
  localFeedSpecificity,
  sortLocalFeedsBySpecificity,
  ingestLocationScore,
  findDuplicateForIngest,
  maybeEnrichDuplicateLocation,
};
