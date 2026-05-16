const crypto = require('crypto');

/** Strip tracking params and normalize host/path for dedupe. */
function canonicalizeUrl(url) {
  if (!url || typeof url !== 'string') return null;
  try {
    const u = new URL(url.trim());
    if (!['http:', 'https:'].includes(u.protocol)) return null;
    u.hash = '';
    const drop = new Set([
      'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
      'fbclid', 'gclid', 'ref', 'referrer', 'oc', 'igshid',
    ]);
    [...u.searchParams.keys()].forEach((k) => {
      if (drop.has(k.toLowerCase()) || k.toLowerCase().startsWith('utm_')) {
        u.searchParams.delete(k);
      }
    });
    let host = u.hostname.toLowerCase();
    if (host.startsWith('www.')) host = host.slice(4);
    const path = u.pathname.replace(/\/+$/, '') || '/';
    const qs = u.searchParams.toString();
    return `${u.protocol}//${host}${path}${qs ? `?${qs}` : ''}`;
  } catch {
    return null;
  }
}

function hashUrl(url) {
  return crypto.createHash('sha256').update(url).digest('hex');
}

/** Stable title key — catches same story with punctuation/case differences. */
function normalizeTitle(title) {
  return String(title || '')
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[''`]/g, "'")
    .replace(/[^\w\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 180);
}

function titleFingerprint(title) {
  const norm = normalizeTitle(title);
  if (norm.length < 12) return null;
  return hashUrl(norm);
}

module.exports = {
  canonicalizeUrl,
  hashUrl,
  normalizeTitle,
  titleFingerprint,
};
