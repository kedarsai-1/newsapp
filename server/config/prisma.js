const { PrismaClient, Prisma } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');

const connectionString = process.env.DATABASE_URL?.trim();

if (!connectionString) {
  console.warn('[db] DATABASE_URL is not set. PostgreSQL-backed routes will fail until it is configured.');
}

const adapter = new PrismaPg({
  connectionString: connectionString || 'postgresql://postgres:postgres@localhost:5432/news_app',
});

const prisma = new PrismaClient({
  adapter,
  log: process.env.PRISMA_QUERY_LOG === 'true' ? ['query', 'error', 'warn'] : ['error', 'warn'],
});

module.exports = { prisma, Prisma };
