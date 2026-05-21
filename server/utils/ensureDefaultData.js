const { prisma } = require('../config/prisma');
const { defaultCategories } = require('../config/defaultCategories');

/**
 * After a wiped DB, scraping needs at least one active category (ideally slug `general`).
 */
async function ensureDefaultCategories() {
  const count = await prisma.category.count();
  if (count === 0) {
    await prisma.category.createMany({ data: defaultCategories, skipDuplicates: true });
    console.log(`[db] Seeded ${defaultCategories.length} default categories (database had none).`);
    return;
  }

  const existing = await prisma.category.findMany({ select: { slug: true } });
  const existingSlugs = new Set(existing.map((c) => String(c.slug || '').toLowerCase()).filter(Boolean));
  const missing = defaultCategories.filter((c) => !existingSlugs.has(String(c.slug).toLowerCase()));
  if (missing.length) {
    await prisma.category.createMany({ data: missing, skipDuplicates: true });
    console.log(`[db] Added missing categories: ${missing.map((c) => c.slug).join(', ')}`);
  }
}

module.exports = { ensureDefaultCategories };
