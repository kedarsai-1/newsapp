const express = require('express');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
require('dotenv').config();
const cacheService = require('./utils/cacheService');
const { prisma } = require('./config/prisma');
const { setIngestionSocket } = require('./services/feedSocket');
const { startCronScheduler } = require('./services/cronScheduler');
const { ensureDefaultCategories, ensureDefaultAdmin } = require('./utils/ensureDefaultData');
const aiProvider = require('./services/aiProvider');
const { getPushHealth } = require('./utils/notifications');
const { buildCorsOptions, socketCorsOrigins } = require('./middleware/corsConfig');
const apiRateLimit = require('./middleware/apiRateLimit');

const authRoutes = require('./routes/auth');
const newsRoutes = require('./routes/news');
const reporterRoutes = require('./routes/reporter');
const adminRoutes = require('./routes/admin');
const categoryRoutes = require('./routes/categories');
const sportsRoutes = require('./routes/sports');
const politicalVideoRoutes = require('./routes/politicalVideos');
const weatherRoutes = require('./routes/weather');
const cronRoutes = require('./routes/cron');

const app = express();
if (process.env.TRUST_PROXY === 'true' || process.env.NODE_ENV === 'production') {
  app.set('trust proxy', Number(process.env.TRUST_PROXY_HOPS || 1));
}
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: socketCorsOrigins(),
    methods: ['GET', 'POST'],
    credentials: true,
  },
});
setIngestionSocket(io);

// Middleware
app.use(cors(buildCorsOptions()));
app.use(apiRateLimit);
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));

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
app.use('/api/weather', weatherRoutes);
app.use('/api/cron', cronRoutes);

let dbReady = false;

const OLLAMA_HEALTH_TTL_MS = Math.max(
  10_000,
  Number(process.env.OLLAMA_HEALTH_TTL_MS || 60_000),
);
let ollamaHealthCache = { at: 0, payload: null };

async function buildAiHealthPayload(forceRefresh = false) {
  const provider = aiProvider.getAiProvider();
  if (!aiProvider.isOllamaProvider()) {
    return {
      provider,
      summariesEnabled: aiProvider.isAiSummaryEnabled(),
    };
  }
  const now = Date.now();
  if (
    !forceRefresh
    && ollamaHealthCache.payload
    && now - ollamaHealthCache.at < OLLAMA_HEALTH_TTL_MS
  ) {
    return ollamaHealthCache.payload;
  }
  const ping = await aiProvider.pingOllama();
  const byLang = ping.modelsByLang || {};
  const payload = {
    provider: 'ollama',
    summariesEnabled: aiProvider.isAiSummaryEnabled(),
    ok: ping.ok === true,
    modelsByLang: {
      en: byLang.en ?? 'unknown',
      hi: byLang.hi ?? 'unknown',
      te: byLang.te ?? 'unknown',
    },
    missing: ping.missing || [],
    error: ping.error || null,
  };
  ollamaHealthCache = { at: now, payload };
  return payload;
}

// Liveness — always 200 once HTTP is up (Railway health checks hit this before DB is ready).
app.get('/api/health', async (req, res) => {
  try {
    const forceAi = req.query.refresh === '1' || req.query.refresh === 'true';
    const ai = await buildAiHealthPayload(forceAi);
    res.json({
      status: 'OK',
      postgres: dbReady ? 'connected' : 'disconnected',
      ai,
      push: getPushHealth(),
      timestamp: new Date(),
    });
  } catch (err) {
    res.json({
      status: 'OK',
      postgres: dbReady ? 'connected' : 'disconnected',
      ai: { provider: aiProvider.getAiProvider(), ok: false, error: err.message },
      push: getPushHealth(),
      timestamp: new Date(),
    });
  }
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
  if (res.headersSent) return next(err);

  const { Prisma } = require('@prisma/client');
  if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2023') {
    return res.status(400).json({
      success: false,
      message: 'Invalid post id',
    });
  }

  const status = err.status || 500;
  console.error(err.stack || err.message || err);
  res.status(status).json({
    success: false,
    message: status >= 500 ? 'Internal Server Error' : (err.message || 'Internal Server Error'),
  });
});

// Socket.io events
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);
  socket.on('join_feed', (category) => socket.join(category || 'all'));
  socket.on('disconnect', () => console.log('Client disconnected:', socket.id));
});

const port = Number(process.env.PORT) || 5000;
const host = process.env.HOST?.trim() || '0.0.0.0';

server.listen(port, host, () => {
  console.log(`Server listening on ${host}:${port} (PostgreSQL connecting in background)`);
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
  await ensureDefaultAdmin();
  if (aiProvider.isOllamaProvider()) {
    const ollama = await aiProvider.pingOllama();
    if (ollama.ok) {
      const byLang = ollama.modelsByLang || {};
      const en = byLang.en ?? 'unknown';
      const hi = byLang.hi ?? 'unknown';
      const te = byLang.te ?? 'unknown';
      console.log(`[ai] Ollama ready en=${en} hi=${hi} te=${te}`);
    } else {
      const missing = (ollama.missing || []).join(', ');
      console.warn(
        '[ai] Ollama not ready — summaries fall back to extractive until models are pulled:',
        ollama.error || missing || 'unknown',
      );
    }
  } else if (aiProvider.isAiSummaryEnabled()) {
    console.log('[ai] Hugging Face inference enabled for summaries/translation');
  }
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

cacheService.init();
schedulePostgresConnect();

module.exports = { app, io };