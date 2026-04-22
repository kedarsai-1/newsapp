/**
 * Purge all app data (DB + Cloudinary).
 *
 * - Deletes: NewsPosts, Comments, Categories
 * - Keeps: Users (so you don't lock yourself out)
 * - Cloudinary: deletes all assets under prefix "newsapp/" (images + videos)
 *
 * Run:
 *   node scripts/purgeAllData.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const NewsPost = require('../models/NewsPost');
const Comment = require('../models/Comment');
const Category = require('../models/Category');
const { cloudinary } = require('../config/cloudinary');

function isCloudinaryConfigured() {
  return Boolean(
    process.env.CLOUDINARY_CLOUD_NAME?.trim()
      && process.env.CLOUDINARY_API_KEY?.trim()
      && process.env.CLOUDINARY_API_SECRET?.trim(),
  );
}

async function deleteCloudinaryByPrefix({ prefix, resourceType }) {
  let nextCursor = null;
  let totalDeleted = 0;
  let totalListed = 0;

  function chunk(arr, size) {
    const out = [];
    for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
    return out;
  }

  for (;;) {
    // eslint-disable-next-line no-await-in-loop
    const page = await cloudinary.api.resources({
      resource_type: resourceType,
      type: 'upload',
      prefix,
      max_results: 500,
      ...(nextCursor ? { next_cursor: nextCursor } : {}),
    });

    const resources = page?.resources || [];
    totalListed += resources.length;
    const ids = resources.map((r) => r.public_id).filter(Boolean);

    if (ids.length) {
      // Cloudinary allows max 100 public_ids per delete request.
      const batches = chunk(ids, 100);
      for (const batch of batches) {
        // eslint-disable-next-line no-await-in-loop
        const out = await cloudinary.api.delete_resources(batch, {
          resource_type: resourceType,
          type: 'upload',
          invalidate: true,
        });
        const deleted = Object.values(out?.deleted || {}).filter((v) => v === 'deleted').length;
        totalDeleted += deleted;
      }
    }

    nextCursor = page?.next_cursor || null;
    if (!nextCursor) break;
  }

  return { listed: totalListed, deleted: totalDeleted };
}

async function main() {
  if (!process.env.MONGO_URI?.trim()) {
    throw new Error('Missing MONGO_URI in environment.');
  }

  console.log('[purge] connecting to MongoDB...');
  await mongoose.connect(process.env.MONGO_URI);
  console.log('[purge] connected');

  console.log('[purge] deleting Cloudinary assets under prefix "newsapp/"...');
  if (isCloudinaryConfigured()) {
    const img = await deleteCloudinaryByPrefix({ prefix: 'newsapp/', resourceType: 'image' });
    const vid = await deleteCloudinaryByPrefix({ prefix: 'newsapp/', resourceType: 'video' });
    console.log(`[purge] cloudinary images: listed=${img.listed} deleted=${img.deleted}`);
    console.log(`[purge] cloudinary videos: listed=${vid.listed} deleted=${vid.deleted}`);
  } else {
    console.log('[purge] cloudinary not configured; skipping asset deletion');
  }

  console.log('[purge] deleting DB collections (posts/comments/categories)...');
  const [posts, comments, categories] = await Promise.all([
    NewsPost.deleteMany({}),
    Comment.deleteMany({}),
    Category.deleteMany({}),
  ]);
  console.log(`[purge] posts deleted: ${posts.deletedCount ?? 0}`);
  console.log(`[purge] comments deleted: ${comments.deletedCount ?? 0}`);
  console.log(`[purge] categories deleted: ${categories.deletedCount ?? 0}`);

  await mongoose.disconnect();
  console.log('[purge] done');
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    // Avoid logging full Cloudinary request options (can contain secrets).
    const msg = e?.error?.message || e?.message || 'Unknown error';
    const code = e?.error?.http_code || e?.http_code || null;
    console.error('[purge] failed:', code ? `${msg} (http ${code})` : msg);
    process.exit(1);
  });

