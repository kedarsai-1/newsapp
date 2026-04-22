const Category = require('../models/Category');
const { defaultCategories } = require('../config/defaultCategories');

/**
 * After a wiped DB, scraping needs at least one active category (ideally slug `general`).
 */
async function ensureDefaultCategories() {
  const count = await Category.countDocuments();
  if (count === 0) {
    await Category.insertMany(defaultCategories);
    console.log(`[db] Seeded ${defaultCategories.length} default categories (database had none).`);
    return;
  }

  const existing = await Category.find({}, 'slug').lean();
  const existingSlugs = new Set(existing.map((c) => String(c.slug || '').toLowerCase()).filter(Boolean));
  const missing = defaultCategories.filter((c) => !existingSlugs.has(String(c.slug).toLowerCase()));
  if (missing.length) {
    await Category.insertMany(missing);
    console.log(`[db] Added missing categories: ${missing.map((c) => c.slug).join(', ')}`);
  }
}

module.exports = { ensureDefaultCategories };
