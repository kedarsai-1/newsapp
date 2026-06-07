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
const { acceptPoliticsRssItem } = require('../utils/politicalStoryFilter');
const { passesIngestCategoryGate } = require('../utils/categoryRelevance');
const { createNewsPost } = require('../utils/prismaNewsPost');
const {
  fetchNewsApiItems,
  fetchGNewsItems,
  fetchBestImageFallback,
  isUnusableFeedImageUrl,
} = require('./newsApiService');
const { newsApiIngestPlan } = require('../config/newsApiIngestPlan');
const { rehostExternalImageToCloudinary } = require('../utils/rehostExternalImage');
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
  translateEnglishToFeedLanguage,
} = require('./rssService');
const { isOllamaProvider } = require('./aiProvider');
const { extractReadableArticle } = require('./articleExtractionService');
const { classifyArticleConstituency } = require('./constituencyClassifierService');
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

/** Round-robin across categorySlug so politics/sports/business all get processed each run. */
function interleaveFeedsByCategory(feeds) {
  const buckets = new Map();
  for (const f of feeds) {
    if (!f?.url) continue;
    const key = String(f.categorySlug || 'general').toLowerCase();
    if (!buckets.has(key)) buckets.set(key, []);
    buckets.get(key).push(f);
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
  const valid = ['all', 'andhra', 'telangana', 'india', 'international', 'north', 'states', 'delhi'].includes(s)
    ? s
    : null;

  if (feedCat !== 'politics' && feedCat !== 'local') return null;

  const inferred = inferPoliticsScopeFromStory(item, null);

  if (feedCat === 'politics') {
    if (valid && valid !== 'all') {
      if (inferred && ['andhra', 'telangana', 'north', 'international'].includes(inferred)) {
        return inferred;
      }
      if (valid === 'international' && inferred !== 'international') return inferred;
      if (valid === 'india' && inferred === 'international') return 'international';
      return valid;
    }
    return inferred || 'india';
  }

  if (feedCat === 'local' && ['andhra', 'telangana', 'north', 'states', 'delhi'].includes(s)) return s;
  if (feedCat === 'local' && (feedLang === 'te' || feedLang === 'hi')) {
    return inferPoliticsScopeFromStory(item, s);
  }
  return null;
}

/** Infer india vs international vs AP/TG from story text when feed scope is broad. */
function inferPoliticsScopeFromStory(postLike, feedScope) {
  const fromFeed = String(feedScope || '').toLowerCase();
  if (['andhra', 'telangana', 'north', 'states', 'delhi'].includes(fromFeed)) {
    return fromFeed;
  }
  const text = stripMarkup(
    `${postLike?.title || ''} ${postLike?.summary || ''} ${postLike?.body || ''}`,
  );
  if (/(ఆంధ్ర|andhra\s*pradesh|amaravati|vijayawada|visakhapatnam|guntur|nellore)/i.test(text)) {
    return 'andhra';
  }
  if (/(తెలంగాణ|telangana|hyderabad|warangal|karimnagar|secunderabad)/i.test(text)) {
    return 'telangana';
  }
  if (
    /(उत्तर प्रदेश|पंजाब|हरियाणा|राजस्थान|बिहार|दिल्ली|यूपी)/.test(text)
    || /\b(uttar pradesh|punjab|haryana|rajasthan|bihar|lucknow|chandigarh|noida|ghaziabad)\b/i.test(text)
  ) {
    return 'north';
  }
  if (/\b(trump|biden|putin|ukraine|gaza|united nations|white house|nato|european union)\b/i.test(text)
    || /(ट्रंप|बाइडेन|अमेरिका|पाकिस्तान|चीन|यूक्रेन|गाजा|विदेश|अंतर्राष्ट्रीय)/.test(text)
    || /(అమెరికా|అమెరిక|బైడెన్|ట్రంప్|పాకిస్తాన్|చైనా|రష్యా|యుద్ధం|విదేశ)/i.test(text)) {
    return 'international';
  }
  if (
    /\b(modi|rahul|parliament|lok sabha|rajya sabha|bjp|congress|delhi|centre|central government)\b/i.test(text)
    || /(మోదీ|రాహుల్|కేంద్ర|లోక్‌సభ|రాజ్యసభ|ఢిల్లీ|జాతీయ)/i.test(text)
    || /(मोदी|राहुल|संसद|लोकसभा|राज्यसभा|केंद्र|दिल्ली|जातीय)/.test(text)
  ) {
    return 'india';
  }
  return 'india';
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

async function isDuplicate(item) {
  const windowStart = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const lang = String(item.language || 'en').toLowerCase();
  const langClause = lang && lang !== 'all' ? { language: lang } : {};

  const orClauses = [];

  const canonical = canonicalizeUrl(item.sourceUrl);
  if (canonical) {
    const sourceUrlHash = hashUrl(canonical);
    orClauses.push({ sourceUrlHash });
  }

  const fp = titleFingerprint(item.title);
  if (fp) {
    orClauses.push({ titleFingerprint: fp });
  }

  const sumFp = summaryFingerprint(item.summary);
  if (sumFp) {
    orClauses.push({ summaryFingerprint: sumFp });
  }

  const titleNorm = normalizeTitle(item.title);
  if (titleNorm.length >= 8) {
    orClauses.push({
      titleNormalized: titleNorm,
      createdAt: { gte: windowStart },
    });
  }

  if (orClauses.length === 0) return false;

  const duplicate = await prisma.newsPost.findFirst({
    where: {
      ...langClause,
      OR: orClauses,
    },
    select: { id: true },
  });

  return !!duplicate;
}

function toPostDoc(item, reporterId, categoryId, sourceName) {
  return {
    title: item.title.slice(0, 200),
    body: item.body || item.title,
    summary: item.summary,
    reporterId,
    categoryId,
    media: item.mediaUrl ? [{ type: 'image', url: item.mediaUrl }] : [],
    status: SCRAPER_AUTO_APPROVE ? 'approved' : 'pending',
    approvedAt: SCRAPER_AUTO_APPROVE ? new Date() : null,
    tags: item.tags || [],
    language: (() => {
      let l = item.language || 'en';
      if (l === 'en') {
        const titleStr = item.title || '';
        if (/[\u0900-\u097F]/.test(titleStr)) return 'hi';
        if (/[\u0C00-\u0C7F]/.test(titleStr)) return 'te';
      }
      return l;
    })(),
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
    politicsScope: ['all', 'andhra', 'telangana', 'india', 'international'].includes(String(item.politicsScope || '').toLowerCase())
      ? String(item.politicsScope).toLowerCase()
      : null,
    constituency: item.constituency || 'Unknown',
    entities: Array.isArray(item.entities) ? item.entities : [],
    scrapedAt: new Date(),
    scrapeConfidence: item.scrapeConfidence,
  };
}

function summarizeForPost(text) {
  const t = decodeHtmlEntities(String(text || ''));
  if (!t) return null;
  if (t.length <= 300) return t;
  // Try to truncate at last sentence boundary within 300 chars
  const slice = t.slice(0, 300);
  const lastSentEnd = Math.max(
    slice.lastIndexOf('. '),
    slice.lastIndexOf('। '),
    slice.lastIndexOf('? '),
    slice.lastIndexOf('! '),
  );
  if (lastSentEnd > 80) return slice.slice(0, lastSentEnd + 1).trim();
  return `${slice.slice(0, 297).trim()}…`;
}

/** AI/extractive summary for ingest; respects budget and RSS_SKIP_AI_SUMMARY only. */
async function summarizeIngestItem({
  item,
  rawRssItem = null,
  feedLang = 'en',
  budget = null,
}) {
  if (process.env.RSS_SKIP_AI_SUMMARY === 'true') return '';
  if (budget?.limitMs != null && budget.remainingMs() < 45_000) return '';
  const prep = prepareForSummaryFromIngestItem(item, rawRssItem);
  if (!prep.textForSummary) return '';
  try {
    return await summarizeForRssIngest(
      prep.textForSummary,
      prep.originalLang,
      feedLang,
    );
  } catch {
    return '';
  }
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
                  const reh = await rehostExternalImageToCloudinary(mediaUrl, {
                    referer: item.sourceUrl || null,
                  });
                  if (reh.ok && reh.url) {
                    postFields = { ...postFields, mediaUrl: reh.url };
                  }
                }
              } else {
                postFields = { ...item, summary: apiSummary, mediaUrl: null };
              }

              const label = item.apiSourceName || providerLabel || 'headlines';
              const { apiSourceName, ...postDocFields } = postFields;
              try {
                await createNewsPost(toPostDoc(postDocFields, reporter.id, category.id, label));
                stats.inserted += 1;
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
      const rssSource = getRssFeeds({ languages: activeLanguages });
      const feeds = activeLanguages.length === 1
        ? interleaveFeedsByCategory(rssSource)
        : interleaveFeedsByLanguageAndCategory(rssSource);
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
      for (const feed of feeds) {
        feedIdx += 1;
        budget.throwIfExpired(`rss:feed-start:${feedIdx}/${feeds.length}`);
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
          const slice = items.slice(0, maxScanPerFeed);
          stats.fetched += slice.length;
          let insertedThisFeed = 0;

          for (let ri = 0; ri < slice.length; ri++) {
            if (insertedThisFeed >= targetInsertsPerFeed) break;
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
              const maxAgeDays = String(feed.categorySlug || '').toLowerCase() === 'politics'
                ? (String(feed.language || '').toLowerCase() === 'te' ? 21 : 12)
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
            const prep = prepareForSummaryFromIngestItem(item, raw);
            const summaryInput = prep.textForSummary;
            const originalLang = prep.originalLang;
            const decodedBody = decodeHtmlEntities(
              collectPlainTextForSummary(item.body, summarizeInputFromItem(raw), item.title),
            );
            const fallbackSummary = summarizeForPost(decodedBody)
              || summarizeForPost(decodeHtmlEntities(String(item.summary || '').trim()));

            let summaryPrimary = '';
            const ollamaSummary = isOllamaProvider();
            const budgetTight = budget.limitMs != null
              && budget.remainingMs() < (ollamaSummary ? 90_000 : 45_000);
            let displayTitle = decodeHtmlEntities(String(item.title || '')).slice(0, 200);
            if (
              ['hi', 'te'].includes(String(feed.language || '').toLowerCase())
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

            if (summaryInput && process.env.RSS_SKIP_AI_SUMMARY !== 'true' && !budgetTight) {
              try {
                // eslint-disable-next-line no-await-in-loop
                summaryPrimary = await summarizeForRssIngest(
                  summaryInput,
                  originalLang,
                  feed.language || '',
                );
              } catch (e) {
                summaryPrimary = '';
                stats.fallbacks += 1;
                console.warn(
                  `[rss] summary fallback (${feed.name || 'RSS'}): ${e?.message || e}`,
                );
              }
            }

            let postFields = {
              ...item,
              title: displayTitle,
              body: decodedBody.slice(0, 10000) || displayTitle,
              summary: decodeHtmlEntities(summaryPrimary || fallbackSummary || item.summary || '')
                || fallbackSummary
                || summarizeForPost(decodedBody),
              originalLanguage: originalLang,
              politicsScope: resolvePoliticsScope(item, feed),
            };
            if (feedLang === 'te' && (feedCat === 'local' || feedCat === 'politics')) {
              const constituencyResult = await classifyArticleConstituency(raw);
              postFields = {
                ...postFields,
                constituency: constituencyResult.constituency || 'Unknown',
                entities: Array.isArray(constituencyResult.entities)
                  ? constituencyResult.entities
                  : [],
              };
            }

            // Google News RSS items often point to news.google.com redirect pages.
            // Resolve to the real publisher URL so:
            // - thumbnails come from the publisher (not Google News logo)
            // - full-article extraction works reliably
            if (
              feed.resolvePublisherUrl
              && postFields.sourceUrl
              && String(postFields.sourceUrl).includes('news.google.com')
            ) {
              try {
                // eslint-disable-next-line no-await-in-loop
                const resolved = await resolveGoogleNewsPublisherUrl(postFields.sourceUrl, {
                  preferredHost: feed.preferredHost || null,
                });
                if (resolved) {
                  postFields = { ...postFields, sourceUrl: resolved };
                }
              } catch { /* ignore */ }
            }

            // Dedupe after publisher URL resolution (Google News links differ per feed).
            // eslint-disable-next-line no-await-in-loop
            if (await isDuplicate(postFields)) {
              stats.duplicates += 1;
              continue;
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
                const full = String(ext?.text || '').replace(/\s+/g, ' ').trim();
                if (ext?.success && full.length >= 80) {
                  let summaryAfterEnrich = '';
                  if (process.env.RSS_SKIP_AI_SUMMARY !== 'true' && !budgetTight) {
                    try {
                      const prepFull = prepareForSummarization(full);
                      if (prepFull.textForSummary) {
                        // eslint-disable-next-line no-await-in-loop
                        summaryAfterEnrich = await summarizeForRssIngest(
                          prepFull.textForSummary,
                          prepFull.originalLang,
                          feed.language || '',
                        );
                      }
                      if (
                        (!postFields.originalLanguage || postFields.originalLanguage === 'und')
                        && prepFull.originalLang
                        && prepFull.originalLang !== 'und'
                      ) {
                        postFields = { ...postFields, originalLanguage: prepFull.originalLang };
                      }
                    } catch (e) {
                      stats.fallbacks += 1;
                      console.warn(
                        `[rss] summary after enrich (${feed.name || 'RSS'}): ${e?.message || e}`,
                      );
                    }
                  }
                  if (!summaryAfterEnrich || !String(summaryAfterEnrich).trim()) {
                    summaryAfterEnrich =
                      (summaryPrimary && String(summaryPrimary).trim())
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

            if (postFields.mediaUrl && INGEST_REHOST_IMAGES) {
              const reh = await rehostExternalImageToCloudinary(postFields.mediaUrl, {
                referer: postFields.sourceUrl || feed.url || null,
              });
              if (reh.ok && reh.url) {
                postFields = { ...postFields, mediaUrl: reh.url };
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

            const label = postFields.apiSourceName || feed.name || 'RSS';
            const { apiSourceName, ...postDocFields } = postFields;
            try {
              await createNewsPost(toPostDoc(postDocFields, reporter.id, category.id, label));
              stats.inserted += 1;
              insertedThisFeed += 1;
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
    ingestState.lastSuccessAt = stats.endedAt;
    ingestState.lastSummary = stats;
    lockState.lastSuccessAt = stats.endedAt;
    lockState.lastSummary = stats;
    if (stats.inserted > 0) {
      emitFeedUpdated({
        inserted: stats.inserted,
        at: stats.endedAt,
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
};
