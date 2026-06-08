#!/usr/bin/env node
/**
 * Re-generate AI summaries for posts stored with legacy short clips (< 350 chars).
 * Usage: node scripts/backfill-summaries.js [--limit=50] [--language=en|hi|te]
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const { prisma } = require('../config/prisma');
const {
  summarizeForRssIngest,
  prepareForSummarization,
} = require('../services/rssService');

function parseArg(name, fallback) {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.split('=').slice(1).join('=') : fallback;
}

async function main() {
  const limit = Math.min(200, Math.max(1, Number(parseArg('limit', 40))));
  const language = String(parseArg('language', 'en')).toLowerCase();
  const maxStored = Math.max(350, Number(process.env.SUMMARY_BACKFILL_MAX_CHARS || 350));

  const posts = await prisma.newsPost.findMany({
    where: {
      status: 'approved',
      language,
      NOT: [{ summary: null }, { summary: '' }, { body: '' }],
    },
    select: {
      id: true,
      title: true,
      body: true,
      summary: true,
      originalLanguage: true,
      language: true,
    },
    orderBy: { createdAt: 'desc' },
    take: limit * 4,
  });

  const candidates = posts.filter((p) => {
    const sl = String(p.summary || '').trim().length;
    const bl = String(p.body || '').trim().length;
    return sl > 0 && sl <= maxStored && bl > sl + 80;
  }).slice(0, limit);

  console.log(`[backfill-summaries] ${candidates.length} ${language} posts to refresh`);

  let updated = 0;
  let failed = 0;

  for (const p of candidates) {
    const input = String(p.body || p.summary || p.title || '').trim();
    if (input.length < 80) {
      failed += 1;
      continue;
    }
    try {
      const prep = prepareForSummarization(input);
      // eslint-disable-next-line no-await-in-loop
      const next = await summarizeForRssIngest(
        prep.textForSummary || input,
        prep.originalLang || p.originalLanguage || 'eng',
        p.language || language,
      );
      if (!next || next.trim().length <= String(p.summary || '').trim().length) {
        failed += 1;
        continue;
      }
      // eslint-disable-next-line no-await-in-loop
      await prisma.newsPost.update({
        where: { id: p.id },
        data: { summary: next.trim() },
      });
      updated += 1;
      if (updated % 5 === 0) console.log(`[backfill-summaries] updated ${updated}…`);
    } catch (e) {
      failed += 1;
      console.warn(`[backfill-summaries] skip ${p.id}: ${e?.message || e}`);
    }
  }

  console.log(`[backfill-summaries] done — updated ${updated}, skipped/failed ${failed}`);
  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
