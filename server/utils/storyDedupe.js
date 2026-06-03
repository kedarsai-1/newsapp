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

/** Stable title key — catches same story with punctuation/case differences (en/te/hi). */
function normalizeTitle(title) {
  const raw = String(title || '').toLowerCase().trim();
  if (!raw) return '';

  if (/[\u0900-\u097F]/.test(raw)) {
    return raw
      .normalize('NFC')
      .replace(/[^\u0900-\u097F0-9\s]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .slice(0, 180);
  }
  if (/[\u0C00-\u0C7F]/.test(raw)) {
    return raw
      .normalize('NFC')
      .replace(/[^\u0C00-\u0C7F0-9\s]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .slice(0, 180);
  }

  return raw
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
  if (norm.length < 8) return null;
  return hashUrl(norm);
}

/** Normalized AI/RSS summary text for cross-source duplicate detection. */
function normalizeSummary(summary) {
  const raw = String(summary || '').toLowerCase().trim();
  if (!raw) return '';
  if (/[\u0900-\u097F]/.test(raw)) {
    return raw
      .normalize('NFC')
      .replace(/[^\u0900-\u097F0-9\s]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .slice(0, 220);
  }
  if (/[\u0C00-\u0C7F]/.test(raw)) {
    return raw
      .normalize('NFC')
      .replace(/[^\u0C00-\u0C7F0-9\s]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .slice(0, 220);
  }
  return raw
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^\w\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 220);
}

function summaryFingerprint(summary) {
  const norm = normalizeSummary(summary);
  if (norm.length < 40) return null;
  return hashUrl(norm);
}

function summaryWordSet(summary) {
  const norm = normalizeSummary(summary);
  if (norm.length < 40) return new Set();
  return new Set(norm.split(/\s+/).filter((w) => w.length > 2));
}

function summariesAreNearDuplicates(a, b) {
  const A = summaryWordSet(a);
  const B = summaryWordSet(b);
  if (A.size < 6 || B.size < 6) return false;
  let inter = 0;
  for (const w of A) {
    if (B.has(w)) inter += 1;
  }
  return inter / Math.min(A.size, B.size) >= 0.68;
}

function titleWordSet(title) {
  const norm = normalizeTitle(title);
  if (!norm) return new Set();
  return new Set(norm.split(/\s+/).filter((w) => w.length > 2));
}

function titlesAreNearDuplicates(a, b) {
  const A = titleWordSet(a);
  const B = titleWordSet(b);
  if (A.size < 4 || B.size < 4) return false;
  let inter = 0;
  for (const w of A) {
    if (B.has(w)) inter += 1;
  }
  return inter / Math.min(A.size, B.size) >= 0.72;
}

module.exports = {
  canonicalizeUrl,
  hashUrl,
  normalizeTitle,
  titleFingerprint,
  normalizeSummary,
  summaryFingerprint,
  summariesAreNearDuplicates,
  titlesAreNearDuplicates,
};
