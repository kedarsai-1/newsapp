const Parser = require('rss-parser');
const { franc } = require('franc');

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

function summarizeInputFromItem(item) {
  const raw = stripHtml(item?.content || item?.['content:encoded'] || item?.contentSnippet || item?.summary || '');
  if (!raw) return '';
  // Keep payload bounded for model latency/cost and to satisfy pipeline requirement.
  const maxLen = 1000;
  const minLen = 800;
  if (raw.length <= maxLen) return raw;
  const cut = raw.slice(0, maxLen);
  const lastSpace = cut.lastIndexOf(' ');
  if (lastSpace >= minLen) return cut.slice(0, lastSpace).trim();
  return cut.trim();
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

function parseHfTranslationJson(result) {
  if (result == null) return '';
  if (typeof result === 'string') return result.trim();
  if (Array.isArray(result)) {
    const first = result[0];
    if (first && typeof first === 'object' && first.translation_text != null) {
      return String(first.translation_text).trim();
    }
  }
  if (typeof result === 'object' && result.translation_text != null) {
    return String(result.translation_text).trim();
  }
  return '';
}

async function translateToEnglish(text) {
  const token = String(process.env.HF_TOKEN || '').trim();
  if (!token) return String(text || '');
  const input = String(text || '').slice(0, 800);
  if (!input.trim()) return '';
  try {
    const response = await fetch(
      'https://router.huggingface.co/hf-inference/models/Helsinki-NLP/opus-mt-mul-en',
      {
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        method: 'POST',
        body: JSON.stringify({ inputs: input }),
      },
    );
    if (!response.ok) throw new Error(`HF translate ${response.status}`);
    const result = await response.json();
    const out = parseHfTranslationJson(result);
    return out || text;
  } catch {
    return String(text || '');
  }
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

async function hfMarianTranslate(text, model, token) {
  const input = String(text || '').trim().slice(0, 600);
  if (!input) return '';
  const response = await fetch(
    `https://router.huggingface.co/hf-inference/models/${model}`,
    {
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      method: 'POST',
      body: JSON.stringify({ inputs: input }),
    },
  );
  if (!response.ok) throw new Error(String(response.status));
  const result = await response.json();
  return parseHfTranslationJson(result) || '';
}

async function hfNllbToTelugu(text, token) {
  const input = String(text || '').trim().slice(0, 512);
  if (!input) return '';
  const response = await fetch(
    'https://router.huggingface.co/hf-inference/models/facebook/nllb-200-distilled-600M',
    {
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      method: 'POST',
      body: JSON.stringify({
        inputs: input,
        parameters: { src_lang: 'eng_Latn', tgt_lang: 'tel_Telu' },
      }),
    },
  );
  if (!response.ok) throw new Error(String(response.status));
  const result = await response.json();
  return parseHfTranslationJson(result) || '';
}

/**
 * When the RSS feed is tagged hi/te but the article text is English, localize summary/title for display.
 */
async function translateEnglishToFeedLanguage(text, feedLang) {
  const raw = String(text || '').trim();
  if (!raw) return '';
  const token = String(process.env.HF_TOKEN || '').trim();
  if (!token) return raw;
  const code = String(feedLang || '').toLowerCase();
  try {
    if (code === 'hi') {
      const out = await hfMarianTranslate(raw, 'Helsinki-NLP/opus-mt-en-hi', token);
      return out || raw;
    }
    if (code === 'te') {
      const out = await hfNllbToTelugu(raw, token);
      return out || raw;
    }
  } catch {
    return raw;
  }
  return raw;
}

/**
 * Generic translation helper for UI/API use.
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

/** Detect language on first 800 chars; keep text in original language (no EN translate) for summarization. */
function prepareForSummarization(strippedText) {
  const raw = String(strippedText || '').replace(/\s+/g, ' ').trim();
  if (!raw) return { textForSummary: '', originalLang: 'und' };
  const limited = raw.length > 800 ? raw.slice(0, 800) : raw;
  const lang = detectLanguage(limited);
  return { textForSummary: sanitizeForSummarization(limited), originalLang: lang };
}

function prepareForHfSummaryFromRssItem(item) {
  const plain = stripHtml(
    item?.contentSnippet || item?.content || item?.['content:encoded'] || item?.summary || '',
  );
  return prepareForSummarization(plain);
}

/**
 * English → HF abstractive summary; Indic/other → extractive summary in the original script.
 * If feed is hi/te but franc says English, translate summary to that language.
 */
async function summarizeForRssIngest(text, originalLang, feedLang) {
  const src = String(text || '').trim();
  if (!src || src.length < 40) return '';
  const fl = String(feedLang || '').toLowerCase();
  const forceNativeForIndicFeed =
    (fl === 'te' || fl === 'hi') && isPrimarilyIndicScript(src);

  let summary = '';
  if (originalLang === 'eng' && !forceNativeForIndicFeed) {
    if (shouldUseHfSummarization(src, { language: 'en' })) {
      try {
        summary = await summarize(src);
      } catch {
        summary = '';
      }
    }
    if (!summary) summary = extractiveSummaryNative(src, 300);
  } else {
    summary = extractiveSummaryNative(src, 300);
  }
  if (!summary) summary = summarizeLocal(src) || '';
  summary = clipSummarySchema(summary, 300);

  if ((fl === 'hi' || fl === 'te') && originalLang === 'eng' && summary && !forceNativeForIndicFeed) {
    try {
      const tr = await translateEnglishToFeedLanguage(summary, fl);
      if (tr && tr.trim()) summary = clipSummarySchema(tr, 300);
    } catch { /* keep English */ }
  }
  return summary;
}

function shouldUseHfSummarization(text, { language } = {}) {
  const t = String(text || '').trim();
  if (!t || t.length < 40) return false;

  // Force-enable for explicitly English feeds, then let sanitize step clean mojibake.
  if (String(language || '').toLowerCase() === 'en') return true;

  const letters = (t.match(/[A-Za-z\u0900-\u0D7F]/g) || []).length;
  if (letters === 0) return false;
  const latin = (t.match(/[A-Za-z]/g) || []).length;
  const latinRatio = latin / letters;

  // sshleifer/distilbart-cnn-12-6 is English-focused; avoid low-quality output on Indic-heavy text.
  return latinRatio >= 0.65;
}

function parseHfSummarizationJson(result) {
  if (result == null) return '';
  if (typeof result === 'string') return result.trim();
  if (Array.isArray(result)) {
    const first = result[0];
    if (first && typeof first === 'object' && first.summary_text != null) {
      return String(first.summary_text).trim();
    }
  }
  if (typeof result === 'object' && result.summary_text != null) {
    return String(result.summary_text).trim();
  }
  return '';
}

async function summarize(text) {
  const input = sanitizeForSummarization(text);
  if (!input) return '';
  const token = String(process.env.HF_TOKEN || '').trim();
  if (!token) {
    throw new Error('HF_TOKEN is missing');
  }
  try {
    const response = await fetch(
      'https://router.huggingface.co/hf-inference/models/sshleifer/distilbart-cnn-12-6',
      {
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        method: 'POST',
        body: JSON.stringify({ inputs: input }),
      },
    );
    if (!response.ok) {
      const body = await response.text().catch(() => '');
      const detail = body ? ` - ${body.slice(0, 240)}` : '';
      throw new Error(`HF ${response.status}${detail}`);
    }
    const result = await response.json();
    const out = parseHfSummarizationJson(result);
    if (!out || looksMojibake(out)) return '';
    return out;
  } catch (e) {
    throw new Error(`HuggingFace summarization failed: ${e.message || e}`);
  }
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
  
  // Extract from HTML content
  const html = it['content:encoded'] || it.content || '';
  const htmlImg = (() => {
    const s = String(html || '');
    const m =
      s.match(/<img[^>]+src\s*=\s*["']([^"']+)["']/i)
      || s.match(/<img[^>]+data-src\s*=\s*["']([^"']+)["']/i);
    return m && m[1] ? m[1].trim() : null;
  })();

  const candidates = [enclosure, mediaContent, mediaThumbnail, itunesImg, htmlImg].filter(Boolean);
  for (const c of candidates) {
    const u = normalizeMediaUrl(c);
    if (u) return u;
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
  summarizeForRssIngest,
  translateEnglishToFeedLanguage,
  translateTextForFeed,
  extractiveSummaryNative,
};

