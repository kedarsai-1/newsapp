const NewsPost = require('../models/NewsPost');
const { cloudinary } = require('../config/cloudinary');

function clampInt(n, min, max, fallback) {
  const v = Number(n);
  if (!Number.isFinite(v)) return fallback;
  return Math.min(Math.max(Math.trunc(v), min), max);
}

function isCloudinaryConfigured() {
  return Boolean(
    process.env.CLOUDINARY_CLOUD_NAME
    && process.env.CLOUDINARY_API_KEY
    && process.env.CLOUDINARY_API_SECRET,
  );
}

async function destroyCloudinaryPublicIds(publicIds, { resourceType = 'image' } = {}) {
  if (!isCloudinaryConfigured()) return { attempted: 0, deleted: 0, skipped: true };
  const ids = Array.from(new Set(publicIds.filter(Boolean).map(String)));
  if (!ids.length) return { attempted: 0, deleted: 0 };

  // Cloudinary has an API limit; keep this conservative.
  const batchSize = 80;
  let deleted = 0;
  for (let i = 0; i < ids.length; i += batchSize) {
    const batch = ids.slice(i, i + batchSize);
    // delete_resources returns { deleted: { publicId: 'deleted'|'not_found'|... } }
    // For videos, resource_type='video'
    // eslint-disable-next-line no-await-in-loop
    const res = await cloudinary.api.delete_resources(batch, { resource_type: resourceType });
    const map = res?.deleted || {};
    deleted += Object.values(map).filter((v) => v === 'deleted').length;
  }
  return { attempted: ids.length, deleted };
}

/**
 * Delete ingested news older than N days from Mongo + remove their Cloudinary media.
 *
 * We keep reporter/manual posts by default (production safety), and only purge:
 *   sourceType in ['api','rss','html']
 *
 * The cutoff uses sourcePublishedAt when present, else createdAt.
 */
async function purgeOldNews({
  retentionDays = 7,
  limit = 1200,
  dryRun = false,
  keepManual = true,
} = {}) {
  const days = clampInt(retentionDays, 1, 365, 7);
  const max = clampInt(limit, 1, 10_000, 1200);
  const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

  const sourceTypes = keepManual ? ['api', 'rss', 'html'] : ['api', 'rss', 'html', 'manual'];

  const query = {
    sourceType: { $in: sourceTypes },
    $or: [
      { sourcePublishedAt: { $lt: cutoff } },
      { sourcePublishedAt: null, createdAt: { $lt: cutoff } },
      { sourcePublishedAt: { $exists: false }, createdAt: { $lt: cutoff } },
    ],
  };

  const posts = await NewsPost.find(query)
    .select('_id media sourceUrl sourceType sourcePublishedAt createdAt')
    .sort({ sourcePublishedAt: 1, createdAt: 1 })
    .limit(max);

  const ids = posts.map((p) => p._id);

  const imgPublicIds = [];
  const videoPublicIds = [];
  for (const p of posts) {
    const media = Array.isArray(p.media) ? p.media : [];
    for (const m of media) {
      const pid = m?.publicId;
      if (!pid) continue;
      if (m.type === 'video') videoPublicIds.push(pid);
      else imgPublicIds.push(pid);
    }
  }

  const result = {
    success: true,
    dryRun: Boolean(dryRun),
    retentionDays: days,
    cutoff,
    matched: ids.length,
    deletedPosts: 0,
    cloudinary: {
      images: { attempted: 0, deleted: 0, skipped: false },
      videos: { attempted: 0, deleted: 0, skipped: false },
    },
  };

  if (!ids.length) return result;

  if (!dryRun) {
    // Best effort: delete Cloudinary first, then DB.
    result.cloudinary.images = await destroyCloudinaryPublicIds(imgPublicIds, { resourceType: 'image' });
    result.cloudinary.videos = await destroyCloudinaryPublicIds(videoPublicIds, { resourceType: 'video' });

    const del = await NewsPost.deleteMany({ _id: { $in: ids } });
    result.deletedPosts = del.deletedCount || 0;
  } else {
    result.cloudinary.images = { attempted: imgPublicIds.length, deleted: 0, skipped: true };
    result.cloudinary.videos = { attempted: videoPublicIds.length, deleted: 0, skipped: true };
  }

  return result;
}

module.exports = { purgeOldNews };

