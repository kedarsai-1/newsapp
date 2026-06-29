require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

const connectionString = process.env.DATABASE_URL?.trim();
const adapter = new PrismaPg({ connectionString });
const prisma = new PrismaClient({ adapter, log: ['error', 'warn'] });

async function migrate() {
  try {
    await prisma.$connect();
    console.log('Connected to DB');

    const result = await prisma.newsPost.updateMany({
      where: {
        OR: [
          { sourceName: { contains: 'Mathrubhumi', mode: 'insensitive' } },
          { sourceName: { contains: 'Manorama', mode: 'insensitive' } },
          { sourceName: { contains: 'Madhyamam', mode: 'insensitive' } },
          { sourceName: { contains: 'Reporter Malayalam', mode: 'insensitive' } },
          { sourceName: { contains: 'Asianet', mode: 'insensitive' } },
        ],
        language: 'en',
      },
      data: { language: 'ml', originalLanguage: 'mal' },
    });

    console.log('Updated', result.count, 'ml posts');
    await prisma.$disconnect();
    process.exit(0);
  } catch (e) {
    console.error('Migration failed:', e.message);
    await prisma.$disconnect();
    process.exit(1);
  }
}

migrate();
