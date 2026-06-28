const { createRateLimitStore } = require('../utils/rateLimitStore');

const WINDOW_MS = 60 * 60 * 1000;
const MAX_PER_IP = Math.max(
  1,
  Number(process.env.REPORT_RATE_LIMIT_PER_IP || 20),
);
const MAX_PER_POST_IP = Math.max(
  1,
  Number(process.env.REPORT_RATE_LIMIT_PER_POST_IP || 2),
);

const ipStore = createRateLimitStore({ windowMs: WINDOW_MS });
const postIpStore = createRateLimitStore({ windowMs: WINDOW_MS });

function clientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (forwarded) {
    const first = String(forwarded).split(',')[0]?.trim();
    if (first) return first;
  }
  return req.ip || 'global';
}

function reportRateLimit(req, res, next) {
  if (req.user?.id || req.user?._id) {
    return next();
  }

  const ip = clientIp(req);
  const postId = String(req.params?.id || '').trim().toLowerCase();

  if (!ipStore.hit(`report:ip:${ip}`, MAX_PER_IP)) {
    res.setHeader('Retry-After', String(Math.ceil(WINDOW_MS / 1000)));
    return res.status(429).json({
      success: false,
      message: 'Too many reports from this network. Please try again later.',
    });
  }

  if (
    postId
    && !postIpStore.hit(`report:post:${postId}:${ip}`, MAX_PER_POST_IP)
  ) {
    res.setHeader('Retry-After', String(Math.ceil(WINDOW_MS / 1000)));
    return res.status(429).json({
      success: false,
      message: 'You already reported this story recently.',
    });
  }

  return next();
}

module.exports = reportRateLimit;
