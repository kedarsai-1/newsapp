const { cloudinary } = require('../config/cloudinary');

const TTL_MS = Math.max(
  60_000,
  Number(process.env.CLOUDINARY_HEALTH_TTL_MS || 15 * 60 * 1000),
);

let cached = { ok: null, reason: null, checkedAt: 0 };

function isConfigured() {
  return Boolean(
    process.env.CLOUDINARY_CLOUD_NAME?.trim()
    && process.env.CLOUDINARY_API_KEY?.trim()
    && process.env.CLOUDINARY_API_SECRET?.trim(),
  );
}

function pingCloudinary() {
  return new Promise((resolve, reject) => {
    cloudinary.api.ping((err, res) => {
      if (err) reject(err);
      else resolve(res);
    });
  });
}

/** Cached Cloudinary availability — avoids 45s upload timeouts when account is disabled. */
async function getCloudinaryHealth({ force = false } = {}) {
  if (!isConfigured()) {
    return { ok: false, reason: 'not_configured', configured: false };
  }
  if (
    !force
    && cached.checkedAt > 0
    && Date.now() - cached.checkedAt < TTL_MS
    && cached.ok != null
  ) {
    return { ok: cached.ok, reason: cached.reason, configured: true, cached: true };
  }
  try {
    await pingCloudinary();
    cached = { ok: true, reason: null, checkedAt: Date.now() };
    return { ok: true, reason: null, configured: true, cached: false };
  } catch (e) {
    const reason = String(e?.message || e || 'unavailable');
    cached = { ok: false, reason, checkedAt: Date.now() };
    return { ok: false, reason, configured: true, cached: false };
  }
}

async function isCloudinaryAvailable() {
  const h = await getCloudinaryHealth();
  return h.ok === true;
}

module.exports = {
  getCloudinaryHealth,
  isCloudinaryAvailable,
  isCloudinaryConfigured: isConfigured,
};
