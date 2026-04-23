const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
const cron = require('node-cron');
require('dotenv').config();
const { runIngestion } = require('./services/newsIngestionService');
const { purgeOldNews } = require('./services/retentionCleanupService');
const { ensureDefaultCategories } = require('./utils/ensureDefaultData');

const authRoutes = require('./routes/auth');
const newsRoutes = require('./routes/news');
const reporterRoutes = require('./routes/reporter');
const adminRoutes = require('./routes/admin');
const categoryRoutes = require('./routes/categories');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] }
});

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

// Health check
app.get('/api/health', (req, res) => res.json({ status: 'OK', timestamp: new Date() }));

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

// MongoDB connection
mongoose.connect(process.env.MONGO_URI)
  .then(async () => {
    console.log('MongoDB connected');
    await ensureDefaultCategories();
    // Production default: every 5 minutes (safe + fresh).
    const cronExpr = process.env.SCRAPER_CRON || '*/5 * * * *';
    const scrapingEnabled = process.env.SCRAPER_ENABLED !== 'false';
    const runOnStart = process.env.SCRAPER_RUN_ON_START !== 'false';

    // Retention cleanup (production): delete ingested news older than N days + Cloudinary assets.
    const retentionEnabled = process.env.RETENTION_ENABLED !== 'false';
    const retentionDays = Number(process.env.RETENTION_DAYS || 7);
    // Daily at 03:10 server local time (low traffic).
    const retentionCron = process.env.RETENTION_CRON || '10 3 * * *';
    const retentionRunOnStart = process.env.RETENTION_RUN_ON_START === 'true';

    async function runScheduledIngestion(triggeredBy) {
      console.log(`[scraper] ingestion start (${triggeredBy}) ${new Date().toISOString()}`);
      const result = await runIngestion({ triggeredBy });
      if (!result.success && !result.skipped) {
        console.error('[scraper] run failed:', result.error || result.message);
      } else {
        const s = result.stats || {};
        console.log(
          `[scraper] run completed (${triggeredBy}): inserted=${s.inserted ?? 0} fetched=${s.fetched ?? 0} duplicates=${s.duplicates ?? 0} failed=${s.failed ?? 0}`,
        );
        if (s.sourceRuns?.length) {
          console.log('[scraper] details:', JSON.stringify(s.sourceRuns));
        }
      }
    }

    if (scrapingEnabled) {
      cron.schedule(cronExpr, () => {
        runScheduledIngestion('scheduler').catch((e) =>
          console.error('[scraper] scheduler error:', e),
        );
      });
      console.log(
        `[scraper] scheduler active with cron "${cronExpr}" (node-cron uses server local time)`,
      );

      // Cron does NOT run immediately — wait up to one interval for first fetch.
      // Run once after startup so new GNews/NewsAPI posts appear without waiting.
      if (runOnStart) {
        setTimeout(() => {
          runScheduledIngestion('startup').catch((e) =>
            console.error('[scraper] startup ingestion error:', e),
          );
        }, 2500);
        console.log('[scraper] will run ingestion once ~2s after startup (set SCRAPER_RUN_ON_START=false to disable)');
      }
    } else {
      console.log('[scraper] scheduler disabled by SCRAPER_ENABLED=false');
    }

    async function runRetention(triggeredBy) {
      try {
        const out = await purgeOldNews({
          retentionDays,
          limit: Number(process.env.RETENTION_BATCH || 2000),
          keepManual: true,
          dryRun: process.env.RETENTION_DRY_RUN === 'true',
        });
        console.log(
          `[retention] ${triggeredBy}: matched=${out.matched} deleted=${out.deletedPosts} cutoff=${out.cutoff.toISOString()}`,
        );
        if (out.matched) {
          console.log(
            `[retention] cloudinary images: attempted=${out.cloudinary.images.attempted} deleted=${out.cloudinary.images.deleted} skipped=${Boolean(out.cloudinary.images.skipped)}`,
          );
          console.log(
            `[retention] cloudinary videos: attempted=${out.cloudinary.videos.attempted} deleted=${out.cloudinary.videos.deleted} skipped=${Boolean(out.cloudinary.videos.skipped)}`,
          );
        }
      } catch (e) {
        console.error('[retention] failed:', e);
      }
    }

    if (retentionEnabled) {
      cron.schedule(retentionCron, () => runRetention('scheduler'));
      console.log(`[retention] active with cron "${retentionCron}" days=${retentionDays}`);
      if (retentionRunOnStart) {
        setTimeout(() => runRetention('startup'), 4500);
        console.log('[retention] will run once on startup (RETENTION_RUN_ON_START=true)');
      }
    } else {
      console.log('[retention] disabled by RETENTION_ENABLED=false');
    }

    // Bind on all interfaces so PaaS proxies (Railway, Render) can reach the app — localhost-only causes 502.
    const port = Number(process.env.PORT) || 5000;
    server.listen(port, '0.0.0.0', () => {
      console.log(`Server running on 0.0.0.0:${port}`);
    });
  })
  .catch((err) => {
    console.error('MongoDB connection error:', err);
    process.exit(1);
  });

module.exports = { app, io };