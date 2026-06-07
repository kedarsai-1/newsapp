// Run with: npm run seed  OR  node seed.js
require('dotenv').config();
const bcrypt = require('bcryptjs');

const { prisma } = require('./config/prisma');
const { defaultCategories } = require('./config/defaultCategories');
const { ensureDefaultAdmin, ensureDefaultCategories, DEFAULT_ADMIN_EMAIL } = require('./utils/ensureDefaultData');

const seed = async () => {
  try {
    await prisma.$connect();
    console.log('Connected to PostgreSQL');

    await ensureDefaultCategories();
    console.log(`Ensured ${defaultCategories.length} default categories (additive)`);

    const created = await ensureDefaultAdmin();
    if (created) {
      console.log(`Admin user created: ${DEFAULT_ADMIN_EMAIL} (password from ADMIN_SEED_PASSWORD or Admin@123)`);
    } else {
      console.log('Admin user already exists');
    }

    const reporter = await prisma.user.findUnique({ where: { email: 'reporter@newsapp.com' } });
    if (!reporter) {
      await prisma.user.create({
        data: {
          name: 'Sample Reporter',
          email: 'reporter@newsapp.com',
          password: await bcrypt.hash('Reporter@123', 10),
          role: 'reporter',
          isActive: true,
          isVerified: true,
        },
      });
      console.log('Reporter created: reporter@newsapp.com / Reporter@123');
    }

    console.log('\nDatabase seeded successfully!');
    process.exit(0);
  } catch (err) {
    console.error('Seed error:', err);
    await prisma.$disconnect().catch(() => {});
    process.exit(1);
  }
};

seed();
