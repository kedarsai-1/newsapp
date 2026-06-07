const bcrypt = require('bcryptjs');
const { prisma } = require('../config/prisma');
const { defaultCategories } = require('../config/defaultCategories');

const DEFAULT_ADMIN_EMAIL = 'admin@newsapp.com';

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

/**
 * Idempotent admin provisioning for fresh production databases.
 * Password from ADMIN_SEED_PASSWORD or the documented dev default.
 */
async function ensureDefaultAdmin() {
  const existing = await prisma.user.findUnique({ where: { email: DEFAULT_ADMIN_EMAIL } });
  if (existing) return false;

  const plainPassword = String(process.env.ADMIN_SEED_PASSWORD || 'Admin@123').trim();
  if (!plainPassword) {
    console.warn('[db] ADMIN_SEED_PASSWORD is empty; skipping default admin creation.');
    return false;
  }

  await prisma.user.create({
    data: {
      name: 'Super Admin',
      email: DEFAULT_ADMIN_EMAIL,
      password: await bcrypt.hash(plainPassword, 10),
      role: 'admin',
      isActive: true,
      isVerified: true,
    },
  });
  console.log(
    `[db] Created default admin (${DEFAULT_ADMIN_EMAIL}). Set ADMIN_SEED_PASSWORD and change password after first login.`,
  );
  return true;
}

module.exports = { ensureDefaultCategories, ensureDefaultAdmin, DEFAULT_ADMIN_EMAIL };
