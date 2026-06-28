#!/usr/bin/env node
/**
 * Repair dead Cloudinary hero images by re-fetching from article og:image and rehosting.
 * Usage: node scripts/backfillDeadCloudinaryMedia.js [--limit=100] [--dry-run]
 */
require('dotenv').config();

const { prisma } = require('../config/prisma');
const { isCloudinaryUrl } = require('../utils/rehostExternalImage');
const { rehostExternalImageForIngest } = require('../utils/rehostExternalImage');
const { fetchBestImageFallback } = require('../services/newsApiService');

function parseArgs() {
  const args = { limit: 150, dryRun: false };
  for (const arg of process.argv.slice(2)) {
    if (arg === '--dry-run') args.dryRun = true;
    else if (arg.startsWith('--limit=')) args.limit = Number(arg.split('=')[1]) || 150;
  }
  return args;
}

async function isUrlAlive(url) {
  if (!url) return false;
  const ac = new AbortController();
  const to = setTimeout(() => ac.abort(), 12000);
  try {
    const res = await fetch(url, {
      method: 'HEAD',
      redirect: 'follow',
      signal: ac.signal,
      headers: { 'User-Agent': 'NewsApp-MediaHealth/1.0' },
    });
    return res.ok;
  } catch {
    return false;
  } finally {
    clearTimeout(to);
  }
}

async function main() {
  const { limit, dryRun } = parseArgs();

  const posts = await prisma.newsPost.findMany({
    where: {
      status: 'approved',
      media: { some: { type: 'image' } },
    },
    select: {
      id: true,
      sourceUrl: true,
      media: {
        where: { type: 'image' },
        select: { id: true, url: true },
        orderBy: { order: 'asc' },
        take: 1,
      },
    },
    orderBy: { createdAt: 'desc' },
    take: limit * 3,
  });

  let scanned = 0;
  let dead = 0;
  let repaired = 0;
  let failed = 0;

  for (const post of posts) {
    if (scanned >= limit) break;
    const media = post.media[0];
    const url = media?.url;
    if (!isCloudinaryUrl(url)) continue;
    scanned += 1;
    const alive = await isUrlAlive(url);
    if (alive) continue;
    dead += 1;
    console.warn('[dead-cloudinary]', post.id, url?.slice(0, 80));

    if (dryRun) {
      repaired += 1;
      continue;
    }

    let replacement = null;
    if (post.sourceUrl) {
      try {
        replacement = await fetchBestImageFallback(post.sourceUrl);
      } catch (err) {
        console.warn('[og-fallback]', post.id, err.message);
      }
    }
    if (!replacement || replacement === url) {
      failed += 1;
      continue;
    }

    const reh = await rehostExternalImageForIngest(replacement, {
      referer: post.sourceUrl,
    });
    if (!reh.ok || !reh.url) {
      failed += 1;
      console.warn('[rehost]', post.id, reh.reason);
      continue;
    }

    await prisma.newsPostMedia.update({
      where: { id: media.id },
      data: { url: reh.url },
    });
    repaired += 1;
    if (repaired % 10 === 0) console.log(`[backfill] repaired ${repaired}`);
  }

  console.log(JSON.stringify({ scanned, dead, repaired, failed, dryRun }, null, 2));
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
