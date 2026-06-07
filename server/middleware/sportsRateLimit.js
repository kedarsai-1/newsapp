const WINDOW_MS = 60 * 1000;
const MAX_PER_WINDOW = Number(process.env.SPORTS_RATE_LIMIT_PER_MIN) || 120;
const { createRateLimitStore } = require('../utils/rateLimitStore');

const store = createRateLimitStore();

function sportsRateLimit(req, res, next) {
  const key = req.ip || req.headers['x-forwarded-for'] || 'global';
  if (!store.hit(key, MAX_PER_WINDOW)) {
    return res.status(429).json({
      success: false,
      message: 'Too many sports requests. Please wait a moment.',
    });
  }
  return next();
}

module.exports = sportsRateLimit;
