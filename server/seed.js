// Run with: npm run seed  OR  node seed.js
require('dotenv').config();
const bcrypt = require('bcryptjs');

const { prisma } = require('./config/prisma');
const { defaultCategories } = require('./config/defaultCategories');

const seed = async () => {
  try {
    await prisma.$connect();
    console.log('Connected to PostgreSQL');

    await prisma.category.deleteMany({});
    await prisma.category.createMany({ data: defaultCategories, skipDuplicates: true });
    console.log(`Seeded ${defaultCategories.length} categories`);

    const existing = await prisma.user.findUnique({ where: { email: 'admin@newsapp.com' } });
    if (!existing) {
      await prisma.user.create({
        data: {
          name: 'Super Admin',
          email: 'admin@newsapp.com',
          password: await bcrypt.hash('Admin@123', 10),
          role: 'admin',
          isActive: true,
          isVerified: true,
        },
      });
      console.log('Admin user created: admin@newsapp.com / Admin@123');
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
