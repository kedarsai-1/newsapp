const WINDOW_MS = 60 * 1000;
const MAX_PER_WINDOW = Math.max(
  Number(process.env.RATE_LIMIT_MAX || 200),
  1,
);
const MAX_READ_PER_WINDOW = Math.max(
  Number(process.env.RATE_LIMIT_READ_MAX || 600),
  MAX_PER_WINDOW,
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

const READ_GET_PREFIXES = [
  '/api/news/feed',
  '/api/news/local',
  '/api/categories',
  '/api/political-videos/feed',
  '/api/sports/live',
  '/api/sports/news',
  '/api/sports/leaderboard',
  '/api/weather',
];

const READ_GET_PATH_RE = /^\/api\/news\/[0-9a-f-]{36}$/i;

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

function requestPath(req) {
  const raw = req.path || req.url || '';
  return String(raw).split('?')[0];
}

function isReadHeavyRequest(req) {
  const method = String(req.method || 'GET').toUpperCase();
  if (method !== 'GET' && method !== 'HEAD') return false;
  const path = requestPath(req);
  if (READ_GET_PREFIXES.some((p) => path === p || path.startsWith(`${p}/`))) return true;
  return READ_GET_PATH_RE.test(path);
}

function rateLimitKey(req) {
  const ip = clientIp(req);
  return isReadHeavyRequest(req) ? `${ip}:read` : `${ip}:write`;
}

function maxForRequest(req) {
  return isReadHeavyRequest(req) ? MAX_READ_PER_WINDOW : MAX_PER_WINDOW;
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

  const key = rateLimitKey(req);
  const limit = maxForRequest(req);
  const now = Date.now();
  let bucket = hits.get(key);
  if (!bucket || now - bucket.start > WINDOW_MS) {
    bucket = { start: now, count: 0, lastSeen: now };
    hits.set(key, bucket);
  }
  bucket.count += 1;
  bucket.lastSeen = now;
  if (bucket.count > limit) {
    res.setHeader('Retry-After', String(Math.ceil(WINDOW_MS / 1000)));
    res.setHeader('X-RateLimit-Limit', String(limit));
    res.setHeader('X-RateLimit-Remaining', '0');
    return res.status(429).json({
      success: false,
      message: 'Too many requests. Please wait a moment.',
    });
  }
  res.setHeader('X-RateLimit-Limit', String(limit));
  res.setHeader('X-RateLimit-Remaining', String(Math.max(0, limit - bucket.count)));
  return next();
}

module.exports = apiRateLimit;
module.exports.clientIp = clientIp;
module.exports.isReadHeavyRequest = isReadHeavyRequest;
module.exports.maxForRequest = maxForRequest;
module.exports.stopRateLimitCleanup = stopRateLimitCleanup;
module.exports._pruneStaleBuckets = pruneStaleBuckets;
