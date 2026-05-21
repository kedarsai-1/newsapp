const { prisma } = require('./prisma');

const connectDB = async () => {
  try {
    await prisma.$connect();
    await prisma.$queryRaw`SELECT 1`;
    console.log('PostgreSQL connected');
    return prisma;
  } catch (error) {
    console.error('Database connection failed:', error.message);
    process.exit(1);
  }
};

module.exports = connectDB;