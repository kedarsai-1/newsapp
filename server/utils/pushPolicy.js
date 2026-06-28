const DEFAULT_MIN_INSERTED = 5;
const DEFAULT_COOLDOWN_MS = 15 * 60 * 1000;
const DEFAULT_INGEST_SOURCES = ['news'];
const NOTIFICATION_BODY_MAX = 240;
const NOTIFICATION_TITLE_MAX = 120;

const INVALID_FCM_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

function parseEnvInt(name, fallback) {
  const raw = process.env[name];
  if (raw === undefined || raw === null || String(raw).trim() === '') return fallback;
  const n = Number(raw);
  return Number.isFinite(n) && n >= 0 ? Math.floor(n) : fallback;
}

function getPushMinInserted() {
  return parseEnvInt('PUSH_MIN_INSERTED', DEFAULT_MIN_INSERTED);
}

function getPushIngestCooldownMs() {
  return parseEnvInt('PUSH_INGEST_COOLDOWN_MS', DEFAULT_COOLDOWN_MS);
}

function parsePushIngestSources() {
  const raw = process.env.PUSH_INGEST_SOURCES;
  if (raw === undefined || raw === null || String(raw).trim() === '') {
    return new Set(DEFAULT_INGEST_SOURCES);
  }
  const parts = String(raw)
    .split(',')
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);
  return parts.length ? new Set(parts) : new Set(DEFAULT_INGEST_SOURCES);
}

function normalizeIngestSource(source) {
  const value = String(source || 'news').trim().toLowerCase();
  if (value === 'political-video') return 'political-video';
  return value || 'news';
}

function shouldNotifyFeedIngest({
  inserted = 0,
  source = 'news',
  now = Date.now(),
  lastPushAt = 0,
  notifyEnabled = true,
  minInserted = getPushMinInserted(),
  cooldownMs = getPushIngestCooldownMs(),
  allowedSources = parsePushIngestSources(),
} = {}) {
  if (!notifyEnabled) return { ok: false, reason: 'disabled' };
  const count = Number(inserted);
  if (!Number.isFinite(count) || count < 1) return { ok: false, reason: 'no_inserted' };
  if (count < minInserted) return { ok: false, reason: 'below_min_inserted', minInserted };
  const normalizedSource = normalizeIngestSource(source);
  if (!allowedSources.has(normalizedSource)) {
    return { ok: false, reason: 'source_excluded', source: normalizedSource };
  }
  if (lastPushAt > 0 && now - lastPushAt < cooldownMs) {
    return { ok: false, reason: 'cooldown', cooldownMs, retryInMs: cooldownMs - (now - lastPushAt) };
  }
  return { ok: true, count, source: normalizedSource };
}

function buildIngestNotification(count, { headline } = {}) {
  const n = Number(count);
  const safeHeadline = truncatePushText(headline, NOTIFICATION_TITLE_MAX);
  if (safeHeadline) {
    if (n <= 1) {
      return {
        title: safeHeadline,
        body: 'Tap to read the latest update.',
      };
    }
    const more = n - 1;
    return {
      title: safeHeadline,
      body: `${more} more new ${more === 1 ? 'story' : 'stories'} in your feed.`,
    };
  }
  if (n === 1) {
    return {
      title: 'New story in your feed',
      body: 'Tap to read the latest update.',
    };
  }
  return {
    title: 'Fresh stories in your feed',
    body: `${n} new stories were added. Tap to catch up.`,
  };
}

function truncatePushText(text, max = NOTIFICATION_BODY_MAX) {
  const value = String(text || '').trim();
  if (value.length <= max) return value;
  return `${value.slice(0, Math.max(0, max - 1)).trimEnd()}…`;
}

function sanitizeFcmTopic(topic) {
  return String(topic || '').replace(/[^a-zA-Z0-9_-]/g, '_');
}

function isInvalidFcmTokenError(error) {
  const code = error?.code || error?.errorInfo?.code;
  if (code && INVALID_FCM_TOKEN_CODES.has(code)) return true;
  const message = String(error?.message || '').toLowerCase();
  return message.includes('registration token')
    || message.includes('not registered')
    || message.includes('invalid registration');
}

function breakingTopicEnabled() {
  return process.env.PUSH_NOTIFY_BREAKING_TOPIC !== 'false';
}

function pruneInvalidTokensEnabled() {
  return process.env.FCM_PRUNE_INVALID_TOKENS !== 'false';
}

module.exports = {
  DEFAULT_MIN_INSERTED,
  DEFAULT_COOLDOWN_MS,
  DEFAULT_INGEST_SOURCES,
  NOTIFICATION_BODY_MAX,
  NOTIFICATION_TITLE_MAX,
  INVALID_FCM_TOKEN_CODES,
  parseEnvInt,
  getPushMinInserted,
  getPushIngestCooldownMs,
  parsePushIngestSources,
  normalizeIngestSource,
  shouldNotifyFeedIngest,
  buildIngestNotification,
  truncatePushText,
  sanitizeFcmTopic,
  isInvalidFcmTokenError,
  breakingTopicEnabled,
  pruneInvalidTokensEnabled,
};
