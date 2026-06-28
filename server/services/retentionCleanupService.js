const fs = require('fs');
const path = require('path');
const { prisma } = require('../config/prisma');
const { cloudinary } = require('../config/cloudinary');
const { isCloudinaryAvailable } = require('../utils/cloudinaryHealth');

const CLOUDINARY_INGEST_FOLDERS = [
  { prefix: 'newsapp/external', resourceType: 'image' },
  { prefix: 'newsapp/images', resourceType: 'image' },
  { prefix: 'newsapp/videos', resourceType: 'video' },
];

function clampInt(n, min, max, fallback) {
  const v = Number(n);
  if (!Number.isFinite(v)) return fallback;
  return Math.min(Math.max(Math.trunc(v), min), max);
}

function retentionDaysFromEnv() {
  return clampInt(process.env.RETENTION_DAYS || process.env.CLOUDINARY_RETENTION_DAYS, 15, 60, 18);
}

function isCloudinaryConfigured() {
  return Boolean(
    process.env.CLOUDINARY_CLOUD_NAME
    && process.env.CLOUDINARY_API_KEY
    && process.env.CLOUDINARY_API_SECRET,
  );
}

function localMediaDir() {
  return process.env.INGEST_LOCAL_MEDIA_DIR
    || path.join(__dirname, '..', '..', 'newsapp-media', 'ingest');
}

async function destroyCloudinaryPublicIds(publicIds, { resourceType = 'image' } = {}) {
  if (!isCloudinaryConfigured() || !(await isCloudinaryAvailable())) {
    return { attempted: 0, deleted: 0, skipped: true };
  }
  const ids = Array.from(new Set(publicIds.filter(Boolean).map(String)));
  if (!ids.length) return { attempted: 0, deleted: 0 };

  const batchSize = 80;
  let deleted = 0;
  for (let i = 0; i < ids.length; i += batchSize) {
    const batch = ids.slice(i, i + batchSize);
    // eslint-disable-next-line no-await-in-loop
    const res = await cloudinary.api.delete_resources(batch, { resource_type: resourceType });
    const map = res?.deleted || {};
    deleted += Object.values(map).filter((v) => v === 'deleted').length;
  }
  return { attempted: ids.length, deleted };
}

/**
 * Delete Cloudinary uploads older than N days by folder prefix (catches rehosts without DB publicId).
 */
async function purgeCloudinaryFolderByAge(prefix, resourceType, retentionDays, { dryRun = false } = {}) {
  if (!isCloudinaryConfigured() || !(await isCloudinaryAvailable())) {
    return { prefix, resourceType, deleted: 0, skipped: true };
  }
  if (dryRun) {
    return { prefix, resourceType, deleted: 0, skipped: true, dryRun: true };
  }

  const olderThan = `${clampInt(retentionDays, 1, 365, 18)}d`;
  let deleted = 0;
  let nextCursor;
  let pages = 0;

  do {
    const opts = {
      resource_type: resourceType,
      type: 'upload',
      older_than: olderThan,
    };
    if (nextCursor) opts.next_cursor = nextCursor;

    // eslint-disable-next-line no-await-in-loop
    const res = await cloudinary.api.delete_resources_by_prefix(prefix, opts);
    const map = res?.deleted || {};
    deleted += Object.values(map).filter((v) => v === 'deleted').length;
    nextCursor = res?.next_cursor;
    pages += 1;
  } while (nextCursor && pages < 50);

  return { prefix, resourceType, deleted, olderThan };
}

async function purgeStaleCloudinaryMedia({
  retentionDays = retentionDaysFromEnv(),
  dryRun = false,
} = {}) {
  const days = clampInt(retentionDays, 15, 60, 18);
  const folders = [];
  for (const { prefix, resourceType } of CLOUDINARY_INGEST_FOLDERS) {
    // eslint-disable-next-line no-await-in-loop
    const out = await purgeCloudinaryFolderByAge(prefix, resourceType, days, { dryRun });
    folders.push(out);
  }
  const deleted = folders.reduce((sum, f) => sum + (f.deleted || 0), 0);
  return { retentionDays: days, deleted, folders };
}

