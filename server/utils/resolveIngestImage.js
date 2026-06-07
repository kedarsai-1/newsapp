const {
  fetchBestImageFallback,
  isUnusableFeedImageUrl,
  parseOgImageFromHtml,
  parseFirstContentImageFromHtml,
} = require('../services/newsApiService');
const { rehostExternalImageToCloudinary } = require('./rehostExternalImage');

function normalizeMediaUrl(url) {
  if (!url || typeof url !== 'string') return null;
  let u = url.trim();
  if (!u) return null;
  if (u.startsWith('//')) u = `https:${u}`;
  if (!/^https?:\/\//i.test(u)) return null;
  if (u.startsWith('http://')) u = u.replace(/^http:\/\//i, 'https://');
  return u;
}

function extractImageFromArticleHtml(html, baseUrl) {
  if (!html || typeof html !== 'string') return null;
  const og = parseOgImageFromHtml(html);
  if (og && !isUnusableFeedImageUrl(og)) return normalizeMediaUrl(og);
  const content = parseFirstContentImageFromHtml(html, baseUrl);
  if (content && !isUnusableFeedImageUrl(content)) return normalizeMediaUrl(content);
  return null;
}

function ogFallbackEnabled(feed) {
  return feed?.ogImageFallback !== false && process.env.RSS_OG_FALLBACK !== 'false';
}

function requireImageEnabled() {
  return process.env.RSS_REQUIRE_IMAGE === 'true';
}

function rehostEnabled() {
  return process.env.INGEST_REHOST_IMAGES !== 'false';
}

/**
 * Resolve a stable hero image for an ingest item (RSS/API).
 * Order: RSS media → article HTML → og/twitter page fetch → Cloudinary rehost.
 */
async function resolveIngestImage({
  mediaUrl,
  sourceUrl,
  feedUrl = null,
  feed = null,
  articleHtml = null,
}) {
  let resolved = normalizeMediaUrl(mediaUrl);
  if (resolved && isUnusableFeedImageUrl(resolved)) resolved = null;

  const referer = sourceUrl || feedUrl || null;

  if (!resolved && articleHtml && sourceUrl) {
    resolved = extractImageFromArticleHtml(articleHtml, sourceUrl);
  }

  if (!resolved && sourceUrl && ogFallbackEnabled(feed)) {
    try {
      resolved = await fetchBestImageFallback(sourceUrl);
      if (resolved && isUnusableFeedImageUrl(resolved)) resolved = null;
    } catch {
      resolved = null;
    }
  }

  if (resolved) {
    resolved = normalizeMediaUrl(resolved);
  }

  if (resolved && rehostEnabled()) {
    const reh = await rehostExternalImageToCloudinary(resolved, { referer });
    if (reh.ok && reh.url) {
      resolved = reh.url;
    }
  }

  const required = requireImageEnabled();
  const ok = Boolean(resolved && !isUnusableFeedImageUrl(resolved));

  return {
    mediaUrl: ok ? resolved : null,
    ok,
    required,
    skipped: required && !ok,
  };
}

module.exports = {
  resolveIngestImage,
  extractImageFromArticleHtml,
  normalizeMediaUrl,
  requireImageEnabled,
};
