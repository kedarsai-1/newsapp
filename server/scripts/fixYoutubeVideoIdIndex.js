/**
 * One-off: drop broken youtube.videoId unique index, unset phantom youtube blobs, recreate index.
 * Run: node scripts/fixYoutubeVideoIdIndex.js
 */
require('dotenv').config();
const mongoose = require('mongoose');
const { ensureNewsPostIndexes } = require('../utils/ensureNewsPostIndexes');

async function main() {
  await mongoose.connect(process.env.MONGO_URI);
  const { cleaned } = await ensureNewsPostIndexes();
  console.log(`Done. Cleaned ${cleaned} document(s).`);
  await mongoose.disconnect();
}

main().catch((e) => {
  console.error(e?.message || e);
  process.exit(1);
});
