const express = require('express');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
require('dotenv').config();
const { prisma } = require('./config/prisma');
const { setIngestionSocket } = require('./services/feedSocket');
const { startCronScheduler } = require('./services/cronScheduler');
const { ensureDefaultCategories } = require('./utils/ensureDefaultData');

const authRoutes = require('./routes/auth');
const newsRoutes = require('./routes/news');
const reporterRoutes = require('./routes/reporter');
const adminRoutes = require('./routes/admin');
const categoryRoutes = require('./routes/categories');
const sportsRoutes = require('./routes/sports');
const politicalVideoRoutes = require('./routes/politicalVideos');
const cronRoutes = require('./routes/cron');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] }
});
setIngestionSocket(io);

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Attach io to requests so controllers can emit events
app.use((req, res, next) => {
  req.io = io;
  next();
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/news', newsRoutes);
app.use('/api/reporter', reporterRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/categories', categoryRoutes);
app.use('/api/sports', sportsRoutes);
app.use('/api/political-videos', politicalVideoRoutes);
app.use('/api/cron', cronRoutes);

let dbReady = false;

// Liveness — always 200 once HTTP is up (Railway health checks hit this before DB is ready).
app.get('/api/health', (req, res) => {
  res.json({
    status: 'OK',
    postgres: dbReady ? 'connected' : 'disconnected',
    timestamp: new Date(),
  });
});

// Readiness — 503 until DB is ready (optional; do not point Railway healthcheck here).
app.get('/api/ready', (req, res) => {
  if (dbReady) {
    return res.json({ ready: true, timestamp: new Date() });
  }
  return res.status(503).json({ ready: false, timestamp: new Date() });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal Server Error'
  });
});

// Socket.io events
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);
  socket.on('join_feed', (category) => socket.join(category || 'all'));
  socket.on('disconnect', () => console.log('Client disconnected:', socket.id));
});

const port = Number(process.env.PORT) || 5000;

server.listen(port, () => {
  console.log(`Server listening on port ${port} (PostgreSQL connecting in background)`);
});

process.on('SIGTERM', () => {
  console.log('[shutdown] SIGTERM received, closing HTTP server…');
  server.close(() => {
    prisma.$disconnect().finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 12_000).unref();
});

let backgroundJobsStarted = false;

async function runBackgroundJobs() {
  if (backgroundJobsStarted) return;
  if (!dbReady) return;
  backgroundJobsStarted = true;

  console.log('PostgreSQL connected');
  await ensureDefaultCategories();
  startCronScheduler();
}

async function schedulePostgresConnect() {
  if (!process.env.DATABASE_URL?.trim()) {
    console.error('[db] DATABASE_URL is not set. Set it in Railway Variables or server/.env.');
    return;
  }
  try {
    await prisma.$connect();
    await prisma.$queryRaw`SELECT 1`;
    dbReady = true;
    await runBackgroundJobs();
  } catch (err) {
    dbReady = false;
    backgroundJobsStarted = false;
    console.error('[db] PostgreSQL connection error, retry in 10s:', err?.message || err);
    setTimeout(schedulePostgresConnect, 10_000).unref();
  }
}

schedulePostgresConnect();

module.exports = { app, io };