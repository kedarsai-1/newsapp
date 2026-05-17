/**
 * YouTube search queries mapped to app category slugs + language (te / hi / en).
 * Override via YOUTUBE_SEARCH_JSON env if needed.
 */
const youtubeSearchPlan = [
  // English
  { categorySlug: 'general', query: 'india news today', language: 'en' },
  { categorySlug: 'politics', query: 'india politics news', language: 'en' },
  { categorySlug: 'sports', query: 'india sports news', language: 'en' },
  { categorySlug: 'business', query: 'india business news', language: 'en' },
  { categorySlug: 'entertainment', query: 'india entertainment news', language: 'en' },
  { categorySlug: 'technology', query: 'technology news india', language: 'en' },
  // Telugu
  { categorySlug: 'general', query: 'telugu news today', language: 'te' },
  { categorySlug: 'politics', query: 'telugu politics news', language: 'te' },
  { categorySlug: 'sports', query: 'telugu sports news', language: 'te' },
  { categorySlug: 'business', query: 'telugu business news', language: 'te' },
  { categorySlug: 'entertainment', query: 'telugu entertainment news', language: 'te' },
  { categorySlug: 'technology', query: 'telugu technology news', language: 'te' },
  // Hindi
  { categorySlug: 'general', query: 'hindi news today', language: 'hi' },
  { categorySlug: 'politics', query: 'hindi politics news', language: 'hi' },
  { categorySlug: 'sports', query: 'hindi sports news', language: 'hi' },
  { categorySlug: 'business', query: 'hindi business news', language: 'hi' },
  { categorySlug: 'entertainment', query: 'hindi entertainment news', language: 'hi' },
  { categorySlug: 'technology', query: 'hindi technology news', language: 'hi' },
];

function parseChannelIds(raw) {
  if (!raw?.trim()) return [];
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter((id) => id.startsWith('UC') && id.length >= 10);
}

function getYoutubeSearchPlan() {
  const raw = process.env.YOUTUBE_SEARCH_JSON?.trim();
  if (!raw) return youtubeSearchPlan;
  try {
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return youtubeSearchPlan;
    return parsed
      .filter((x) => x && typeof x === 'object' && x.query)
      .map((x) => ({
        categorySlug: String(x.categorySlug || 'general').trim(),
        query: String(x.query).trim(),
        language: String(x.language || 'en').trim().toLowerCase(),
      }));
  } catch {
    return youtubeSearchPlan;
  }
}

/** Legacy: all channel IDs (defaults to English tagging). */
function getYoutubeChannelIds() {
  return getYoutubeChannelsByLanguage().map((c) => c.channelId);
}

/** Built-in channels when env lists are empty (public channel IDs). */
const defaultYoutubeChannels = [
  { channelId: 'UCumtYpCY26F6Jr3satUgMvA', language: 'te', categorySlug: 'general' },
  { channelId: 'UCwqusr8YDwM-3mEYTDeJHzw', language: 'en', categorySlug: 'general' },
  { channelId: 'UCt4t-jeY85JegMlZ-E5UWtA', language: 'hi', categorySlug: 'general' },
];

/**
 * Channel IDs per language — set YOUTUBE_CHANNEL_IDS_TE / _HI / _EN (or YOUTUBE_CHANNEL_IDS → en).
 */
function getYoutubeChannelsByLanguage() {
  const seen = new Set();
  const out = [];

  const push = (channelId, language, categorySlug = 'general') => {
    if (!channelId || seen.has(channelId)) return;
    seen.add(channelId);
    out.push({
      channelId,
      language: String(language || 'en').toLowerCase(),
      categorySlug: String(categorySlug || 'general').trim(),
    });
  };

  const addFromEnv = (envKey, language) => {
    for (const channelId of parseChannelIds(process.env[envKey])) {
      push(channelId, language);
    }
  };

  addFromEnv('YOUTUBE_CHANNEL_IDS_TE', 'te');
  addFromEnv('YOUTUBE_CHANNEL_IDS_HI', 'hi');
  addFromEnv('YOUTUBE_CHANNEL_IDS_EN', 'en');
  if (out.length === 0) {
    addFromEnv('YOUTUBE_CHANNEL_IDS', 'en');
  }

  for (const row of defaultYoutubeChannels) {
    push(row.channelId, row.language, row.categorySlug);
  }

  return out;
}

module.exports = {
  youtubeSearchPlan,
  getYoutubeSearchPlan,
  getYoutubeChannelIds,
  getYoutubeChannelsByLanguage,
};
