#!/usr/bin/env node
/**
 * Move posts ingested from section-specific RSS feeds out of "general" category.
 * Usage: node scripts/recategorizeSectionFeedPosts.js [--dry-run]
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const { prisma } = require('../config/prisma');
const { getRssFeeds } = require('../config/rssFeeds');

const dryRun = process.argv.includes('--dry-run');

async function main() {
  const feeds = getRssFeeds().filter(
    (f) => f.categorySlug && String(f.categorySlug).toLowerCase() !== 'general',
  );
  const bySource = new Map();
  for (const f of feeds) {
    bySource.set(`RSS · ${f.name}`, String(f.categorySlug).toLowerCase());
  }

  const categories = await prisma.category.findMany({
    where: { slug: { in: [...new Set(feeds.map((f) => f.categorySlug))] } },
    select: { id: true, slug: true },
  });
  const catBySlug = new Map(categories.map((c) => [c.slug, c.id]));

  let updated = 0;
  for (const [sourceName, slug] of bySource) {
    const categoryId = catBySlug.get(slug);
    if (!categoryId) continue;
    const where = {
      sourceName,
      category: { slug: 'general' },
    };
    const count = await prisma.newsPost.count({ where });
    if (!count) continue;
    console.log(`${sourceName} → ${slug}: ${count}`);
    if (!dryRun) {
      const res = await prisma.newsPost.updateMany({ where, data: { categoryId } });
      updated += res.count;
    } else {
      updated += count;
    }
  }

  console.log(dryRun ? `[dry-run] would update ${updated}` : `updated ${updated}`);
  await prisma.$disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
