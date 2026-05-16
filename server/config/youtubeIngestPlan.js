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

/**
 * Channel IDs per language — set YOUTUBE_CHANNEL_IDS_TE / _HI / _EN (or YOUTUBE_CHANNEL_IDS → en).
 */
function getYoutubeChannelsByLanguage() {
  const out = [];
  const add = (envKey, language) => {
    for (const channelId of parseChannelIds(process.env[envKey])) {
      out.push({ channelId, language });
    }
  };
  add('YOUTUBE_CHANNEL_IDS_TE', 'te');
  add('YOUTUBE_CHANNEL_IDS_HI', 'hi');
  add('YOUTUBE_CHANNEL_IDS_EN', 'en');
  if (out.length === 0) {
    add('YOUTUBE_CHANNEL_IDS', 'en');
  }
  return out;
}

module.exports = {
  youtubeSearchPlan,
  getYoutubeSearchPlan,
  getYoutubeChannelIds,
  getYoutubeChannelsByLanguage,
};
