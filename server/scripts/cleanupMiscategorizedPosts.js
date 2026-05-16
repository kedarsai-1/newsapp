/**
 * Remove legacy RSS rows saved under the wrong category (e.g. LiveMint News → business).
 *
 * Run: node scripts/cleanupMiscategorizedPosts.js
 * Dry run: DRY_RUN=true node scripts/cleanupMiscategorizedPosts.js
 */
require('dotenv').config();
const mongoose = require('mongoose');
const NewsPost = require('../models/NewsPost');
const Category = require('../models/Category');
const { isLegacyMiscategorized } = require('../utils/categoryRelevance');

async function main() {
  if (!process.env.MONGO_URI?.trim()) throw new Error('Missing MONGO_URI');
  const dryRun = process.env.DRY_RUN === 'true';

  await mongoose.connect(process.env.MONGO_URI);
  const categories = await Category.find({}).select('_id slug').lean();
  const bySlug = Object.fromEntries(categories.map((c) => [c.slug, c._id]));

  const targets = [
    { slug: 'business', sourcePattern: /livemint news/i },
  ];

  let deleted = 0;
  for (const t of targets) {
    const catId = bySlug[t.slug];
    if (!catId) continue;
    const rows = await NewsPost.find({
      category: catId,
      sourceName: t.sourcePattern,
      status: 'approved',
    })
      .select('_id title sourceName category')
      .lean();

    for (const row of rows) {
      const cat = categories.find((c) => String(c._id) === String(catId));
      if (!isLegacyMiscategorized(row, cat?.slug || t.slug)) continue;
      if (dryRun) {
        console.log('[dry-run] would delete:', row._id, row.title?.slice(0, 80));
      } else {
        // eslint-disable-next-line no-await-in-loop
        await NewsPost.deleteOne({ _id: row._id });
      }
      deleted += 1;
    }
  }

  console.log(JSON.stringify({ dryRun, deleted }, null, 2));
  await mongoose.disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
