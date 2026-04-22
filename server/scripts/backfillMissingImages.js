/**
 * Backfill missing thumbnails for existing RSS/API posts.
 *
 * Strategy:
 * 1) Resolve Google News links to publisher URL.
 * 2) Fetch best image fallback (og/twitter -> first content image).
 * 3) Rehost to Cloudinary.
 *
 * Usage:
 *   node scripts/backfillMissingImages.js
 *   BACKFILL_LIMIT=800 node scripts/backfillMissingImages.js
 */

require('dotenv').config();
const crypto = require('crypto');
const mongoose = require('mongoose');
const NewsPost = require('../models/NewsPost');
const { cloudinary } = require('../config/cloudinary');
const { fetchBestImageFallback, buildDomainImageFallbackCandidates } = require('../services/newsApiService');
const { resolveGoogleNewsPublisherUrl } = require('../services/rssService');

function hashUrl(url) {
  return crypto.createHash('sha256').update(url).digest('hex');
}

function isCloudinaryUrl(url) {
  if (!url || typeof url !== 'string') return false;
  return url.includes('res.cloudinary.com/') || url.includes('cloudinary.com/');
}

async function rehostExternalImageToCloudinary(imageUrl, { referer } = {}) {
  if (!imageUrl || typeof imageUrl !== 'string') return null;
  if (isCloudinaryUrl(imageUrl)) return { url: imageUrl, publicId: null };

  try {
    const res = await fetch(imageUrl, {
      redirect: 'follow',
      headers: {
        'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
        Accept: 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
        ...(referer ? { Referer: referer, Origin: referer } : {}),
      },
    });
    if (!res.ok) return null;
    const ct = (res.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
    if (ct && !ct.startsWith('image/')) return null;
    const buf = Buffer.from(await res.arrayBuffer());
    if (!buf.length || buf.length > 5 * 1024 * 1024) return null;
    const dataUri = `data:${ct || 'image/jpeg'};base64,${buf.toString('base64')}`;
    const up = await cloudinary.uploader.upload(dataUri, {
      folder: 'newsapp/external',
      resource_type: 'image',
      overwrite: false,
      unique_filename: true,
    });
    const url = up?.secure_url || up?.url;
    if (!url) return null;
    return { url, publicId: up.public_id };
  } catch {
    return null;
  }
}

function preferredHostFromSourceName(sourceName) {
  const src = String(sourceName || '').toLowerCase();
  if (src.includes('eenadu')) return 'eenadu.net';
  if (src.includes('aaj tak')) return 'aajtak.in';
  if (src.includes('amar ujala')) return 'amarujala.com';
  return null;
}

async function main() {
  if (!process.env.MONGO_URI?.trim()) throw new Error('Missing MONGO_URI');
  await mongoose.connect(process.env.MONGO_URI);

  const limit = Math.min(1500, Math.max(1, Number(process.env.BACKFILL_LIMIT || 600)));
  const posts = await NewsPost.find({
    status: 'approved',
    sourceType: { $in: ['rss', 'api'] },
    sourceUrl: { $exists: true, $ne: null, $ne: '' },
    $or: [{ media: { $exists: false } }, { media: { $size: 0 } }],
  })
    .select('_id sourceUrl sourceName sourceUrlHash media')
    .sort({ createdAt: -1 })
    .limit(limit);

  let updated = 0;
  let failed = 0;
  let resolved = 0;
  for (const p of posts) {
    let articleUrl = p.sourceUrl;
    if (articleUrl && String(articleUrl).includes('news.google.com')) {
      const preferredHost = preferredHostFromSourceName(p.sourceName);
      // eslint-disable-next-line no-await-in-loop
      const r = await resolveGoogleNewsPublisherUrl(articleUrl, { preferredHost });
      if (r) {
        articleUrl = r;
        resolved += 1;
      }
    }

    // eslint-disable-next-line no-await-in-loop
    let finalUrl = null;
    let finalPublicId = null;

    const img = await fetchBestImageFallback(articleUrl);
    if (img) {
      // eslint-disable-next-line no-await-in-loop
      const reh = await rehostExternalImageToCloudinary(img, { referer: articleUrl });
      finalUrl = reh?.url || img;
      finalPublicId = reh?.publicId || null;
    } else {
      const logoCandidates = buildDomainImageFallbackCandidates(articleUrl);
      for (const candidate of logoCandidates) {
        // eslint-disable-next-line no-await-in-loop
        const reh = await rehostExternalImageToCloudinary(candidate, { referer: articleUrl });
        if (reh?.url) {
          finalUrl = reh.url;
          finalPublicId = reh.publicId || null;
          break;
        }
      }
    }

    if (!finalUrl) {
      failed += 1;
      continue;
    }

    p.sourceUrl = articleUrl;
    p.sourceUrlHash = articleUrl ? hashUrl(articleUrl) : null;
    p.media = [{ type: 'image', url: finalUrl, ...(finalPublicId ? { publicId: finalPublicId } : {}) }];
    // eslint-disable-next-line no-await-in-loop
    await p.save();
    updated += 1;
  }

  const total = await NewsPost.countDocuments();
  const withMedia = await NewsPost.countDocuments({ 'media.0': { $exists: true } });
  console.log(JSON.stringify({
    scanned: posts.length,
    updated,
    failed,
    resolvedGoogleNewsLinks: resolved,
    total,
    withMedia,
    withoutMedia: total - withMedia,
  }, null, 2));

  await mongoose.disconnect();
}

main().catch((e) => {
  console.error(e?.message || e);
  process.exit(1);
});

