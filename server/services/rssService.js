const Parser = require('rss-parser');
const { franc } = require('franc');
const aiProvider = require('./aiProvider');
const {
  summarize: aiSummarize,
  translateToEnglish: aiTranslateToEnglish,
  translateToFeedLanguage: aiTranslateToFeedLanguage,
  isAiSummaryEnabled,
  isOllamaProvider,
} = aiProvider;

const parser = new Parser({
  timeout: 15000,
  // Capture common media fields (Google News, many publishers).
  customFields: {
    item: [
      ['media:content', 'media:content'],
      ['media:thumbnail', 'media:thumbnail'],
      ['content:encoded', 'content:encoded'],
      ['itunes:image', 'itunes:image'],
    ],
  },
  headers: {
    'User-Agent':
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    Accept: 'application/rss+xml,application/xml;q=0.9,*/*;q=0.8',
  },
});

function stripHtml(input = '') {
  return decodeHtmlEntities(
    String(input || '')
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]*>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim(),
  );
}

function decodeHtmlEntities(input = '') {
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

function summarizeLocal(text) {
  if (!text) return null;
  const t = String(text);
  return t.length > 280 ? `${t.slice(0, 277)}...` : t;
}

function summaryInputMaxChars() {
  return Math.min(
    4000,
    Math.max(400, Number(process.env.RSS_SUMMARY_INPUT_MAX_CHARS || 2000)),
  );
}

/** Join RSS/API fields and keep the longest useful plain-text block (bounded for HF). */
function collectPlainTextForSummary(...parts) {
  const maxLen = summaryInputMaxChars();
  const blocks = parts
    .map((p) => stripHtml(String(p || '')).replace(/\s+/g, ' ').trim())
    .filter((t) => t.length > 0);
  if (!blocks.length) return '';
  const merged = [...new Set(blocks)].sort((a, b) => b.length - a.length)[0];
  if (merged.length <= maxLen) return merged;
  const cut = merged.slice(0, maxLen);
  const lastSpace = cut.lastIndexOf(' ');
  if (lastSpace >= Math.floor(maxLen * 0.75)) return cut.slice(0, lastSpace).trim();
  return cut.trim();
}

function summarizeInputFromItem(item) {
  return collectPlainTextForSummary(
    item?.['content:encoded'],
    item?.content,
    item?.contentSnippet,
    item?.summary,
    item?.title,
  );
}

function looksMojibake(text) {
  const t = String(text || '');
  return (
    t.includes('\uFFFD')
    || t.includes('â€™')
    || t.includes('â€œ')
    || t.includes('â€')
    || t.includes('Ã')
  );
}

function sanitizeForSummarization(text) {
  return String(text || '')
    .replace(/â€™/g, "'")
    .replace(/â€œ|â€\x9D/g, '"')
    .replace(/â€"/g, '-')
    .replace(/Ã©/g, 'e')
    .replace(/\uFFFD/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function detectLanguage(text) {
  const lang = franc(text || '');
  return lang;
}

async function translateToEnglish(text) {
  return aiTranslateToEnglish(text);
}

async function translateEnglishToFeedLanguage(text, feedLang) {
  return aiTranslateToFeedLanguage(text, feedLang);
}

async function summarize(text, feedLang = 'en') {
  return aiSummarize(text, feedLang);
}

function extractiveSummaryNative(text, maxLen = 300) {
  const t = sanitizeForSummarization(text);
  if (!t) return '';
  if (t.length <= maxLen) return t;
  const cut = t.slice(0, maxLen);
  const sentenceEnd = /[.!?।॥\u0964\u0965\n]/;
  let best = -1;
  for (let i = Math.min(cut.length - 1, maxLen - 1); i > 80; i -= 1) {
    if (sentenceEnd.test(t[i])) {
      best = i + 1;
      break;
    }
  }
  if (best > 80) return t.slice(0, best).trim();
  const sp = cut.lastIndexOf(' ');
  if (sp > 60) return `${cut.slice(0, sp).trim()}…`;
  return `${cut.trim()}…`;
}

function clipSummarySchema(s, max = 300) {
  const x = String(s || '').replace(/\s+/g, ' ').trim();
  if (x.length <= max) return x;
  return `${x.slice(0, max - 1).trim()}…`;
}

/** Devanagari, Telugu, Tamil, etc. — if dominant, do not run English-only distilbart. */
function isPrimarilyIndicScript(text) {
  const t = String(text || '');
  const indic = (t.match(/[\u0900-\u0D7F]/g) || []).length;
  const latin = (t.match(/[A-Za-z]/g) || []).length;
  if (indic + latin === 0) return false;
  return indic / (indic + latin) >= 0.35;
}

/** Generic translation helper for UI/API use.
 * Supports target: en, hi, te. Falls back to input when unsupported/failure.
 */
async function translateTextForFeed(text, targetLanguage) {
  const raw = String(text || '').trim();
  if (!raw) return '';

  const target = String(targetLanguage || '').toLowerCase().trim();
  if (!['en', 'hi', 'te'].includes(target)) return raw;

  const detected = detectLanguage(raw.slice(0, 500));
  const looksEnglish = detected === 'eng';

  if (target === 'en') {
    return translateToEnglish(raw);
  }

  // hi/te models are most reliable from English source.
  const sourceForModel = looksEnglish ? raw : await translateToEnglish(raw);
  return translateEnglishToFeedLanguage(sourceForModel, target);
}

/** Detect language on a sample; keep text in original language (no EN translate) for summarization. */
function prepareForSummarization(strippedText) {
  const raw = String(strippedText || '').replace(/\s+/g, ' ').trim();
  if (!raw) return { textForSummary: '', originalLang: 'und' };
  const maxLen = summaryInputMaxChars();
  const limited = raw.length > maxLen ? raw.slice(0, maxLen) : raw;
  const langSample = limited.length > 800 ? limited.slice(0, 800) : limited;
  const lang = detectLanguage(langSample);
  return { textForSummary: sanitizeForSummarization(limited), originalLang: lang };
}

function prepareForHfSummaryFromRssItem(item) {
  const plain = collectPlainTextForSummary(
    item?.['content:encoded'],
    item?.content,
    item?.contentSnippet,
    item?.summary,
    item?.title,
  );
  return prepareForSummarization(plain);
}

/** Best available text from a normalized ingest item (RSS/API). */
function prepareForSummaryFromIngestItem(item = {}, rawRssItem = null) {
  const fromNormalized = collectPlainTextForSummary(item.body, item.summary, item.title);
  const fromRss = rawRssItem ? summarizeInputFromItem(rawRssItem) : '';
  const plain = fromNormalized.length >= fromRss.length ? fromNormalized : fromRss;
  return prepareForSummarization(plain);
}

/** True when franc language code is Hindi (`hin`) or Telugu (`tel`). */
function isIndicFrancLang(lang) {
  const l = String(lang || '').toLowerCase();
  return l === 'hin' || l === 'tel';
}

function isIndicAiSummaryEnabled() {
  if (process.env.RSS_INDIC_AI_SUMMARY === 'false') return false;
  return isAiSummaryEnabled();
}

/** Ollama: one multilingual call. HF: translate → EN → summarize → translate back. */
async function summarizeIndicViaEnglish(src, feedLang) {
  const raw = String(src || '').trim();
  if (!raw) return '';
  const fl = String(feedLang || 'en').toLowerCase();

  if (isOllamaProvider()) {
    try {
      const out = await aiSummarize(raw, fl);
      return out ? clipSummarySchema(out, 300) : '';
    } catch {
      return '';
    }
  }

  let en = await translateToEnglish(raw);
  en = sanitizeForSummarization(en);
  const minChars = Math.max(12, Number(process.env.RSS_SUMMARY_MIN_CHARS || 15));
  if (!en || en.length < minChars) return '';

  let summaryEn = '';
  try {
    summaryEn = await aiSummarize(en, 'en');
  } catch {
    summaryEn = '';
  }
  if (!summaryEn) return '';

  summaryEn = clipSummarySchema(summaryEn, 300);
  if (fl === 'hi' || fl === 'te') {
    try {
      const localized = await translateEnglishToFeedLanguage(summaryEn, fl);
      if (localized && localized.trim()) {
        return clipSummarySchema(localized, 300);
      }
    } catch { /* keep English summary */ }
  }
  return summaryEn;
}

/**
 * RSS ingest summarization: English → Ollama/HF in feed language, else extractive.
 * Indic (hi/te) with RSS_INDIC_AI_SUMMARY → summarizeIndicViaEnglish (Ollama: one call in
 * target language; HF: translate → EN → summarize → translate back). Always falls back to
 * extractive, then summarizeLocal. English summaries may be translated to hi/te when needed.
 */
async function summarizeForRssIngest(text, originalLang, feedLang) {
  const src = String(text || '').trim();
  const minChars = Math.max(12, Number(process.env.RSS_SUMMARY_MIN_CHARS || 15));
  if (!src || src.length < minChars) return '';
  const fl = String(feedLang || '').toLowerCase();
  const isIndicScript = isPrimarilyIndicScript(src);
  const isIndicContent = isIndicFrancLang(originalLang) || isIndicScript;

  let summary = '';

  if (originalLang === 'eng' && !isIndicScript) {
    const useAi = isOllamaProvider() || shouldUseHfSummarization(src, { language: 'en' });
    if (useAi && isAiSummaryEnabled()) {
      try {
        summary = await aiSummarize(src, fl || 'en');
      } catch {
        summary = '';
      }
    }
    if (!summary) summary = extractiveSummaryNative(src, 300);
  } else if (isIndicAiSummaryEnabled() && (isIndicContent || fl === 'hi' || fl === 'te')) {
    try {
      summary = await summarizeIndicViaEnglish(src, fl);
    } catch {
      summary = '';
    }
    if (!summary) summary = extractiveSummaryNative(src, 300);
  } else {
    summary = extractiveSummaryNative(src, 300);
  }

  if (!summary) summary = summarizeLocal(src) || '';
  summary = clipSummarySchema(summary, 300);

  if (
    (fl === 'hi' || fl === 'te')
    && originalLang === 'eng'
    && summary
    && !isIndicScript
    && !isIndicFrancLang(originalLang)
  ) {
    try {
      const tr = await translateEnglishToFeedLanguage(summary, fl);
      if (tr && tr.trim()) summary = clipSummarySchema(tr, 300);
    } catch { /* keep English */ }
  }
  return summary;
}

function shouldUseHfSummarization(text, { language } = {}) {
  const t = String(text || '').trim();
  const minChars = Math.max(12, Number(process.env.RSS_SUMMARY_MIN_CHARS || 15));
  if (!t || t.length < minChars) return false;

  // Force-enable for explicitly English feeds, then let sanitize step clean mojibake.
  if (String(language || '').toLowerCase() === 'en') return true;

  const letters = (t.match(/[A-Za-z\u0900-\u0D7F]/g) || []).length;
  if (letters === 0) return false;
  const latin = (t.match(/[A-Za-z]/g) || []).length;
  const latinRatio = latin / letters;

  // sshleifer/distilbart-cnn-12-6 is English-focused; avoid low-quality output on Indic-heavy text.
  return latinRatio >= 0.65;
}

function normalizeMediaUrl(url) {
  if (!url || typeof url !== 'string') return null;
  let u = url.trim();
  if (!u) return null;
  if (u.startsWith('//')) u = `https:${u}`;
  if (!/^https?:\/\//i.test(u)) return null;
  if (u.startsWith('http://')) u = u.replace(/^http:\/\//i, 'https://');
  return u;
}

const { isUnusableFeedImageUrl } = require('./newsApiService');

function pickImageFromItem(item) {
  const it = item || {};
  
  // Handle enclosure (standard RSS)
  const enclosure = it.enclosure?.url || it.enclosure?.link;
  
  // Handle media:content - rss-parser returns attributes in $ property
  const mediaContentRaw = it['media:content'];
  let mediaContent = null;
  if (mediaContentRaw) {
    if (mediaContentRaw.$?.url) {
      mediaContent = mediaContentRaw.$.url;
    } else if (mediaContentRaw.url) {
      mediaContent = mediaContentRaw.url;
    } else if (Array.isArray(mediaContentRaw)) {
      mediaContent = mediaContentRaw[0]?.$?.url || mediaContentRaw[0]?.url;
    }
  }
  
  // Handle media:thumbnail - same nested structure
  const mediaThumbnailRaw = it['media:thumbnail'];
  let mediaThumbnail = null;
  if (mediaThumbnailRaw) {
    if (mediaThumbnailRaw.$?.url) {
      mediaThumbnail = mediaThumbnailRaw.$.url;
    } else if (mediaThumbnailRaw.url) {
      mediaThumbnail = mediaThumbnailRaw.url;
    } else if (Array.isArray(mediaThumbnailRaw)) {
      mediaThumbnail = mediaThumbnailRaw[0]?.$?.url || mediaThumbnailRaw[0]?.url;
    }
  }
  
  // Handle itunes:image
  const itunesImg = it.itunes?.image || it['itunes:image']?.href || it['itunes:image']?.url || it['itunes:image']?.$?.href;
  
  // rss-parser top-level image (BBC and others)
  const topImage =
    (typeof it.image === 'string' ? it.image : null)
    || it.image?.url
    || it.image?.$?.url;

  // Extract from HTML content
  const html = it['content:encoded'] || it.content || it.summary || '';
  const htmlImg = (() => {
    const s = String(html || '');
    const patterns = [
      /<img[^>]+src\s*=\s*["']([^"']+)["']/i,
      /<img[^>]+data-src\s*=\s*["']([^"']+)["']/i,
      /<img[^>]+data-original\s*=\s*["']([^"']+)["']/i,
      /<img[^>]+data-lazy-src\s*=\s*["']([^"']+)["']/i,
    ];
    for (const re of patterns) {
      const m = s.match(re);
      if (m?.[1]) return m[1].trim();
    }
    return null;
  })();

  const candidates = [enclosure, mediaContent, mediaThumbnail, itunesImg, topImage, htmlImg].filter(Boolean);
  for (const c of candidates) {
    const u = normalizeMediaUrl(c);
    if (u && !isUnusableFeedImageUrl(u)) return u;
  }
  return null;
}

async function resolveGoogleNewsPublisherUrl(googleNewsUrl, { preferredHost } = {}) {
  if (!googleNewsUrl || typeof googleNewsUrl !== 'string') return null;
  const u = googleNewsUrl.trim();
  if (!u.startsWith('http')) return null;
  if (!u.includes('news.google.com')) return u;

  const ac = new AbortController();
  const to = setTimeout(() => ac.abort(), 12000);
  try {
    const res = await fetch(u, {
      redirect: 'follow',
      signal: ac.signal,
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
        Accept: 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
      },
    });
    clearTimeout(to);
    if (!res.ok) return null;
    const html = await res.text();

    // Try to find the publisher link in HTML.
    const host = preferredHost ? String(preferredHost).toLowerCase() : null;

    // Blocklist of non-article URL patterns
    const blockedUrlPatterns = [
      'w3.org', 'xmlns', 'schema.org', 'purl.org', 'xml.org',
      'ogp.me', 'opengraphprotocol', 'facebook.com/sharer',
      'twitter.com/intent', 'linkedin.com/share',
    ];

    const isLikelyArticleUrl = (x) => {
      try {
        const parsed = new URL(x);
        const h = parsed.hostname.toLowerCase();
        const full = x.toLowerCase();

        // Block XML namespaces and schema URLs
        for (const pattern of blockedUrlPatterns) {
          if (full.includes(pattern)) return false;
        }

        // Block Google-owned domains
        if (h.includes('news.google.com') || h.includes('googleusercontent.com')) return false;
        if (
          h.includes('googleapis.com')
          || h.includes('gstatic.com')
          || h.includes('googletagmanager.com')
          || h.includes('doubleclick.net')
          || h.includes('google-analytics.com')
          || h.includes('google.com')
        ) return false;

        // Block static assets
        const path = parsed.pathname.toLowerCase();
        if (path === '/css' || path === '/js' || path.startsWith('/fonts')) return false;
        if (/\.(jpg|jpeg|png|gif|webp|avif|svg|ico|css|js|json|xml|pdf|woff|woff2|ttf|eot)$/.test(path)) return false;

        // Require path to have some substance (not just root)
        if (path.length < 5) return false;

        return true;
      } catch {
        return false;
      }
    };
    const urls = Array.from(
      new Set(
        (html.match(/https?:\/\/[^\s"'<>]+/g) || [])
          .map((x) => x.replace(/&amp;/g, '&').trim())
          .filter((x) => x.length > 20 && x.length < 500), // Filter out obviously wrong URLs
      ),
    );
    if (host) {
      const hit = urls.find((x) => {
        try { return new URL(x).hostname.toLowerCase().includes(host); } catch { return false; }
      });
      if (hit && isLikelyArticleUrl(hit)) return hit;
    }
    // Fallback: first non-google URL.
    const nonGoogle = urls.find((x) => isLikelyArticleUrl(x));
    return nonGoogle || null;
  } catch {
    clearTimeout(to);
    return null;
  }
}

async function fetchRssItems(feedUrl) {
  const parsed = await parser.parseURL(feedUrl);
  const items = parsed.items || [];
  items.sort((a, b) => {
    const ta = new Date(a.isoDate || a.pubDate || 0).getTime();
    const tb = new Date(b.isoDate || b.pubDate || 0).getTime();
    return tb - ta;
  });
  return items;
}

/**
 * Normalize RSS item → ingestion service item format.
 * @param {object} item rss-parser item
 * @param {object} feedCfg { name, url, categorySlug, language }
 */
function normalizeRssItem(item, feedCfg, { sourceUrlOverride } = {}) {
  const title = stripHtml(item.title || '').slice(0, 200);
  const link = sourceUrlOverride || item.link || item.guid || null;
  const rawBody = item.content || item['content:encoded'] || item.contentSnippet || item.summary || '';
  const body = (stripHtml(rawBody) || title).slice(0, 10000);
  const publishedAt = item.isoDate || item.pubDate || null;
  const img = pickImageFromItem(item);

  return {
    title,
    body,
    summary: summarizeLocal(stripHtml(item.contentSnippet || item.summary || rawBody)),
    mediaUrl: img,
    tags: [],
    sourceUrl: link,
    sourcePublishedAt: publishedAt,
    sourceType: 'rss',
    language: (feedCfg.language || 'en').toLowerCase(),
    scrapeConfidence: img ? 0.85 : 0.75,
    apiSourceName: feedCfg.name || 'RSS',
  };
}

module.exports = {
  fetchRssItems,
  normalizeRssItem,
  resolveGoogleNewsPublisherUrl,
  summarize,
  summarizeInputFromItem,
  shouldUseHfSummarization,
  detectLanguage,
  translateToEnglish,
  prepareForSummarization,
  prepareForHfSummaryFromRssItem,
  prepareForSummaryFromIngestItem,
  collectPlainTextForSummary,
  summaryInputMaxChars,
  summarizeForRssIngest,
  summarizeIndicViaEnglish,
  isIndicAiSummaryEnabled,
  isIndicFrancLang,
  isPrimarilyIndicScript,
  translateEnglishToFeedLanguage,
  translateTextForFeed,
  extractiveSummaryNative,
};

