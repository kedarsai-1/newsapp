const { createRateLimitStore } = require('../utils/rateLimitStore');

const TARGET_WINDOW_MS = 15 * 60 * 1000;
const IP_WINDOW_MS = 60 * 60 * 1000;
const MAX_PER_TARGET = Math.max(
  1,
  Number(process.env.OTP_RATE_LIMIT_PER_TARGET || 3),
);
const MAX_PER_IP = Math.max(
  1,
  Number(process.env.OTP_RATE_LIMIT_PER_IP || 10),
);

const targetStore = createRateLimitStore({ windowMs: TARGET_WINDOW_MS });
const ipStore = createRateLimitStore({ windowMs: IP_WINDOW_MS });

function clientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (forwarded) {
    const first = String(forwarded).split(',')[0]?.trim();
    if (first) return first;
  }
  return req.ip || 'global';
}

function otpRateLimit(req, res, next) {
  const ip = clientIp(req);
  if (!ipStore.hit(`otp:ip:${ip}`, MAX_PER_IP)) {
    res.setHeader('Retry-After', String(Math.ceil(IP_WINDOW_MS / 1000)));
    return res.status(429).json({
      success: false,
      message: 'Too many OTP requests from this network. Please try again later.',
    });
  }

  const target = String(req.body?.target || '').trim().toLowerCase();
  if (target && !targetStore.hit(`otp:t:${target}`, MAX_PER_TARGET)) {
    res.setHeader('Retry-After', String(Math.ceil(TARGET_WINDOW_MS / 1000)));
    return res.status(429).json({
      success: false,
      message: 'Too many OTP requests for this number or email. Please wait before retrying.',
    });
  }

  return next();
}

module.exports = otpRateLimit;
