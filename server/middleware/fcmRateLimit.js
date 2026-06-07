const WINDOW_MS = 60 * 1000;
const MAX_FCM_PER_WINDOW = Math.max(
  1,
  Number(process.env.FCM_TOKEN_RATE_LIMIT_MAX || 10),
);
const { createRateLimitStore } = require('../utils/rateLimitStore');

const store = createRateLimitStore();

function clientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (forwarded) {
    const first = String(forwarded).split(',')[0]?.trim();
    if (first) return first;
  }
  return req.ip || 'global';
}

function fcmRateLimit(req, res, next) {
  const key = `${clientIp(req)}:${req.user?._id || 'anon'}`;
  if (!store.hit(key, MAX_FCM_PER_WINDOW)) {
    res.setHeader('Retry-After', String(Math.ceil(WINDOW_MS / 1000)));
    return res.status(429).json({
      success: false,
      message: 'Too many FCM token updates. Please wait a moment.',
    });
  }
  return next();
}

module.exports = fcmRateLimit;
