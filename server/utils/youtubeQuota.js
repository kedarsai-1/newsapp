const fs = require('fs');
const path = require('path');

const COOLDOWN_FILE = path.join(__dirname, '..', '.youtube-quota-until');
const SEARCH_COOLDOWN_FILE = path.join(__dirname, '..', '.youtube-search-quota-until');
let blockedUntilMs = null;
let searchBlockedUntilMs = null;

function readBlockedUntilFromDisk(filePath) {
  try {
    const raw = fs.readFileSync(filePath, 'utf8').trim();
    const ms = Number(raw);
    if (Number.isFinite(ms) && ms > Date.now()) return ms;
  } catch {
    /* no file */
  }
  return null;
}

function writeBlockedUntilToDisk(filePath, ms) {
  try {
    fs.writeFileSync(filePath, String(ms), 'utf8');
  } catch {
    /* ignore on read-only deploy */
  }
}

/** Search-only daily cap (100 queries/day) — channel uploads can still work. */
function isYoutubeSearchQuotaError(err) {
  const msg = String(err?.message || err || '').toLowerCase();
  if (msg.includes('search queries') && msg.includes('quota')) return true;
  const reasons = err?.youtubeReasons || err?.reasons;
  if (Array.isArray(reasons) && reasons.some((r) => String(r).toLowerCase() === 'quotaexceeded')) {
    return msg.includes('search');
  }
  return false;
}

function isYoutubeQuotaError(err) {
  if (isYoutubeSearchQuotaError(err)) return false;
  const msg = String(err?.message || err || '').toLowerCase();
  if (
    msg.includes('quotaexceeded')
    || (msg.includes('quota') && msg.includes('exceeded'))
  ) {
    return true;
  }
  const reasons = err?.youtubeReasons || err?.reasons;
  if (Array.isArray(reasons) && reasons.some((r) => String(r).toLowerCase() === 'quotaexceeded')) {
    return true;
  }
  return false;
}

function getQuotaBlockedUntil() {
  if (blockedUntilMs && blockedUntilMs > Date.now()) return blockedUntilMs;
  const fromDisk = readBlockedUntilFromDisk(COOLDOWN_FILE);
  if (fromDisk) {
    blockedUntilMs = fromDisk;
    return fromDisk;
  }
  blockedUntilMs = null;
  return null;
}

function getSearchQuotaBlockedUntil() {
  if (searchBlockedUntilMs && searchBlockedUntilMs > Date.now()) return searchBlockedUntilMs;
  const fromDisk = readBlockedUntilFromDisk(SEARCH_COOLDOWN_FILE);
  if (fromDisk) {
    searchBlockedUntilMs = fromDisk;
    return fromDisk;
  }
  searchBlockedUntilMs = null;
  return null;
}

function isYoutubeQuotaBlocked() {
  const until = getQuotaBlockedUntil();
  return until != null && until > Date.now();
}

function isYoutubeSearchQuotaBlocked() {
  const until = getSearchQuotaBlockedUntil();
  return until != null && until > Date.now();
}

function markYoutubeQuotaBlocked() {
  const hours = Math.max(
    1,
    Number(process.env.YOUTUBE_QUOTA_COOLDOWN_HOURS || 24),
  );
  blockedUntilMs = Date.now() + hours * 60 * 60 * 1000;
  writeBlockedUntilToDisk(COOLDOWN_FILE, blockedUntilMs);
  return blockedUntilMs;
}

function markYoutubeSearchQuotaBlocked() {
  const hours = Math.max(
    1,
    Number(process.env.YOUTUBE_SEARCH_QUOTA_COOLDOWN_HOURS || 24),
  );
  searchBlockedUntilMs = Date.now() + hours * 60 * 60 * 1000;
  writeBlockedUntilToDisk(SEARCH_COOLDOWN_FILE, searchBlockedUntilMs);
  return searchBlockedUntilMs;
}

function clearYoutubeQuotaBlock() {
  blockedUntilMs = null;
  searchBlockedUntilMs = null;
  try {
    fs.unlinkSync(COOLDOWN_FILE);
    fs.unlinkSync(SEARCH_COOLDOWN_FILE);
  } catch {
    /* ignore */
  }
}

function formatBlockedUntil(ms) {
  return new Date(ms).toISOString();
}

module.exports = {
  isYoutubeQuotaError,
  isYoutubeSearchQuotaError,
  isYoutubeQuotaBlocked,
  isYoutubeSearchQuotaBlocked,
  markYoutubeQuotaBlocked,
  markYoutubeSearchQuotaBlocked,
  clearYoutubeQuotaBlock,
  getQuotaBlockedUntil,
  getSearchQuotaBlockedUntil,
  formatBlockedUntil,
};
