/**
 * Backfill politicsScope on existing Telugu/Hindi posts (run after deploy).
 *   node scripts/backfillPoliticsScopes.js
 */
require('dotenv').config();
const mongoose = require('mongoose');
const NewsPost = require('../models/NewsPost');
const Category = require('../models/Category');
const { postMatchesPoliticsScopeFilter } = require('../utils/categoryRelevance');

function inferScope(post) {
  const text = `${post.title || ''} ${post.summary || ''} ${post.body || ''}`;
  const src = String(post.sourceName || '').toLowerCase();

  if (/(andhra|amaravati|vijayawada|visakhapatnam|ఆంధ్ర)/i.test(text) || /andhra/.test(src)) {
    return 'andhra';
  }
  if (/(telangana|hyderabad|warangal|తెలంగాణ|హైదరాబాద్)/i.test(text) || /telangana/.test(src)) {
    return 'telangana';
  }
  if (
    /(उत्तर प्रदेश|पंजाब|हरियाणा|राजस्थान|बिहार|दिल्ली|uttar pradesh|punjab|haryana|rajasthan|bihar|lucknow)/i.test(text)
    || /amarujala|amar ujala|dainik bhaskar|jagran|abplive|states/.test(src)
  ) {
    return 'north';
  }
  if (
    /\b(trump|biden|putin|ukraine|gaza|nato|white house|britain|europe)\b/i.test(text)
    || /(विदेश|अंतर्राष्ट्रीय|ब्रिटेन|अमेरिका|यूक्रेन|ट्रंप|बाइडेन)/.test(text)
    || /(విదేశ|అంతర్జాతీయ|అమెరికా|ట్రంప్|బైడెన్|బ్రిటన్|యూక్రేన్)/i.test(text)
    || /international|world/.test(src)
  ) {
    return 'international';
  }
  return 'india';
}

async function main() {
  await mongoose.connect(process.env.MONGO_URI);
  const [politics, local] = await Promise.all([
    Category.findOne({ slug: 'politics' }).select('_id').lean(),
    Category.findOne({ slug: 'local' }).select('_id').lean(),
  ]);

  const cursor = NewsPost.find({
    status: 'approved',
    language: { $in: ['te', 'hi'] },
    $or: [
      { politicsScope: null },
      { politicsScope: { $exists: false } },
      { politicsScope: 'all' },
      { politicsScope: 'international' },
    ],
  })
    .select('_id title summary body sourceName language category politicsScope')
    .cursor();

  let updated = 0;
  let internationalFixed = 0;
  for await (const post of cursor) {
    const scope = inferScope(post);
    const wasInternational = String(post.politicsScope || '').toLowerCase() === 'international';
    if (wasInternational && scope !== 'international') {
      internationalFixed += 1;
    }
    if (scope !== post.politicsScope) {
      await NewsPost.updateOne({ _id: post._id }, { $set: { politicsScope: scope } });
      updated += 1;
    }
  }
  console.log('Backfilled politicsScope on', updated, 'posts');
  console.log('Re-tagged mislabeled international → regional/india:', internationalFixed);

  if (politics?._id && local?._id) {
    const moved = await NewsPost.updateMany(
      {
        category: politics._id,
        language: 'te',
        politicsScope: { $in: ['andhra', 'telangana'] },
      },
      { $set: { category: local._id } },
    );
    console.log('Moved AP/TG rows to local category:', moved.modifiedCount);
  }

  // Sanity: international chip should not surface AP/TG-only rows
  const sampleIntl = await NewsPost.find({
    status: 'approved',
    language: 'te',
    politicsScope: 'international',
  })
    .select('title summary body politicsScope')
    .limit(200)
    .lean();
  const bad = sampleIntl.filter(
    (p) => !postMatchesPoliticsScopeFilter(p, 'international'),
  );
  console.log('Telugu international rows failing scope filter:', bad.length);

  await mongoose.disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