async function purgeLocalMediaByAge({
  retentionDays = retentionDaysFromEnv(),
  dryRun = false,
} = {}) {
  const days = clampInt(retentionDays, 15, 60, 18);
  const dir = localMediaDir();
  const cutoffMs = Date.now() - days * 24 * 60 * 60 * 1000;
  let deleted = 0;
  let scanned = 0;

  let names = [];
  try {
    names = fs.readdirSync(dir);
  } catch {
    return { retentionDays: days, scanned: 0, deleted: 0, skipped: true };
  }

  for (const name of names) {
    const filePath = path.join(dir, name);
    let stat;
    try {
      stat = fs.statSync(filePath);
    } catch {
      continue;
    }
    if (!stat.isFile()) continue;
    scanned += 1;
    const ageMs = stat.mtimeMs || stat.birthtimeMs || 0;
    if (ageMs >= cutoffMs) continue;
    if (!dryRun) {
      try {
        fs.unlinkSync(filePath);
      } catch {
        continue;
      }
    }
    deleted += 1;
  }

  return { retentionDays: days, scanned, deleted };
}

/**
 * Delete ingested news older than N days from PostgreSQL + remove their Cloudinary media.
 *
 * We keep reporter/manual posts by default (production safety), and only purge:
 *   sourceType in ['api','rss','html','youtube']
 */
async function purgeOldNews({
  retentionDays = retentionDaysFromEnv(),
  limit = 1200,
  dryRun = false,
  keepManual = true,
} = {}) {
  const days = clampInt(retentionDays, 15, 60, 18);
  const max = clampInt(limit, 1, 10_000, 2000);
  const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

  const sourceTypes = keepManual
    ? ['api', 'rss', 'html', 'youtube']
    : ['api', 'rss', 'html', 'youtube', 'manual'];

  const where = {
    sourceType: { in: sourceTypes },
    OR: [
      { sourcePublishedAt: { lt: cutoff } },
      { sourcePublishedAt: null, createdAt: { lt: cutoff } },
    ],
  };

  const posts = await prisma.newsPost.findMany({
    where,
    select: {
      id: true,
      media: true,
      sourceUrl: true,
      sourceType: true,
      sourcePublishedAt: true,
      createdAt: true,
    },
    orderBy: [{ sourcePublishedAt: 'asc' }, { createdAt: 'asc' }],
    take: max,
  });

  const ids = posts.map((p) => p.id);

  const imgPublicIds = [];
  const videoPublicIds = [];
  for (const p of posts) {
    const media = Array.isArray(p.media) ? p.media : [];
    for (const m of media) {
      let pid = m?.publicId;
      if (!pid && m?.url && String(m.url).includes('res.cloudinary.com/')) {
        const match = String(m.url).match(/\/upload\/(?:v\d+\/)?(.+?)(?:\.[a-z0-9]+)?$/i);
        if (match?.[1]) pid = match[1];
      }
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
    result.cloudinary.images = await destroyCloudinaryPublicIds(imgPublicIds, { resourceType: 'image' });
    result.cloudinary.videos = await destroyCloudinaryPublicIds(videoPublicIds, { resourceType: 'video' });

    const del = await prisma.newsPost.deleteMany({ where: { id: { in: ids } } });
    result.deletedPosts = del.count || 0;
  } else {
    result.cloudinary.images = { attempted: imgPublicIds.length, deleted: 0, skipped: true };
    result.cloudinary.videos = { attempted: videoPublicIds.length, deleted: 0, skipped: true };
  }

  return result;
}

/** Full retention pass: old ingested posts + aged Cloudinary folders + local /media/ingest. */
async function runRetentionCleanup({
  retentionDays = retentionDaysFromEnv(),
  limit,
  dryRun = false,
  keepManual = true,
} = {}) {
  const days = clampInt(retentionDays, 15, 60, 18);
  const news = await purgeOldNews({
    retentionDays: days,
    limit: limit ?? Number(process.env.RETENTION_BATCH || 2000),
    dryRun,
    keepManual,
  });
  const cloudinaryFolders = await purgeStaleCloudinaryMedia({ retentionDays: days, dryRun });
  const localMedia = await purgeLocalMediaByAge({ retentionDays: days, dryRun });
  return {
    success: true,
    dryRun: Boolean(dryRun),
    retentionDays: days,
    news,
    cloudinaryFolders,
    localMedia,
  };
}

module.exports = {
  purgeOldNews,
  purgeStaleCloudinaryMedia,
  purgeLocalMediaByAge,
  runRetentionCleanup,
  retentionDaysFromEnv,
};
