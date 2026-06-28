#!/usr/bin/env node
/**
 * Backfill recent post hero images to local /media/ingest/ (when Cloudinary is disabled).
 * Usage: node scripts/backfillLocalMedia.js [--days=7] [--limit=200] [--dry-run]
 */
require('dotenv').config();

const { prisma } = require('../config/prisma');
const { rehostExternalImageForIngest, isLocalMediaUrl, isCloudinaryUrl } = require('../utils/rehostExternalImage');

function parseArgs() {
  const args = { days: 7, limit: 200, dryRun: false };
  for (const arg of process.argv.slice(2)) {
    if (arg === '--dry-run') args.dryRun = true;
    else if (arg.startsWith('--days=')) args.days = Number(arg.split('=')[1]) || 7;
    else if (arg.startsWith('--limit=')) args.limit = Number(arg.split('=')[1]) || 200;
  }
  return args;
}

function needsRehost(url) {
  if (!url || typeof url !== 'string') return false;
  if (isLocalMediaUrl(url) || isCloudinaryUrl(url)) return false;
  return /^https?:\/\//i.test(url);
}

async function main() {
  const { days, limit, dryRun } = parseArgs();
  const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);

  const posts = await prisma.newsPost.findMany({
    where: {
      status: 'approved',
      createdAt: { gte: since },
      media: { some: { type: 'image' } },
    },
    select: {
      id: true,
      sourceUrl: true,
      media: { where: { type: 'image' }, select: { id: true, url: true }, take: 1 },
    },
    orderBy: { createdAt: 'desc' },
    take: limit,
  });

  let updated = 0;
  let skipped = 0;
  let failed = 0;

  for (const post of posts) {
    const media = post.media[0];
    const url = media?.url;
    if (!needsRehost(url)) {
      skipped += 1;
      continue;
    }
    if (dryRun) {
      console.log('[dry-run] would rehost', post.id, url?.slice(0, 70));
      updated += 1;
      continue;
    }
    const reh = await rehostExternalImageForIngest(url, { referer: post.sourceUrl });
    if (!reh.ok || !reh.url) {
      failed += 1;
      console.warn('[backfill] failed', post.id, reh.reason);
      continue;
    }
    await prisma.newsPostMedia.update({
      where: { id: media.id },
      data: { url: reh.url },
    });
    updated += 1;
    if (updated % 25 === 0) console.log(`[backfill] updated ${updated}/${posts.length}`);
  }

  console.log(JSON.stringify({ scanned: posts.length, updated, skipped, failed, dryRun }, null, 2));
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
