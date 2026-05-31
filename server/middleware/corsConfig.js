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
      return callback(new Error(`CORS blocked: ${origin}`));
    },
  };
}

function socketCorsOrigins() {
  const allowed = parseAllowedOrigins();
  if (allowed === null || allowed.includes('*')) return '*';
  return allowed.length ? allowed : false;
}

module.exports = {
  parseAllowedOrigins,
  buildCorsOptions,
  socketCorsOrigins,
};
