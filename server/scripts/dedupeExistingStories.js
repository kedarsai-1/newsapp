/**
 * One-time cleanup: remove duplicate approved stories that share the same title fingerprint.
 * Keeps the newest row per fingerprint. Run: node server/scripts/dedupeExistingStories.js
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mongoose = require('mongoose');
const NewsPost = require('../models/NewsPost');
const { titleFingerprint } = require('../utils/storyDedupe');

async function main() {
  const uri = process.env.MONGODB_URI || process.env.MONGO_URI;
  if (!uri) {
    console.error('Missing MONGODB_URI');
    process.exit(1);
  }
  await mongoose.connect(uri);

  const posts = await NewsPost.find({ status: 'approved' })
    .select('_id title titleFingerprint createdAt')
    .lean();

  const groups = new Map();
  for (const p of posts) {
    const fp = p.titleFingerprint || titleFingerprint(p.title);
    if (!fp) continue;
    if (!groups.has(fp)) groups.set(fp, []);
    groups.get(fp).push(p);
  }

  let removed = 0;
  for (const arr of groups.values()) {
    if (arr.length < 2) continue;
    arr.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    const dropIds = arr.slice(1).map((x) => x._id);
    const res = await NewsPost.deleteMany({ _id: { $in: dropIds } });
    removed += res.deletedCount || 0;
  }

  console.log(`Removed ${removed} duplicate story rows.`);
  await mongoose.disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
