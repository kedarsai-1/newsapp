const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
const cron = require('node-cron');
require('dotenv').config();
const { runIngestion } = require('./services/newsIngestionService');
const { setIngestionSocket } = require('./services/feedSocket');
const { runYoutubeIngestion } = require('./services/youtubeIngestionService');
const { purgeOldNews } = require('./services/retentionCleanupService');
const { ensureDefaultCategories } = require('./utils/ensureDefaultData');
const { ensureNewsPostIndexes } = require('./utils/ensureNewsPostIndexes');

const authRoutes = require('./routes/auth');
const newsRoutes = require('./routes/news');
const reporterRoutes = require('./routes/reporter');
const adminRoutes = require('./routes/admin');
const categoryRoutes = require('./routes/categories');
const sportsRoutes = require('./routes/sports');

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

// Liveness — always 200 once HTTP is up (Railway health checks hit this before Mongo is ready).
app.get('/api/health', (req, res) => {
  const mongoState = mongoose.connection.readyState;
  res.json({
    status: 'OK',
    mongo: mongoState === 1 ? 'connected' : mongoState === 2 ? 'connecting' : 'disconnected',
    timestamp: new Date(),
  });
});

// Readiness — 503 until DB is ready (optional; do not point Railway healthcheck here).
app.get('/api/ready', (req, res) => {
  if (mongoose.connection.readyState === 1) {
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
const isRailway = Boolean(process.env.RAILWAY_ENVIRONMENT || process.env.RAILWAY_PROJECT_ID);

server.listen(port, () => {
  console.log(`Server listening on port ${port} (mongo connecting in background)`);
});

process.on('SIGTERM', () => {
  console.log('[shutdown] SIGTERM received, closing HTTP server…');
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 12_000).unref();
});

let backgroundJobsStarted = false;

async function runBackgroundJobs() {
  if (backgroundJobsStarted) return;
  if (mongoose.connection.readyState !== 1) return;
  backgroundJobsStarted = true;

  console.log('MongoDB connected');
  await ensureDefaultCategories();
    try {
      const { cleaned } = await ensureNewsPostIndexes();
      if (cleaned > 0) {
        console.log(`[db] removed phantom youtube field from ${cleaned} post(s)`);
      }
    } catch (e) {
      console.error('[db] NewsPost index setup failed:', e?.message || e);
    }
    // Production default: every 5 minutes (safe + fresh).
    const cronExpr = process.env.SCRAPER_CRON || '*/5 * * * *';
    const scrapingEnabled = process.env.SCRAPER_ENABLED !== 'false';
    const runOnStart =
      process.env.SCRAPER_RUN_ON_START === 'true'
      || (!isRailway && process.env.SCRAPER_RUN_ON_START !== 'false');

    // Retention cleanup (production): delete ingested news older than N days + Cloudinary assets.
    const retentionEnabled = process.env.RETENTION_ENABLED !== 'false';
    const retentionDays = Number(process.env.RETENTION_DAYS || 7);
    // Daily at 03:10 server local time (low traffic).
    const retentionCron = process.env.RETENTION_CRON || '10 3 * * *';
    const retentionRunOnStart = process.env.RETENTION_RUN_ON_START === 'true';

    async function runScheduledIngestion(triggeredBy) {
      console.log(`[scraper] ingestion start (${triggeredBy}) ${new Date().toISOString()}`);
      const result = await runIngestion({ triggeredBy });
      if (result.skipped) {
        console.log(`[scraper] skipped (${triggeredBy}): ${result.message || 'ingestion already running'}`);
        return;
      }
      if (!result.success) {
        if (result.stats?.timedOut) {
          console.warn('[scraper] time budget hit:', result.error || result.message);
        } else {
          console.error('[scraper] run failed:', result.error || result.message);
        }
      } else {
        const s = result.stats || {};
        console.log(
          `[scraper] run completed (${triggeredBy}): inserted=${s.inserted ?? 0} fetched=${s.fetched ?? 0} duplicates=${s.duplicates ?? 0} skippedNoImage=${s.skippedNoImage ?? 0} categoryFiltered=${s.categoryFiltered ?? 0} failed=${s.failed ?? 0}`,
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

    const youtubeEnabled = process.env.YOUTUBE_ENABLED !== 'false';
    const youtubeCronExpr = process.env.YOUTUBE_CRON || '*/15 * * * *';
    const youtubeRunOnStart =
      process.env.YOUTUBE_RUN_ON_START === 'true'
      || (!isRailway && process.env.YOUTUBE_RUN_ON_START !== 'false');

    async function runScheduledYoutube(triggeredBy) {
      console.log(`[youtube] ingestion start (${triggeredBy}) ${new Date().toISOString()}`);
      const result = await runYoutubeIngestion({ triggeredBy });
      if (result.skipped) {
        console.log(`[youtube] skipped (${triggeredBy}): ${result.message || ''}`);
        return;
      }
      if (!result.success) {
        console.error('[youtube] run failed:', result.error);
        return;
      }
      const s = result.stats || {};
      console.log(
        `[youtube] run completed (${triggeredBy}): inserted=${s.youtubeInserted ?? 0} `
          + `fetched=${s.youtubeFetched ?? 0} duplicates=${s.youtubeDuplicates ?? 0} `
          + `restricted=${s.youtubeSkippedRestricted ?? 0}`,
      );
      if ((s.youtubeInserted ?? 0) > 0) {
        io.to('all').emit('feed_updated', {
          inserted: s.youtubeInserted,
          at: new Date(),
        });
      }
    }

    if (youtubeEnabled && process.env.YOUTUBE_API_KEY?.trim()) {
      cron.schedule(youtubeCronExpr, () => {
        runScheduledYoutube('youtube-cron').catch((e) =>
          console.error('[youtube] scheduler error:', e),
        );
      });
      console.log(`[youtube] scheduler active with cron "${youtubeCronExpr}"`);
      if (youtubeRunOnStart) {
        setTimeout(() => {
          runScheduledYoutube('youtube-startup').catch((e) =>
            console.error('[youtube] startup error:', e),
          );
        }, 5000);
      }
    } else {
      console.log('[youtube] scheduler disabled (YOUTUBE_ENABLED=false or missing YOUTUBE_API_KEY)');
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
}

const mongoUri = process.env.MONGO_URI?.trim();
const mongoOpts = {
  serverSelectionTimeoutMS: Number(process.env.MONGO_CONNECT_TIMEOUT_MS) || 20_000,
};

function scheduleMongoConnect() {
  if (!mongoUri) return;
  mongoose
    .connect(mongoUri, mongoOpts)
    .then(() => runBackgroundJobs().catch((e) => {
      backgroundJobsStarted = false;
      console.error('[startup] background jobs failed:', e?.message || e);
    }))
    .catch((err) => {
      console.error('[mongo] connection error, retry in 10s:', err?.message || err);
      setTimeout(scheduleMongoConnect, 10_000).unref();
    });
}

if (!mongoUri) {
  console.error('[mongo] MONGO_URI is not set — API routes need a database. Set it in Railway Variables.');
} else {
  mongoose.connection.on('disconnected', () => {
    console.warn('[mongo] disconnected');
    backgroundJobsStarted = false;
  });
  mongoose.connection.on('reconnected', () => {
    console.log('[mongo] reconnected');
    runBackgroundJobs().catch((e) => console.error('[startup] background jobs failed:', e));
  });
  scheduleMongoConnect();
}

module.exports = { app, io };