const { JSDOM, VirtualConsole } = require('jsdom');
const { Readability } = require('@mozilla/readability');
const { resolveGoogleNewsPublisherUrl } = require('./rssService');

/** JSDOM's CSSOM cannot parse much modern CSS; strip styles so logs stay clean and Readability still has the DOM. */
function stripStyleTags(html) {
  if (typeof html !== 'string') return html;
  return html
    .replace(/<link\b[^>]*\brel=['"]?stylesheet['"]?[^>]*>/gi, '')
    .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, '');
}

function isBlockedFetchHost(hostname) {
  const host = String(hostname || '').toLowerCase();
  if (!host || host === 'localhost' || host.endsWith('.local')) return true;
  if (host === 'metadata.google.internal') return true;
  return /^(127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(host);
}

function normalizeUrl(input) {
  if (!input || typeof input !== 'string') return null;
  const raw = input.trim();
  if (!raw) return null;
  let url;
  try {
    url = new URL(raw);
  } catch {
    return null;
  }
  if (!['http:', 'https:'].includes(url.protocol)) return null;
  if (isBlockedFetchHost(url.hostname)) return null;
  return url;
}

function looksLikeGoogleNews(url) {
  const host = String(url?.hostname || '').toLowerCase();
  return host === 'news.google.com' || host.endsWith('.news.google.com');
}

function tryExtractPublisherUrlFromGoogleNewsParams(url) {
  try {
    const candidates = [
      url.searchParams.get('url'),
      url.searchParams.get('u'),
      url.searchParams.get('q'),
      url.searchParams.get('link'),
    ].filter(Boolean);

    for (const c of candidates) {
      const raw = String(c).trim();
      if (!raw) continue;
      let decoded = raw;
      try {
        decoded = decodeURIComponent(raw);
      } catch { /* ignore */ }
      if (/^https?:\/\//i.test(decoded)) return decoded;
    }
  } catch { /* ignore */ }
  return null;
}

function clampInt(n, min, max, fallback) {
  const v = Number(n);
  if (!Number.isFinite(v)) return fallback;
  return Math.min(Math.max(Math.trunc(v), min), max);
}

// Tiny in-memory cache to avoid re-scraping on every open.
const _cache = new Map(); // key: url, value: { value, expiresAt }
const _maxCache = 200;

function _cacheGet(key) {
  const hit = _cache.get(key);
  if (!hit) return null;
  if (Date.now() > hit.expiresAt) {
    _cache.delete(key);
    return null;
  }
  return hit.value;
}

function _cacheSet(key, value, ttlMs) {
  if (_cache.size >= _maxCache) {
    // delete oldest entry
    const first = _cache.keys().next().value;
    if (first) _cache.delete(first);
  }
  _cache.set(key, { value, expiresAt: Date.now() + ttlMs });
}

async function extractReadableArticle(urlString, options = {}) {
  const requested = normalizeUrl(urlString);
  if (!requested) {
    return { success: false, message: 'Invalid or forbidden url.' };
  }

  let url = requested;

  // Google News RSS links often point to news.google.com which is not directly readable.
  // Resolve to the publisher URL before running Readability.
  if (looksLikeGoogleNews(url)) {
    const byParam = tryExtractPublisherUrlFromGoogleNewsParams(url);
    let resolved = byParam;
    if (!resolved) {
      try {
        resolved = await resolveGoogleNewsPublisherUrl(url.toString());
      } catch { /* ignore */ }
    }
    const resolvedUrl = resolved ? normalizeUrl(resolved) : null;
    if (resolvedUrl) {
      url = resolvedUrl;
    }
  }

  const cacheKey = url.toString();
  const cached = _cacheGet(cacheKey);
  if (cached) {
    return {
      success: true,
      cached: true,
      requestedUrl: requested.toString(),
      ...cached,
    };
  }

  const timeoutMs = clampInt(options.timeoutMs, 3000, 20000, 15000);
  const maxBytes = clampInt(options.maxBytes, 200 * 1024, 2 * 1024 * 1024, 900 * 1024);
  const cacheTtlMs = clampInt(options.cacheTtlMs, 10_000, 24 * 60 * 60 * 1000, 30 * 60 * 1000);

  const ac = new AbortController();
  const to = setTimeout(() => ac.abort(), timeoutMs);
  try {
    const res = await fetch(url.toString(), {
      redirect: 'follow',
      signal: ac.signal,
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
        Accept: 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
      },
    });
    clearTimeout(to);
    if (!res.ok) {
      return { success: false, message: `Upstream failed (${res.status})` };
    }
    const ct = (res.headers.get('content-type') || '').toLowerCase();

    const buf = Buffer.from(await res.arrayBuffer());
    const slice = buf.length > maxBytes ? buf.subarray(0, maxBytes) : buf;
    const html = slice.toString('utf8');

    // Some publishers (or WAFs) return HTML with incorrect content-type (e.g. application/octet-stream).
    // Prefer sniffing the body before failing.
    const looksHtml =
      !ct
      || ct.includes('text/html')
      || ct.includes('application/xhtml')
      || /<\s*!doctype\s+html/i.test(html)
      || /<\s*html[\s>]/i.test(html)
      || /<\s*head[\s>]/i.test(html);
    if (!looksHtml) {
      return { success: false, message: 'Not an HTML page.' };
    }

    const forDom = stripStyleTags(html);
    const virtualConsole = new VirtualConsole();
    virtualConsole.on('error', () => {});

    const dom = new JSDOM(forDom, {
      url: url.toString(),
      virtualConsole,
    });
    const reader = new Readability(dom.window.document);
    const parsed = reader.parse();
    if (!parsed || !parsed.textContent) {
      return { success: false, message: 'Could not extract readable content.' };
    }

    const value = {
      url: url.toString(),
      requestedUrl: requested.toString(),
      title: parsed.title || null,
      byline: parsed.byline || null,
      excerpt: parsed.excerpt || null,
      text: String(parsed.textContent || '').trim(),
      html: parsed.content || null,
      length: parsed.length || null,
      siteName: parsed.siteName || null,
    };
    _cacheSet(cacheKey, value, cacheTtlMs);
    return { success: true, cached: false, ...value };
  } catch (e) {
    clearTimeout(to);
    const msg = e?.name === 'AbortError' ? 'Timed out fetching article.' : 'Fetch failed.';
    return { success: false, message: msg };
  }
}

module.exports = { extractReadableArticle };

