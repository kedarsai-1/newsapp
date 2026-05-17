/**
 * One-time fix: move AP/TG-scoped rows out of Politics into Local; tag national politics as india.
 * Run: node scripts/fixTeluguPoliticsScopes.js
 */
require('dotenv').config();
const mongoose = require('mongoose');
const NewsPost = require('../models/NewsPost');
const Category = require('../models/Category');

async function main() {
  await mongoose.connect(process.env.MONGO_URI);
  const [politics, local] = await Promise.all([
    Category.findOne({ slug: 'politics' }).select('_id').lean(),
    Category.findOne({ slug: 'local' }).select('_id').lean(),
  ]);
  if (!politics?._id || !local?._id) {
    console.error('Seed politics + local categories first.');
    process.exit(1);
  }

  const moved = await NewsPost.updateMany(
    {
      category: politics._id,
      language: 'te',
      politicsScope: { $in: ['andhra', 'telangana'] },
    },
    { $set: { category: local._id } },
  );
  console.log('Moved AP/TG politics → local category:', moved.modifiedCount);

  const taggedIndia = await NewsPost.updateMany(
    {
      category: politics._id,
      language: 'te',
      sourceName: /TV9 Telugu - Politics/i,
    },
    { $set: { politicsScope: 'india' } },
  );
  console.log('Tagged TV9 Politics feed as india:', taggedIndia.modifiedCount);

  await mongoose.disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
