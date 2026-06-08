#!/usr/bin/env node
/**
 * Backfill missing hero images for English RSS/API posts (og:image fetch).
 * Usage: node scripts/backfill-en-images.js [--limit=100] [--language=en]
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const { prisma } = require('../config/prisma');
const {
  fetchBestImageFallback,
  isUnusableFeedImageUrl,
} = require('../services/newsApiService');
const { resolveGoogleNewsPublisherUrl } = require('../services/rssService');
const { mediaCreate } = require('../utils/prismaNewsPost');
const { rehostExternalImageToCloudinary } = require('../utils/rehostExternalImage');

const INGEST_REHOST_IMAGES = process.env.INGEST_REHOST_IMAGES !== 'false';

function parseArg(name, fallback) {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.split('=').slice(1).join('=') : fallback;
}

async function main() {
  const limit = Math.min(500, Math.max(1, Number(parseArg('limit', 120))));
  const language = String(parseArg('language', 'en')).toLowerCase();

  const posts = await prisma.newsPost.findMany({
    where: {
      status: 'approved',
      language,
      sourceType: { in: ['rss', 'api'] },
      sourceUrl: { not: null },
      media: { none: {} },
    },
    select: { id: true, sourceUrl: true, sourceName: true },
    orderBy: { createdAt: 'desc' },
    take: limit,
  });

  console.log(`[backfill] ${posts.length} ${language} posts without media (limit ${limit})`);

  let updated = 0;
  let failed = 0;

  for (const p of posts) {
    let articleUrl = p.sourceUrl;
    if (articleUrl && String(articleUrl).includes('news.google.com')) {
      const src = String(p.sourceName || '').toLowerCase();
      let preferredHost = null;
      if (src.includes('hindustan')) preferredHost = 'hindustantimes.com';
      else if (src.includes('the hindu')) preferredHost = 'thehindu.com';
      else if (src.includes('indian express')) preferredHost = 'indianexpress.com';
      // eslint-disable-next-line no-await-in-loop
      const resolved = await resolveGoogleNewsPublisherUrl(articleUrl, { preferredHost });
      if (resolved) articleUrl = resolved;
    }

    try {
      // eslint-disable-next-line no-await-in-loop
      const og = await fetchBestImageFallback(articleUrl);
      if (!og || isUnusableFeedImageUrl(og)) {
        failed += 1;
        continue;
      }

      let finalUrl = og;
      if (INGEST_REHOST_IMAGES) {
        // eslint-disable-next-line no-await-in-loop
        const reh = await rehostExternalImageToCloudinary(og, { referer: articleUrl });
        if (reh?.ok && reh.url) finalUrl = reh.url;
      }

      // eslint-disable-next-line no-await-in-loop
      await prisma.newsPost.update({
        where: { id: p.id },
        data: {
          sourceUrl: articleUrl,
          media: {
            create: mediaCreate([{ type: 'image', url: finalUrl }]),
          },
        },
      });
      updated += 1;
      if (updated % 10 === 0) console.log(`[backfill] updated ${updated}…`);
    } catch (e) {
      failed += 1;
      console.warn(`[backfill] skip ${p.id}: ${e?.message || e}`);
    }
  }

  console.log(`[backfill] done — updated ${updated}, failed ${failed}`);
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
