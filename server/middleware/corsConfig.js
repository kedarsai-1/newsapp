/**
 * CORS allowlist from ALLOWED_ORIGINS (comma or || separated).
 * Entries without a scheme get http:// and https:// variants.
 * Unset in development → reflect any origin. Unset in production → block cross-origin.
 */

function normalizeOriginEntry(entry) {
  const t = String(entry || '').trim();
  if (!t) return [];
  if (t === '*') return ['*'];
  if (/^https?:\/\//i.test(t)) return [t.replace(/\/$/, '')];
  const host = t.replace(/\/$/, '');
  return [`http://${host}`, `https://${host}`];
}

function parseAllowedOrigins() {
  const raw = process.env.ALLOWED_ORIGINS?.trim();
  if (!raw) {
    return process.env.NODE_ENV === 'production' ? [] : null;
  }
  const parts = raw.split(/\|\||[,;]/).map((s) => s.trim()).filter(Boolean);
  const set = new Set();
  for (const part of parts) {
    for (const o of normalizeOriginEntry(part)) {
      if (o === '*') return ['*'];
      set.add(o);
    }
  }
  return [...set];
}

function isLocalDevOrigin(origin) {
  if (!origin || process.env.CORS_ALLOW_LOCALHOST === 'false') return false;
  // Production: require explicit opt-in (avoids open CORS to any localhost port).
  if (
    process.env.NODE_ENV === 'production'
    && process.env.CORS_ALLOW_LOCALHOST !== 'true'
  ) {
    return false;
  }
  try {
    const { hostname, protocol } = new URL(origin);
    if (protocol !== 'http:' && protocol !== 'https:') return false;
    return hostname === 'localhost' || hostname === '127.0.0.1';
  } catch {
    return false;
  }
}

function buildCorsOptions() {
  const allowed = parseAllowedOrigins();

  if (allowed === null) {
    return { origin: true, credentials: true };
  }

  if (allowed.length === 0) {
    return {
      origin: false,
      credentials: true,
    };
  }

  if (allowed.includes('*')) {
    return { origin: true, credentials: true };
  }

  const allowSet = new Set(allowed);
  return {
    credentials: true,
    origin(origin, callback) {
      if (!origin) return callback(null, true);
      if (allowSet.has(origin)) return callback(null, true);
      if (isLocalDevOrigin(origin)) return callback(null, true);
      return callback(new Error(`CORS blocked: ${origin}`));
    },
  };
}

function socketCorsOrigins() {
  const allowed = parseAllowedOrigins();
  if (allowed === null || allowed.includes('*')) return '*';
  if (!allowed.length) return false;

  const allowSet = new Set(allowed);
  return (origin, callback) => {
    if (!origin) return callback(null, true);
    if (allowSet.has(origin)) return callback(null, true);
    if (isLocalDevOrigin(origin)) return callback(null, true);
    return callback(new Error(`CORS blocked: ${origin}`));
  };
}

module.exports = {
  parseAllowedOrigins,
  buildCorsOptions,
  socketCorsOrigins,
  isLocalDevOrigin,
};
