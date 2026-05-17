const WINDOW_MS = 60 * 1000;
const MAX_PER_WINDOW = Number(process.env.SPORTS_RATE_LIMIT_PER_MIN) || 120;

const hits = new Map();

function sportsRateLimit(req, res, next) {
  const key = req.ip || req.headers['x-forwarded-for'] || 'global';
  const now = Date.now();
  let bucket = hits.get(key);
  if (!bucket || now - bucket.start > WINDOW_MS) {
    bucket = { start: now, count: 0 };
    hits.set(key, bucket);
  }
  bucket.count += 1;
  if (bucket.count > MAX_PER_WINDOW) {
    return res.status(429).json({
      success: false,
      message: 'Too many sports requests. Please wait a moment.',
    });
  }
  return next();
}

module.exports = sportsRateLimit;
