const fs = require('fs');
const path = require('path');

const COOLDOWN_FILE = path.join(__dirname, '..', '.youtube-quota-until');
let blockedUntilMs = null;

function readBlockedUntilFromDisk() {
  try {
    const raw = fs.readFileSync(COOLDOWN_FILE, 'utf8').trim();
    const ms = Number(raw);
    if (Number.isFinite(ms) && ms > Date.now()) return ms;
  } catch {
    /* no file */
  }
  return null;
}

function writeBlockedUntilToDisk(ms) {
  try {
    fs.writeFileSync(COOLDOWN_FILE, String(ms), 'utf8');
  } catch {
    /* ignore on read-only deploy */
  }
}

function isYoutubeQuotaError(err) {
  const msg = String(err?.message || err || '').toLowerCase();
  if (msg.includes('quotaexceeded') || msg.includes('exceeded your') && msg.includes('quota')) {
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
  const fromDisk = readBlockedUntilFromDisk();
  if (fromDisk) {
    blockedUntilMs = fromDisk;
    return fromDisk;
  }
  blockedUntilMs = null;
  return null;
}

function isYoutubeQuotaBlocked() {
  const until = getQuotaBlockedUntil();
  return until != null && until > Date.now();
}

function markYoutubeQuotaBlocked() {
  const hours = Math.max(
    1,
    Number(process.env.YOUTUBE_QUOTA_COOLDOWN_HOURS || 24),
  );
  blockedUntilMs = Date.now() + hours * 60 * 60 * 1000;
  writeBlockedUntilToDisk(blockedUntilMs);
  return blockedUntilMs;
}

function clearYoutubeQuotaBlock() {
  blockedUntilMs = null;
  try {
    fs.unlinkSync(COOLDOWN_FILE);
  } catch {
    /* ignore */
  }
}

function formatBlockedUntil(ms) {
  return new Date(ms).toISOString();
}

module.exports = {
  isYoutubeQuotaError,
  isYoutubeQuotaBlocked,
  markYoutubeQuotaBlocked,
  clearYoutubeQuotaBlock,
  getQuotaBlockedUntil,
  formatBlockedUntil,
};
