const NewsPost = require('../models/NewsPost');

/**
 * Fix legacy rows where Mongoose materialized `youtube: { videoId: null, ... }` on every
 * insert, breaking the unique sparse index and blocking RSS/API ingestion.
 */
async function cleanupPhantomYoutubeFields() {
  const result = await NewsPost.updateMany(
    {
      $or: [
        { sourceType: { $ne: 'youtube' } },
        { 'youtube.videoId': { $in: [null, ''] } },
        { 'youtube.videoId': { $exists: false } },
      ],
    },
    { $unset: { youtube: '' } },
  );
  return result.modifiedCount ?? result.nModified ?? 0;
}

async function ensureNewsPostIndexes() {
  const collection = NewsPost.collection;

  try {
    await collection.dropIndex('youtube.videoId_1');
  } catch (err) {
    const code = err?.code;
    const msg = String(err?.message || '');
    if (code !== 27 && !msg.includes('index not found') && !msg.includes('ns not found')) {
      throw err;
    }
  }

  const cleaned = await cleanupPhantomYoutubeFields();

  await collection.createIndex(
    { 'youtube.videoId': 1 },
    {
      unique: true,
      name: 'youtube.videoId_1',
      partialFilterExpression: {
        'youtube.videoId': { $type: 'string', $gt: '' },
      },
    },
  );

  return { cleaned };
}

module.exports = {
  ensureNewsPostIndexes,
  cleanupPhantomYoutubeFields,
};
