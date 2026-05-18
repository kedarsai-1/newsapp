const NewsPost = require('../models/NewsPost');
const {
  canonicalizeUrl,
  hashUrl,
  normalizeTitle,
  titleFingerprint,
  summaryFingerprint,
  summariesAreNearDuplicates,
} = require('../utils/storyDedupe');
const { passesIngestCategoryGate } = require('../utils/categoryRelevance');
const User = require('../models/User');
const Category = require('../models/Category');
const {
  fetchNewsApiItems,
  fetchGNewsItems,
  fetchBestImageFallback,
  isUnusableFeedImageUrl,
} = require('./newsApiService');
const { newsApiIngestPlan } = require('../config/newsApiIngestPlan');
const { cloudinary } = require('../config/cloudinary');
const { getRssFeeds } = require('../config/rssFeeds');
const {
  fetchRssItems,
  normalizeRssItem,
  resolveGoogleNewsPublisherUrl,
  summarizeInputFromItem,
  detectLanguage,
  prepareForHfSummaryFromRssItem,
  prepareForSummarization,
  summarizeForRssIngest,
  translateEnglishToFeedLanguage,
} = require('./rssService');
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
function createIngestBudget() {
  const raw = process.env.INGEST_MAX_RUNTIME_MS;
  const onRailway = Boolean(
    process.env.RAILWAY_ENVIRONMENT || process.env.RAILWAY_PROJECT_ID,
  );
  let ms;
  if (raw === undefined || raw === '') {
    ms = onRailway
      ? 6 * 60 * 1000
      : 20 * 60 * 1000; // Railway: 6 min default to avoid OOM on small instances
  } else {
    ms = Number(raw);
    if (onRailway && Number.isFinite(ms) && ms > 10 * 60 * 1000) {
      ms = 10 * 60 * 1000;
    }
  }
  if (!Number.isFinite(ms) || ms <= 0) {
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
          `[ingest] time budget exceeded (${ms}ms) at ${phase || '?'}. `
            + 'Set INGEST_MAX_RUNTIME_MS higher, or lower RSS_INSERTS_PER_FEED / RSS_SCAN_PER_FEED, '
            + 'or RSS_ENRICH_BODY=false / RSS_OG_FALLBACK=false.',
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
  return String(input || '')
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]*>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
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

function isTeluguPoliticalStory(postLike) {
  const text = stripMarkup(
    `${postLike?.title || ''} ${postLike?.summary || ''} ${postLike?.body || ''}`,
  ).toLowerCase();
  if (!text) return false;

  // Hard-negative topical filters: reject common non-political story types.
  const noisePatterns = [
    /రాశి|జాతకం|హోరోస్కోప్|వాస్తు|పూజ|దేవాలయం|ధ్యానం|ఆధ్యాత్మిక/,
    /సినిమా|మూవీ|ట్రైలర్|టీజర్|ఓటిటి|బాక్సాఫీస్|హీరో|హీరోయిన్|సెలబ్రిటీ/,
    /క్రికెట్|ఐపీఎల్|ఐపిఎల్|ఫుట్‌బాల్|కబడ్డీ|టోర్నమెంట్|మ్యాచ్|స్కోర్/,
    /హెల్త్|ఆరోగ్యం|డైట్|బ్యూటీ|రెసిపీ|లైఫ్‌స్టైల్|టిప్స్/,
    /జాబ్స్|ఉద్యోగ|ఎడ్యుకేషన్|ఎగ్జామ్|అడ్మిట్\s*కార్డ్|ఫలితాలు/,
  ];
  for (const re of noisePatterns) {
    if (re.test(text)) return false;
  }

  // Strict political scoring: require at least two independent signals.
  const partyOrLeader = [
    /\b(ysrcp|ycp|tdp|bjp|congress|janasena|jsp|b(?:rs|rs)|trs|cpi|cpm|aimim)\b/i,
    /\b(jagan|ys\s*jagan|chandrababu|lokesh|pawan\s*kalyan|revanth|modi|rahul|kcr|kavitha)\b/i,
  ];
  const institutional = [
    /ఎన్నిక|పోలింగ్|ఓటు|పార్టీ|ప్రభుత్వం|ప్రతిపక్షం|మంత్రి|మంత్రివర్గం|కేబినెట్|ఎమ్మెల్యే|ఎంపీ|ఎమ్మెల్సీ|శాసనసభ|అసెంబ్లీ|లోక్‌సభ|రాజ్యసభ|కూటమి|మానిఫెస్టో|రాజకీయ/,
    /\b(election|poll|vote|assembly|parliament|cabinet|minister|mla|mp|m[ -]?l[ -]?c|party|alliance|manifesto|politics?)\b/i,
  ];
  const apTgContext = [
    /ఆంధ్రప్రదేశ్|తెలంగాణ|అమరావతి|విజయవాడ|తాడేపల్లి|హైదరాబాద్|సచివాలయం/,
    /\b(andhra\s*pradesh|telangana|amaravati|hyderabad)\b/i,
  ];

  let score = 0;
  if (partyOrLeader.some((re) => re.test(text))) score += 1;
  if (institutional.some((re) => re.test(text))) score += 1;
  if (apTgContext.some((re) => re.test(text))) score += 1;

  return score >= 2;
}

function isHindiPoliticalStory(postLike) {
  const text = stripMarkup(
    `${postLike?.title || ''} ${postLike?.summary || ''} ${postLike?.body || ''}`,
  );
  if (!text) return false;

  const noisePatterns = [
    /राशिफल|कुंडली|ज्योतिष|वास्तु|धर्म|मंदिर|पूजा/,
    /फिल्म|मूवी|ट्रेलर|बॉक्स ऑफिस|बॉलीवुड|सेलिब्रिटी|सिनेमा/,
    /क्रिकेट|आईपीएल|फुटबॉल|मैच|स्कोर|खेल/,
    /रेसिपी|ब्यूटी|स्किनकेयर|डाइट|हेल्थ टिप्स/,
    /सोना चोरी|गोल्ड थेफ्ट|आम की कीमत|मैंगो/i,
  ];
  for (const re of noisePatterns) {
    if (re.test(text)) return false;
  }

  const partyOrLeader = [
    /\b(bjp|congress|aap|sp\b|bsp|jdu|rjd|tdp|ysrcp)\b/i,
    /\b(modi|rahul|yogi|kejriwal|akhilesh|nitish|tejashwi|shah|nadda)\b/i,
    /मोदी|राहुल|योगी|केजरीवाल|शाह|गांधी|भाजपा|कांग्रेस/,
  ];
  const institutional = [
    /\b(election|poll|vote|assembly|parliament|cabinet|minister|mla|mp|party|manifesto|politics?)\b/i,
    /चुनाव|मंत्री|सरकार|विधानसभा|लोकसभा|राज्यसभा|पार्टी|राजनीति|कैबिनेट/,
  ];
  const northContext = [
    /उत्तर प्रदेश|पंजाब|हरियाणा|राजस्थान|बिहार|दिल्ली|यूपी|यू\.पी\./,
    /\b(uttar pradesh|punjab|haryana|rajasthan|bihar|delhi|lucknow|chandigarh)\b/i,
  ];

  let score = 0;
  if (partyOrLeader.some((re) => re.test(text))) score += 1;
  if (institutional.some((re) => re.test(text))) score += 1;
  if (northContext.some((re) => re.test(text))) score += 1;
  return score >= 2;
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
      if (valid === 'international' && inferred !== 'international') return inferred;
      if (valid === 'india' && inferred === 'international') return 'international';
      if (['andhra', 'telangana', 'north'].includes(valid) && inferred !== valid) return inferred;
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

function isCloudinaryUrl(url) {
  if (!url || typeof url !== 'string') return false;
  return url.includes('res.cloudinary.com/') || url.includes('cloudinary.com/');
}

function isBlockedFetchHost(hostname) {
  const host = String(hostname || '').toLowerCase();
  if (!host || host === 'localhost' || host.endsWith('.local')) return true;
  if (host === 'metadata.google.internal') return true;
  return /^(127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(host);
}

async function rehostExternalImageToCloudinary(imageUrl, { referer } = {}) {
  if (!INGEST_REHOST_IMAGES) return { ok: false, reason: 'disabled' };
  if (!imageUrl || typeof imageUrl !== 'string') return { ok: false, reason: 'missing' };
  if (isCloudinaryUrl(imageUrl)) return { ok: true, url: imageUrl, already: true };

  let parsed;
  try {
    parsed = new URL(imageUrl.trim());
  } catch {
    return { ok: false, reason: 'invalid_url' };
  }
  if (!['http:', 'https:'].includes(parsed.protocol)) return { ok: false, reason: 'scheme' };
  if (isBlockedFetchHost(parsed.hostname)) return { ok: false, reason: 'blocked_host' };

  const ac = new AbortController();
  const to = setTimeout(() => ac.abort(), 15000);
  try {
    const headers = {
      'User-Agent':
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
      Accept: 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
    };
    if (referer && typeof referer === 'string' && referer.trim()) {
      headers.Referer = referer.trim();
      headers.Origin = referer.trim();
    }

    const res = await fetch(parsed.href, {
      redirect: 'follow',
      signal: ac.signal,
      headers,
    });
    clearTimeout(to);
    if (!res.ok) return { ok: false, reason: `http_${res.status}` };

    const ct = (res.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
    if (ct && !ct.startsWith('image/')) return { ok: false, reason: `not_image_${ct}` };

    const buf = Buffer.from(await res.arrayBuffer());
    if (!buf.length) return { ok: false, reason: 'empty' };
    if (buf.length > 5 * 1024 * 1024) return { ok: false, reason: 'too_large' };

    const ext =
      ct === 'image/png' ? 'png'
      : ct === 'image/webp' ? 'webp'
      : ct === 'image/gif' ? 'gif'
      : ct === 'image/avif' ? 'avif'
      : 'jpg';

    const dataUri = `data:${ct || 'image/jpeg'};base64,${buf.toString('base64')}`;
    const uploadTimeoutMs = Math.min(
      120000,
      Math.max(8000, Number(process.env.CLOUDINARY_UPLOAD_TIMEOUT_MS || 45000)),
    );
    const upload = await Promise.race([
      cloudinary.uploader.upload(dataUri, {
        folder: 'newsapp/external',
        resource_type: 'image',
        overwrite: false,
        unique_filename: true,
        format: ext,
      }),
      new Promise((_, rej) => {
        setTimeout(() => rej(new Error('cloudinary_upload_timeout')), uploadTimeoutMs);
      }),
    ]);
    const secure = upload?.secure_url || upload?.url;
    if (!secure) return { ok: false, reason: 'upload_failed' };
    return { ok: true, url: secure, publicId: upload.public_id };
  } catch (e) {
    clearTimeout(to);
    const msg =
      e?.message === 'cloudinary_upload_timeout'
        ? 'upload_timeout'
        : e?.name === 'AbortError'
          ? 'timeout'
          : 'fetch_failed';
    return { ok: false, reason: msg };
  }
}

async function ensureSystemReporter() {
  let reporter = await User.findOne({ email: SYSTEM_REPORTER_EMAIL });
  if (!reporter) {
    reporter = await User.create({
      name: 'News Ingestion Bot',
      email: SYSTEM_REPORTER_EMAIL,
      password: SYSTEM_REPORTER_PASSWORD,
      role: 'reporter',
      isVerified: true,
    });
  }
  return reporter;
}

async function getCategoryBySlug(slug) {
  let category = await Category.findOne({ slug: slug || DEFAULT_CATEGORY_SLUG, isActive: true });
  if (!category) {
    category = await Category.findOne({ isActive: true }).sort({ order: 1, createdAt: 1 });
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

  const canonical = canonicalizeUrl(item.sourceUrl);
  if (canonical) {
    const sourceUrlHash = hashUrl(canonical);
    if (await NewsPost.exists({ sourceUrlHash, ...langClause })) return true;
  }

  const fp = titleFingerprint(item.title);
  if (fp && await NewsPost.exists({ titleFingerprint: fp, ...langClause })) return true;

  const sumFp = summaryFingerprint(item.summary);
  if (sumFp && await NewsPost.exists({ summaryFingerprint: sumFp, ...langClause })) return true;

  const titleNorm = normalizeTitle(item.title);
  if (titleNorm.length >= 8) {
    if (await NewsPost.exists({
      titleNormalized: titleNorm,
      createdAt: { $gte: windowStart },
      ...langClause,
    })) {
      return true;
    }
  }

  const existsByExactTitle = await NewsPost.exists({
    title: item.title,
    createdAt: { $gte: windowStart },
    ...langClause,
  });
  return !!existsByExactTitle;
}

function toPostDoc(item, reporterId, categoryId, sourceName) {
  return {
    title: item.title.slice(0, 200),
    body: item.body || item.title,
    summary: item.summary,
    reporter: reporterId,
    category: categoryId,
    media: item.mediaUrl ? [{ type: 'image', url: item.mediaUrl }] : [],
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
  const t = String(text || '').replace(/\s+/g, ' ').trim();
  if (!t) return null;
  return t.length > 280 ? `${t.slice(0, 277)}...` : t;
}

function getIngestPlans() {
  if (!NEWSAPI_MULTI_CATEGORY) {
    return [{ categorySlug: DEFAULT_CATEGORY_SLUG, newsApiCategory: null }];
  }
  return newsApiIngestPlan;
}

/** Languages for API ingestion — en/te/hi by default, plus any RSS feed languages. */
function getIngestLanguages() {
  const raw = process.env.GNEWS_INGEST_LANGS?.trim() || process.env.INGEST_LANGUAGES?.trim();
  if (raw) {
    return [...new Set(
      raw
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .filter(Boolean),
    )];
  }
  const langs = new Set(['en', 'te', 'hi']);
  if (process.env.RSS_ENABLED !== 'false') {
    for (const feed of getRssFeeds()) {
      const l = String(feed.language || '').trim().toLowerCase();
      if (l) langs.add(l);
    }
  }
  return [...langs];
}

async function runIngestion({ triggeredBy = 'scheduler' } = {}) {
  if (ingestState.isRunning) {
    return {
      success: false,
      skipped: true,
      message: 'Ingestion already running.',
      state: ingestState,
    };
  }

  ingestState.isRunning = true;
  ingestState.lastRunAt = new Date();
  ingestState.lastError = null;

  const     stats = {
    triggeredBy,
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
    const budget = createIngestBudget();

    console.log(
      `[ingest] begin (${triggeredBy}) maxRuntime=${budget.describe()} `
        + `api=${Boolean(useGNews || useNewsApi)} rss=${rssEnabled}`,
    );

    if (!useGNews && !useNewsApi && !rssEnabled) {
      const msg =
        'Set GNEWS_API_KEY or NEWSAPI_KEY, or leave RSS enabled (RSS_ENABLED not false).';
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
      const ingestLanguages = getIngestLanguages();
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

              // Re-host external thumbnails on Cloudinary for reliability (no hotlink blocking).
              let postFields = item;
              let mediaUrl = item.mediaUrl;
              if (mediaUrl && isUnusableFeedImageUrl(mediaUrl)) mediaUrl = null;
              if (!mediaUrl && item.sourceUrl) {
                // eslint-disable-next-line no-await-in-loop
                mediaUrl = await fetchBestImageFallback(item.sourceUrl);
              }
              if (mediaUrl && !isUnusableFeedImageUrl(mediaUrl)) {
                const reh = await rehostExternalImageToCloudinary(mediaUrl, {
                  referer: item.sourceUrl || null,
                });
                if (reh.ok && reh.url) {
                  postFields = { ...item, mediaUrl: reh.url };
                }
              } else {
                postFields = { ...item, mediaUrl: null };
              }

              const label = `${providerLabel} · ${item.apiSourceName || 'headlines'}`;
              const { apiSourceName, ...postDocFields } = postFields;
              await NewsPost.create(toPostDoc(postDocFields, reporter._id, category._id, label));
              stats.inserted += 1;
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
      const feeds = interleaveFeedsByLanguageAndCategory(getRssFeeds());
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
          + `(scan up to ${maxScanPerFeed}, target ${targetInsertsPerFeed} new/feed, `
          + `interleaved en/hi/te then category; counts: ${JSON.stringify(langCounts)})`,
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
            // Telugu politics feeds: drop crime/lifestyle/entertainment that section RSS mislabels.
            const feedLang = String(feed.language || '').toLowerCase();
            const feedCat = String(feed.categorySlug || '').toLowerCase();
            if (
              feedLang === 'te'
              && feedCat === 'politics'
              && !isTeluguPoliticalStory(item)
            ) {
              stats.politicsFiltered += 1;
              continue;
            }
            if (
              feedLang === 'hi'
              && feedCat === 'politics'
              && !isHindiPoliticalStory(item)
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
            const prep = prepareForHfSummaryFromRssItem(raw);
            const summaryInput = prep.textForSummary;
            const originalLang = prep.originalLang;
            const fallbackSummary = String(item.summary || summarizeInputFromItem(raw)).slice(0, 150).trim();
            const budgetTight = budget.limitMs != null && budget.remainingMs() < 120_000;
            let displayTitle = item.title;
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

            let summaryPrimary = '';
            const skipAiSummary =
              budgetTight
              || fallbackSummary.length >= 120
              || process.env.RSS_SKIP_AI_SUMMARY === 'true';
            if (summaryInput && !skipAiSummary) {
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
              summary: summaryPrimary || fallbackSummary || item.summary,
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

            // RSS feeds sometimes provide only a one-line snippet.
            // Enrich short bodies from the source URL so article detail isn't one-liner.
            const shouldEnrichBody =
              !budgetTight
              && process.env.RSS_ENRICH_BODY !== 'false'
              && postFields.sourceUrl
              && String(postFields.body || '').trim().length < 260;
            if (shouldEnrichBody) {
              try {
                // eslint-disable-next-line no-await-in-loop
                const ext = await extractReadableArticle(postFields.sourceUrl, {
                  timeoutMs: Number(process.env.RSS_ENRICH_TIMEOUT_MS || 9000),
                  maxBytes: Number(process.env.RSS_ENRICH_MAX_BYTES || 900000),
                  cacheTtlMs: Number(process.env.RSS_ENRICH_CACHE_TTL_MS || 30 * 60 * 1000),
                });
                const full = String(ext?.text || '').replace(/\s+/g, ' ').trim();
                if (ext?.success && full.length > 320) {
                  let summaryAfterEnrich = (summaryPrimary && String(summaryPrimary).trim())
                    ? String(summaryPrimary).trim()
                    : null;
                  if (!summaryAfterEnrich) {
                    const chunk = full.slice(0, 1000).trim();
                    if (chunk.length >= 40) {
                      try {
                        const prepChunk = prepareForSummarization(chunk);
                        if (prepChunk.textForSummary.length >= 40) {
                          // eslint-disable-next-line no-await-in-loop
                          const s2 = await summarizeForRssIngest(
                            prepChunk.textForSummary,
                            prepChunk.originalLang,
                            feed.language || '',
                          );
                          if (s2 && String(s2).trim()) summaryAfterEnrich = String(s2).trim();
                        }
                        if (
                          (!postFields.originalLanguage || postFields.originalLanguage === 'und')
                          && prepChunk.originalLang
                          && prepChunk.originalLang !== 'und'
                        ) {
                          postFields = { ...postFields, originalLanguage: prepChunk.originalLang };
                        }
                      } catch (e) {
                        stats.fallbacks += 1;
                        console.warn(
                          `[rss] summary after enrich (${feed.name || 'RSS'}): ${e?.message || e}`,
                        );
                      }
                    }
                  }
                  if (!summaryAfterEnrich) summaryAfterEnrich = summarizeForPost(full);
                  postFields = {
                    ...postFields,
                    body: full.slice(0, 10000),
                    summary: summaryAfterEnrich,
                  };
                }
              } catch { /* ignore */ }
            }

            if (postFields.mediaUrl && isUnusableFeedImageUrl(postFields.mediaUrl)) {
              postFields = { ...postFields, mediaUrl: null };
            }

            if (postFields.mediaUrl && INGEST_REHOST_IMAGES && !budgetTight) {
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

            const label = `RSS · ${feed.name || 'RSS'}`;
            const { apiSourceName, ...postDocFields } = postFields;
            await NewsPost.create(toPostDoc(postDocFields, reporter._id, category._id, label));
            stats.inserted += 1;
            insertedThisFeed += 1;
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
    const youtubeWithScraper = process.env.YOUTUBE_INGEST_WITH_SCRAPER === 'true';
    if (process.env.YOUTUBE_ENABLED !== 'false' && youtubeWithScraper) {
      try {
        budget.throwIfExpired('youtube:start');
        const yt = await runYoutubeIngestion({ triggeredBy: `${triggeredBy}:youtube` });
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
    if (stats.inserted > 0) {
      emitFeedUpdated({
        inserted: stats.inserted,
        at: stats.endedAt,
      });
    }
    return { success: true, stats };
  } catch (error) {
    ingestState.lastError = error.message;
    stats.endedAt = new Date();
    if (String(error.message || '').includes('time budget exceeded')) {
      stats.timedOut = true;
      console.warn('[ingest]', error.message);
    }
    return { success: false, error: error.message, stats };
  } finally {
    ingestState.isRunning = false;
  }
}

function getIngestionStatus() {
  return { ...ingestState };
}

module.exports = {
  runIngestion,
  getIngestionStatus,
  setIngestionSocket,
  emitFeedUpdated,
  interleaveFeedsByCategory,
  interleaveFeedsByLanguageAndCategory,
};
