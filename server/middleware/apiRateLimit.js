const WINDOW_MS = 60 * 1000;
const MAX_PER_WINDOW = Math.max(
  Number(process.env.RATE_LIMIT_MAX || 100),
  1,
);
const BUCKET_TTL_MS = Math.max(
  WINDOW_MS,
  Number(process.env.RATE_LIMIT_BUCKET_TTL_MS || WINDOW_MS * 2),
);
const CLEANUP_INTERVAL_MS = Math.max(
  WINDOW_MS,
  Number(process.env.RATE_LIMIT_CLEANUP_MS || WINDOW_MS),
);

const hits = new Map();

const SKIP_PREFIXES = ['/api/health', '/api/ready'];

/** Original client IP behind proxies (leftmost in X-Forwarded-For). */
function clientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (forwarded) {
    const first = String(forwarded).split(',')[0]?.trim();
    if (first) return first;
  }
  if (req.ip) return req.ip;
  return 'global';
}

function pruneStaleBuckets() {
  const cutoff = Date.now() - BUCKET_TTL_MS;
  for (const [key, bucket] of hits) {
    if (bucket.lastSeen < cutoff) hits.delete(key);
  }
}

const cleanupTimer = setInterval(pruneStaleBuckets, CLEANUP_INTERVAL_MS);
if (typeof cleanupTimer.unref === 'function') cleanupTimer.unref();

function stopRateLimitCleanup() {
  clearInterval(cleanupTimer);
  hits.clear();
}

function shutdownHandler() {
  stopRateLimitCleanup();
}

process.once('SIGTERM', shutdownHandler);
process.once('SIGINT', shutdownHandler);

function apiRateLimit(req, res, next) {
  if (SKIP_PREFIXES.some((p) => req.path === p || req.path.startsWith(`${p}/`))) {
    return next();
  }

  const key = clientIp(req);
  const now = Date.now();
  let bucket = hits.get(key);
  if (!bucket || now - bucket.start > WINDOW_MS) {
    bucket = { start: now, count: 0, lastSeen: now };
    hits.set(key, bucket);
  }
  bucket.count += 1;
  bucket.lastSeen = now;
  if (bucket.count > MAX_PER_WINDOW) {
    res.setHeader('Retry-After', String(Math.ceil(WINDOW_MS / 1000)));
    return res.status(429).json({
      success: false,
      message: 'Too many requests. Please wait a moment.',
    });
  }
  return next();
}

module.exports = apiRateLimit;
module.exports.clientIp = clientIp;
module.exports.stopRateLimitCleanup = stopRateLimitCleanup;
module.exports._pruneStaleBuckets = pruneStaleBuckets;
