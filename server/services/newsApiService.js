/**
 * External news APIs for ingestion:
 * - GNews (preferred if GNEWS_API_KEY is set): https://gnews.io/docs/v4
 * - NewsAPI.org (fallback): https://newsapi.org/docs — set NEWSAPI_KEY
 */

const { stripNewsWireTruncationMarkers } = require('../utils/stripNewsWireTruncation');

function stripHtml(input = '') {
  return String(input || '').replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}

function summarize(text) {
  if (!text) return null;
  const cleaned = stripNewsWireTruncationMarkers(text);
  return cleaned.length > 280 ? `${cleaned.slice(0, 277)}...` : cleaned;
}

/** Plain text from API fields: HTML stripped, wire truncation markers removed. */
function normalizeWireText(...parts) {
  const joined = parts.filter(Boolean).join('\n\n');
  return stripNewsWireTruncationMarkers(stripHtml(joined));
}

/**
 * NewsAPI often returns `description` as the opening of `content`; joining both repeats
 * the first paragraph. Prefer a single block when content already starts with description.
 */
function mergeDescriptionAndContent(description, content) {
  const desc = stripNewsWireTruncationMarkers(stripHtml(description || ''));
  const cont = stripNewsWireTruncationMarkers(stripHtml(content || ''));
  if (!cont) return desc;
  if (!desc) return cont;
  const d = desc.trim();
  const c = cont.trim();
  if (d.length > 0 && (c.startsWith(d) || c.startsWith(`${d}\n`) || c.startsWith(`${d} `))) {
    return c;
  }
  return `${d}\n\n${c}`.trim();
}

