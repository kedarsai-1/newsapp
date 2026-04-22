/**
 * Run RSS ingestion only (no GNews/NewsAPI).
 *
 * Useful when API keys are missing/forbidden but you still want fresh content.
 *
 * Run:
 *   node scripts/runRssIngestionOnce.js
 */

require('dotenv').config();
const crypto = require('crypto');
const mongoose = require('mongoose');
const NewsPost = require('../models/NewsPost');
const User = require('../models/User');
const Category = require('../models/Category');
const { getRssFeeds } = require('../config/rssFeeds');
const { fetchRssItems, normalizeRssItem, resolveGoogleNewsPublisherUrl } = require('../services/rssService');
const { fetchBestImageFallback } = require('../services/newsApiService');
const { cloudinary } = require('../config/cloudinary');

const SYSTEM_REPORTER_EMAIL = process.env.SCRAPER_SYSTEM_EMAIL || 'scraper@newsnow.local';
const SYSTEM_REPORTER_PASSWORD = process.env.SCRAPER_SYSTEM_PASSWORD || 'change_me_123';
const DEFAULT_CATEGORY_SLUG = process.env.SCRAPER_DEFAULT_CATEGORY || 'general';
const SCRAPER_AUTO_APPROVE = process.env.SCRAPER_AUTO_APPROVE !== 'false';

function hashUrl(url) {
  return crypto.createHash('sha256').update(url).digest('hex');
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

    const res = await fetch(parsed.href, { redirect: 'follow', signal: ac.signal, headers });
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
    const upload = await cloudinary.uploader.upload(dataUri, {
      folder: 'newsapp/external',
      resource_type: 'image',
      overwrite: false,
      unique_filename: true,
      format: ext,
    });
    const secure = upload?.secure_url || upload?.url;
    if (!secure) return { ok: false, reason: 'upload_failed' };
    return { ok: true, url: secure, publicId: upload.public_id };
  } catch (e) {
    clearTimeout(to);
    const msg = e?.name === 'AbortError' ? 'timeout' : 'fetch_failed';
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
  if (!category) throw new Error('No active category found. Seed categories first.');
  return category;
}

async function isDuplicate(item) {
  if (item.sourceUrl) {
    const sourceUrlHash = hashUrl(item.sourceUrl);
    const existsByHash = await NewsPost.exists({ sourceUrlHash });
    if (existsByHash) return true;
  }
  const fuzzyWindowStart = new Date(Date.now() - 48 * 60 * 60 * 1000);
  const existsByTitle = await NewsPost.exists({
    title: item.title,
    createdAt: { $gte: fuzzyWindowStart },
  });
  return !!existsByTitle;
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
    sourceName,
    sourceUrl: item.sourceUrl || null,
    sourceUrlHash: item.sourceUrl ? hashUrl(item.sourceUrl) : null,
    sourcePublishedAt: item.sourcePublishedAt ? new Date(item.sourcePublishedAt) : null,
    sourceType: item.sourceType,
    scrapedAt: new Date(),
    scrapeConfidence: item.scrapeConfidence,
  };
}

async function main() {
  if (!process.env.MONGO_URI?.trim()) throw new Error('Missing MONGO_URI');
  await mongoose.connect(process.env.MONGO_URI);

  const reporter = await ensureSystemReporter();
  const feeds = getRssFeeds();

  const stats = { fetched: 0, inserted: 0, duplicates: 0, failed: 0, byLang: {} };

  for (const feed of feeds) {
    if (!feed?.url) continue;
    try {
      const category = await getCategoryBySlug(feed.categorySlug || DEFAULT_CATEGORY_SLUG);
      const items = await fetchRssItems(feed.url);
      const maxPerFeed = Math.min(50, Math.max(5, Number(process.env.RSS_ITEMS_PER_FEED || 20)));
      const slice = items.slice(0, maxPerFeed);
      stats.fetched += slice.length;

      for (const raw of slice) {
        const item = normalizeRssItem(raw, feed);
        if (!item.title) {
          stats.failed += 1;
          continue;
        }
        // eslint-disable-next-line no-await-in-loop
        if (await isDuplicate(item)) {
          stats.duplicates += 1;
          continue;
        }

        let postFields = item;

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
            if (resolved) postFields = { ...postFields, sourceUrl: resolved };
          } catch { /* ignore */ }
        }

        if (
          !postFields.mediaUrl
          && feed.ogImageFallback
          && process.env.RSS_OG_FALLBACK !== 'false'
          && postFields.sourceUrl
        ) {
          try {
            // eslint-disable-next-line no-await-in-loop
            const og = await fetchBestImageFallback(postFields.sourceUrl);
            if (og) postFields = { ...postFields, mediaUrl: og };
          } catch { /* ignore */ }
        }

        if (postFields.mediaUrl) {
          const reh = await rehostExternalImageToCloudinary(postFields.mediaUrl, {
            referer: postFields.sourceUrl || feed.url || null,
          });
          if (reh.ok && reh.url) {
            postFields = { ...postFields, mediaUrl: reh.url };
          }
        }

        const label = `RSS · ${feed.name || 'RSS'}`;
        const { apiSourceName, ...postDocFields } = postFields;
        // eslint-disable-next-line no-await-in-loop
        await NewsPost.create(toPostDoc(postDocFields, reporter._id, category._id, label));
        stats.inserted += 1;
        stats.byLang[postFields.language] = (stats.byLang[postFields.language] || 0) + 1;
      }
    } catch (e) {
      stats.failed += 1;
      console.error(`[rss-once] feed failed: ${feed.name || 'RSS'} ${feed.url} :: ${e?.message || e}`);
      continue;
    }
  }

  console.log(JSON.stringify(stats, null, 2));
  await mongoose.disconnect();
}

main().catch((e) => {
  console.error(e?.message || e);
  process.exit(1);
});

