/**
 * Tag Hindi local/politics scopes for Local sub-filters (North, India).
 * Run: node scripts/fixHindiPoliticsScopes.js
 */
require('dotenv').config();
const mongoose = require('mongoose');
const NewsPost = require('../models/NewsPost');
const Category = require('../models/Category');

const NORTH_SOURCE = /ABP News - States|Amar Ujala - (Delhi|Uttar Pradesh|Punjab|Haryana|Rajasthan|Bihar)/i;

async function main() {
  await mongoose.connect(process.env.MONGO_URI);
  const [politics, local] = await Promise.all([
    Category.findOne({ slug: 'politics' }).select('_id').lean(),
    Category.findOne({ slug: 'local' }).select('_id').lean(),
  ]);

  const politicsNull = await NewsPost.updateMany(
    {
      category: politics._id,
      language: 'hi',
      $or: [{ politicsScope: null }, { politicsScope: { $exists: false } }, { politicsScope: 'all' }],
    },
    { $set: { politicsScope: 'india' } },
  );
  console.log('Hindi politics untagged → india:', politicsNull.modifiedCount);

  const north = await NewsPost.updateMany(
    {
      category: local._id,
      language: 'hi',
      $or: [
        { sourceName: NORTH_SOURCE },
        { politicsScope: { $in: ['states', 'delhi'] } },
      ],
    },
    { $set: { politicsScope: 'north' } },
  );
  console.log('Hindi local north states → north:', north.modifiedCount);

  await mongoose.disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
