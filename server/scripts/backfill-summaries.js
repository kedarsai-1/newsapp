#!/usr/bin/env node
/**
 * Re-apply boundary-aware truncation to existing post summaries.
 * Fixes legacy hard-slice artifacts (mid-word cuts at 277/280 chars).
 *
 * Usage:
 *   node scripts/backfill-summaries.js [--dry-run] [--limit=500] [--source=youtube|rss|api]
 */
require('dotenv').config();

const { prisma } = require('../config/prisma');
const {
  truncateSummary,
  isSuspiciousSummary,
  normalizeSummarySource,
} = require('../utils/summaryText');

function parseArgs() {
  const args = process.argv.slice(2);
  const out = { dryRun: false, limit: 500, source: null };
  for (const arg of args) {
    if (arg === '--dry-run') out.dryRun = true;
    else if (arg.startsWith('--limit=')) out.limit = Math.max(1, Number(arg.split('=')[1]) || 500);
    else if (arg.startsWith('--source=')) out.source = arg.split('=')[1] || null;
  }
  return out;
}

function rebuildSummary(post) {
  const body = normalizeSummarySource(post.body || '');
  const current = normalizeSummarySource(post.summary || '');
  const source = body.length > current.length ? body : (current || body);
  if (!source) return null;
  const max = post.sourceType === 'youtube' ? 280 : 300;
  return truncateSummary(source, max) || null;
}

async function main() {
  const { dryRun, limit, source } = parseArgs();
  const where = {
    status: 'approved',
    OR: [
      { summary: null },
      { summary: '' },
    ],
  };

  // Also fetch posts with suspicious summaries when not empty-only mode
  const suspiciousWhere = {
    status: 'approved',
    summary: { not: null },
    NOT: { summary: '' },
  };
  if (source) suspiciousWhere.sourceType = source;

  const emptyPosts = await prisma.newsPost.findMany({
    where: source ? { ...where, sourceType: source } : where,
    take: Math.floor(limit / 4),
    orderBy: { createdAt: 'desc' },
    select: { id: true, title: true, body: true, summary: true, sourceType: true },
  });

  const candidatePosts = await prisma.newsPost.findMany({
    where: suspiciousWhere,
    take: limit,
    orderBy: { createdAt: 'desc' },
    select: { id: true, title: true, body: true, summary: true, sourceType: true },
  });

  const seen = new Set();
  const toProcess = [];
  for (const p of [...emptyPosts, ...candidatePosts]) {
    if (seen.has(p.id)) continue;
    seen.add(p.id);
    if (!p.summary || !p.summary.trim() || isSuspiciousSummary(p.summary)) {
      toProcess.push(p);
    }
  }

  let updated = 0;
  let skipped = 0;

  for (const post of toProcess.slice(0, limit)) {
    const next = rebuildSummary(post);
    if (!next || next === post.summary) {
      skipped += 1;
      continue;
    }
    if (dryRun) {
      console.log(`[dry-run] ${post.id} (${post.sourceType})`);
      console.log(`  was: ${(post.summary || '').slice(-50)}`);
      console.log(`  now: ${next.slice(-50)}`);
      updated += 1;
      continue;
    }
    await prisma.newsPost.update({
      where: { id: post.id },
      data: { summary: next },
    });
    updated += 1;
  }

  console.log(JSON.stringify({
    dryRun,
    candidates: toProcess.length,
    updated,
    skipped,
    source: source || 'all',
  }, null, 2));

  await prisma.$disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