/** Many CDNs return http URLs; mobile apps prefer https. */
function normalizeMediaUrl(url) {
  if (!url || typeof url !== 'string') return null;
  let u = url.trim();
  if (!u) return null;
  if (u.startsWith('//')) u = `https:${u}`;
  if (!/^https?:\/\//i.test(u)) return null;
  if (u.startsWith('http://')) u = u.replace(/^http:\/\//i, 'https://');
  return u;
}

function isBlockedFetchHost(hostname) {
  const host = String(hostname || '').toLowerCase();
  if (!host || host === 'localhost' || host.endsWith('.local')) return true;
  if (host === 'metadata.google.internal') return true;
  return /^(127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(host);
}

function isGoogleNewsLogoUrl(url) {
  if (!url || typeof url !== 'string') return false;
  const u = url.toLowerCase();
  // Common Google News / Google favicon / logo assets that appear as og:image.
  return (
    u.includes('news.google.com')
    || u.includes('gstatic.com')
    || u.includes('googleusercontent.com')
    || u.includes('/favicon')
    || u.includes('google')
      && (u.includes('logo') || u.includes('google_g'))
  );
}

/** First og:image / twitter:image from HTML head (NewsAPI often omits urlToImage). */
function parseOgImageFromHtml(html) {
  const s = String(html || '');
  const patterns = [
    /<meta[^>]+property\s*=\s*["']og:image["'][^>]*content\s*=\s*["']([^"']+)["']/i,
    /<meta[^>]+content\s*=\s*["']([^"']+)["'][^>]*property\s*=\s*["']og:image["']/i,
    /<meta[^>]+name\s*=\s*["']twitter:image["'][^>]*content\s*=\s*["']([^"']+)["']/i,
    /<meta[^>]+content\s*=\s*["']([^"']+)["'][^>]*name\s*=\s*["']twitter:image["']/i,
    /<meta[^>]+name\s*=\s*["']twitter:image:src["'][^>]*content\s*=\s*["']([^"']+)["']/i,
  ];
  for (const re of patterns) {
    const m = s.match(re);
    if (m && m[1]) {
      return m[1]
        .trim()
        .replace(/&amp;/gi, '&')
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'");
    }
  }
  return null;
}

function decodeHtmlEntities(input) {
  return String(input || '')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>');
}

function absoluteUrl(raw, baseUrl) {
  if (!raw) return null;
  const v = decodeHtmlEntities(String(raw).trim());
  if (!v || v.startsWith('data:') || v.startsWith('blob:')) return null;
  try {
    return new URL(v, baseUrl).toString();
  } catch {
    return null;
  }
}

function looksLikeDecorativeImage(url) {
  const u = String(url || '').toLowerCase();
  if (!u) return true;
  if (u.includes('logo') || u.includes('favicon') || u.includes('sprite') || u.includes('icon')) return true;
  if (u.includes('og-image') || u.includes('/theme/images/')) return true;
  if (u.includes('1x1') || u.includes('pixel') || u.includes('placeholder') || u.includes('default')) return true;
  if (u.includes('avatar') || u.includes('profile') || u.includes('thumbnail-default')) return true;
  if (u.endsWith('.svg') || u.includes('.svg?') || u.endsWith('.ico') || u.includes('.ico?')) return true;
  // Check for small dimension indicators in URL (e.g., 180x180, 64x64)
  const sizeMatch = u.match(/[/_-](\d{2,3})x(\d{2,3})[/_.-]/);
  if (sizeMatch) {
    const w = parseInt(sizeMatch[1], 10);
    const h = parseInt(sizeMatch[2], 10);
    if (w > 0 && h > 0 && w <= 256 && h <= 256) return true;
  }
  return false;
}

function parseFirstContentImageFromHtml(html, pageUrl) {
  const s = String(html || '');
  const candidates = [];

  // JSON-LD image fields
  for (const m of s.matchAll(/"image"\s*:\s*"([^"]+)"/gi)) {
    if (m && m[1]) candidates.push(m[1]);
  }

  // itemprop image links
  for (const m of s.matchAll(/<meta[^>]+itemprop\s*=\s*["']image["'][^>]*content\s*=\s*["']([^"']+)["']/gi)) {
    if (m && m[1]) candidates.push(m[1]);
  }

  // img src / lazy attrs
  for (const m of s.matchAll(/<img[^>]+(?:src|data-src|data-original|data-lazy-src)\s*=\s*["']([^"']+)["'][^>]*>/gi)) {
    if (m && m[1]) candidates.push(m[1]);
  }

  // img srcset (first candidate in srcset list)
  for (const m of s.matchAll(/<img[^>]+srcset\s*=\s*["']([^"']+)["'][^>]*>/gi)) {
    if (m && m[1]) {
      const first = m[1].split(',')[0]?.trim()?.split(/\s+/)[0];
      if (first) candidates.push(first);
    }
  }

  for (const c of candidates) {
    const abs = absoluteUrl(c, pageUrl);
    const norm = normalizeMediaUrl(abs);
    if (!norm) continue;
    if (looksLikeDecorativeImage(norm)) continue;
    if (isGoogleNewsLogoUrl(norm)) continue;
    return norm;
  }
  return null;
}

/**
 * When NewsAPI does not provide urlToImage, load the article HTML and read og:image.
 * Set NEWSAPI_OG_FALLBACK=false to skip (saves latency on ingest).
 */
async function fetchOgImageFallback(pageUrl) {
  if (process.env.NEWSAPI_OG_FALLBACK === 'false') return null;
  if (!pageUrl || typeof pageUrl !== 'string') return null;
  let parsed;
  try {
    parsed = new URL(pageUrl.trim());
  } catch {
    return null;
  }
  if (!['http:', 'https:'].includes(parsed.protocol)) return null;
  if (isBlockedFetchHost(parsed.hostname)) return null;

  const ac = new AbortController();
  const to = setTimeout(() => ac.abort(), 12000);
  try {
    const upstream = await fetch(parsed.href, {
      redirect: 'follow',
      signal: ac.signal,
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
        Accept: 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
      },
    });
    clearTimeout(to);
    if (!upstream.ok) return null;
    const ct = (upstream.headers.get('content-type') || '').toLowerCase();
    if (ct && !ct.includes('text/html') && !ct.includes('application/xhtml')) {
      return null;
    }
    const buf = Buffer.from(await upstream.arrayBuffer());
    // Google News pages are very large; allow a bigger head slice so og:image can be found.
    const max = parsed.hostname.toLowerCase().includes('news.google.com')
      ? 1400 * 1024
      : 450 * 1024;
    const slice = buf.length > max ? buf.subarray(0, max) : buf;
    const html = slice.toString('utf8');
    const raw = parseOgImageFromHtml(html);
    const normalized = normalizeMediaUrl(absoluteUrl(raw, parsed.href));
    if (!normalized) return null;
    // Avoid using Google News logo/favicons as thumbnails.
    if (parsed.hostname.toLowerCase().includes('news.google.com') && isGoogleNewsLogoUrl(normalized)) {
      return null;
    }
    if (looksLikeDecorativeImage(normalized)) return null;
    return normalized;
  } catch {
    clearTimeout(to);
    return null;
  }
}

/** Best-effort image picker: og/twitter first, then first meaningful content image. */
async function fetchBestImageFallback(pageUrl) {
  const og = await fetchOgImageFallback(pageUrl);
  if (og) return og;
  if (!pageUrl || typeof pageUrl !== 'string') return null;
  let parsed;
  try {
    parsed = new URL(pageUrl.trim());
  } catch {
    return null;
  }
  if (!['http:', 'https:'].includes(parsed.protocol)) return null;
  if (isBlockedFetchHost(parsed.hostname)) return null;

  const ac = new AbortController();
  const to = setTimeout(() => ac.abort(), 12000);
  try {
    const upstream = await fetch(parsed.href, {
      redirect: 'follow',
      signal: ac.signal,
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
        Accept: 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
      },
    });
    clearTimeout(to);
    if (!upstream.ok) return null;
    const buf = Buffer.from(await upstream.arrayBuffer());
    const max = parsed.hostname.toLowerCase().includes('news.google.com')
      ? 1400 * 1024
      : 700 * 1024;
    const slice = buf.length > max ? buf.subarray(0, max) : buf;
    const html = slice.toString('utf8');
    return parseFirstContentImageFromHtml(html, parsed.href);
  } catch {
    clearTimeout(to);
    return null;
  }
}

function buildDomainImageFallbackCandidates(pageUrl) {
  if (!pageUrl || typeof pageUrl !== 'string') return [];
  let parsed;
  try {
    parsed = new URL(pageUrl.trim());
  } catch {
    return [];
  }
  const host = parsed.hostname.toLowerCase();
  if (!host) return [];
  return [
    `https://logo.clearbit.com/${encodeURIComponent(host)}?size=512`,
    `https://www.google.com/s2/favicons?domain=${encodeURIComponent(host)}&sz=256`,
  ];
}

async function mapWithConcurrency(items, limit, mapper) {
  const out = new Array(items.length);
  let i = 0;
  async function worker() {
    for (;;) {
      const idx = i;
      i += 1;
      if (idx >= items.length) break;
      out[idx] = await mapper(items[idx], idx);
    }
  }
  const n = Math.min(Math.max(limit, 1), Math.max(items.length, 1));
  await Promise.all(Array.from({ length: n }, () => worker()));
  return out;
}

/**
 * @param {object} [options]
 * @param {string|null|undefined} [options.newsApiCategory] - NewsAPI category or omit for mixed headlines
 * @param {number} [options.pageSize] - override page size for this request
 * @returns {Promise<Array<object>>} Normalized items for newsIngestionService.toPostDoc
 */
async function fetchNewsApiItems(options = {}) {
  const { newsApiCategory, pageSize: pageSizeOpt, language: languageOpt } = options;
  const key = process.env.NEWSAPI_KEY?.trim();
  if (!key) return [];

  const country = (process.env.NEWSAPI_COUNTRY || 'in').trim();
  const lang = String(
    languageOpt || process.env.NEWSAPI_LANGUAGE || 'en',
  )
    .trim()
    .toLowerCase();
  const defaultSize = Number(process.env.NEWSAPI_PAGE_SIZE || 12);
  const pageSize = Math.min(
    Math.max(Number(pageSizeOpt ?? defaultSize), 1),
    100,
  );

  const url = new URL('https://newsapi.org/v2/top-headlines');
  url.searchParams.set('apiKey', key);
  url.searchParams.set('pageSize', String(pageSize));
  // NewsAPI: `language` cannot be mixed with `country`. English = India bundle; other langs = language-only.
  if (lang === 'en') {
    url.searchParams.set('country', country);
  } else {
    url.searchParams.set('language', lang);
  }
  if (newsApiCategory && String(newsApiCategory).trim()) {
    url.searchParams.set('category', String(newsApiCategory).trim());
  }

  const res = await fetch(url.toString(), {
    headers: { 'User-Agent': 'NewsApp/1.0 (https://newsapi.org)' },
  });
  const data = await res.json();

  if (data.status !== 'ok') {
    // Many keys / langs are unsupported; skip this language instead of failing the whole ingest run.
    if (lang !== 'en') return [];
    throw new Error(data.message || `NewsAPI error (code ${data.code ?? res.status})`);
  }

  const articles = data.articles || [];
  const ogConcurrency = Math.min(
    Math.max(Number(process.env.NEWSAPI_OG_CONCURRENCY || 5), 1),
    10,
  );

  return mapWithConcurrency(articles, ogConcurrency, async (article) => {
    const body =
      normalizeWireText(mergeDescriptionAndContent(article.description, article.content))
      || normalizeWireText(article.title);
    const title = stripHtml(article.title || '').slice(0, 200);
    let img = normalizeMediaUrl(article.urlToImage);
    if (!img && article.url) {
      img = await fetchBestImageFallback(article.url);
    }
    return {
      title,
      body: (body || title).slice(0, 10000),
      summary: summarize(
        stripNewsWireTruncationMarkers(
          stripHtml(article.description || article.content || body || ''),
        ),
      ),
      mediaUrl: img,
      tags: [],
      sourceUrl: article.url || '',
      sourcePublishedAt: article.publishedAt || null,
      sourceType: 'api',
      language: lang,
      scrapeConfidence: img ? 0.9 : 0.85,
      apiSourceName: article.source?.name || 'headlines',
    };
  });
}

/** Map NewsAPI-style category from ingest plan → GNews top-headlines category. */
function newsApiCategoryToGNews(newsApiCategory) {
  if (newsApiCategory == null || String(newsApiCategory).trim() === '') return 'general';
  const k = String(newsApiCategory).trim().toLowerCase();
  const allowed = new Set([
    'general', 'world', 'nation', 'business', 'technology',
    'entertainment', 'sports', 'science', 'health',
  ]);
  if (allowed.has(k)) return k;
  return 'general';
}

/**
 * GNews API v4 top-headlines — set GNEWS_API_KEY in the environment.
 * @param {object} [options]
 * @param {string|null|undefined} [options.newsApiCategory] - same labels as NewsAPI plan (mapped to GNews)
 * @param {number} [options.pageSize]
 * @param {string|null|undefined} [options.language] - ISO 639-1 (e.g. en, te, hi). Overrides GNEWS_LANG for this request.
 * @returns {Promise<Array<object>>} Normalized items for newsIngestionService.toPostDoc
 */
async function fetchGNewsItems(options = {}) {
  const { newsApiCategory, pageSize: pageSizeOpt, language: languageOpt } = options;
  const key = process.env.GNEWS_API_KEY?.trim();
  if (!key) return [];

  const country = (process.env.GNEWS_COUNTRY || 'in').trim().toLowerCase();
  const lang = String(
    languageOpt || process.env.GNEWS_LANG || 'en',
  )
    .trim()
    .toLowerCase();
  const defaultSize = Number(process.env.GNEWS_MAX || process.env.NEWSAPI_PAGE_SIZE || 12);
  const pageSize = Math.min(Math.max(Number(pageSizeOpt ?? defaultSize), 1), 100);

  const category = newsApiCategoryToGNews(newsApiCategory);
  const url = new URL('https://gnews.io/api/v4/top-headlines');
  url.searchParams.set('apikey', key);
  url.searchParams.set('category', category);
  url.searchParams.set('country', country);
  url.searchParams.set('lang', lang);
  url.searchParams.set('max', String(pageSize));

  const res = await fetch(url.toString(), {
    headers: { 'User-Agent': 'NewsApp/1.0 (https://gnews.io)' },
  });
  const data = await res.json();

  if (!res.ok) {
    const msg = data.message || data.errors?.[0]?.message || res.statusText;
    throw new Error(msg || `GNews HTTP ${res.status}`);
  }
  if (data.errors && data.errors.length) {
    const msg = data.errors.map((e) => (typeof e === 'string' ? e : e.message)).join('; ');
    throw new Error(msg || 'GNews error');
  }
  const articles = data.articles || [];
  const ogConcurrency = Math.min(
    Math.max(Number(process.env.NEWSAPI_OG_CONCURRENCY || 5), 1),
    10,
  );

  return mapWithConcurrency(articles, ogConcurrency, async (article) => {
    const body =
      normalizeWireText(mergeDescriptionAndContent(article.description, article.content))
      || normalizeWireText(article.title);
    const title = stripHtml(article.title || '').slice(0, 200);
    let img = normalizeMediaUrl(article.image);
    if (!img && article.url) {
      img = await fetchBestImageFallback(article.url);
    }
    return {
      title,
      body: (body || title).slice(0, 10000),
      summary: summarize(
        stripNewsWireTruncationMarkers(
          stripHtml(article.description || article.content || body || ''),
        ),
      ),
      mediaUrl: img,
      tags: [],
      sourceUrl: article.url || '',
      sourcePublishedAt: article.publishedAt || null,
      sourceType: 'api',
      language: lang,
      scrapeConfidence: img ? 0.9 : 0.85,
      apiSourceName: article.source?.name || 'GNews',
    };
  });
}

module.exports = {
  fetchNewsApiItems,
  fetchGNewsItems,
  normalizeMediaUrl,
  fetchOgImageFallback,
  fetchBestImageFallback,
  buildDomainImageFallbackCandidates,
};
