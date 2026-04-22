const Parser = require('rss-parser');

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

function summarize(text) {
  if (!text) return null;
  const t = String(text);
  return t.length > 280 ? `${t.slice(0, 277)}...` : t;
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
    summary: summarize(stripHtml(item.contentSnippet || item.summary || rawBody)),
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

module.exports = { fetchRssItems, normalizeRssItem, resolveGoogleNewsPublisherUrl };

