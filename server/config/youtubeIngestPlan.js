/**
 * YouTube search queries mapped to app category slugs + language (en / hi / te / ta / kn / bn / ml).
 * Override via YOUTUBE_SEARCH_JSON env if needed.
 */
const youtubeSearchPlan = [
  // English
  { categorySlug: 'general', query: 'india news today', language: 'en' },
  { categorySlug: 'general', query: '#shorts india news today', language: 'en' },
  { categorySlug: 'entertainment', query: '#shorts india entertainment', language: 'en' },
  { categorySlug: 'sports', query: '#shorts cricket india', language: 'en' },
  { categorySlug: 'politics', query: 'india politics news', language: 'en' },
  { categorySlug: 'sports', query: 'india sports news', language: 'en' },
  { categorySlug: 'business', query: 'india business news', language: 'en' },
  { categorySlug: 'entertainment', query: 'india entertainment news', language: 'en' },
  { categorySlug: 'technology', query: 'technology news india', language: 'en' },
  // Telugu
  { categorySlug: 'general', query: 'telugu news today', language: 'te' },
  { categorySlug: 'general', query: '#shorts telugu news', language: 'te' },
  { categorySlug: 'politics', query: 'telugu politics news', language: 'te' },
  { categorySlug: 'politics', query: '#shorts telugu politics', language: 'te' },
  { categorySlug: 'sports', query: 'telugu sports news', language: 'te' },
  { categorySlug: 'business', query: 'telugu business news', language: 'te' },
  { categorySlug: 'entertainment', query: 'telugu entertainment news', language: 'te' },
  { categorySlug: 'technology', query: 'telugu technology news', language: 'te' },
  // Hindi
  { categorySlug: 'general', query: 'hindi news today', language: 'hi' },
  { categorySlug: 'general', query: '#shorts hindi news', language: 'hi' },
  { categorySlug: 'politics', query: 'hindi politics news', language: 'hi' },
  { categorySlug: 'sports', query: 'hindi sports news', language: 'hi' },
  { categorySlug: 'business', query: 'hindi business news', language: 'hi' },
  { categorySlug: 'entertainment', query: 'hindi entertainment news', language: 'hi' },
  { categorySlug: 'technology', query: 'hindi technology news', language: 'hi' },
  // Tamil
  { categorySlug: 'general', query: 'tamil news today', language: 'ta' },
  { categorySlug: 'general', query: '#shorts tamil news', language: 'ta' },
  { categorySlug: 'politics', query: 'tamil politics news', language: 'ta' },
  { categorySlug: 'sports', query: 'tamil sports news', language: 'ta' },
  { categorySlug: 'entertainment', query: 'tamil cinema news', language: 'ta' },
  { categorySlug: 'technology', query: 'tamil technology news', language: 'ta' },
  // Kannada
  { categorySlug: 'general', query: 'kannada news today', language: 'kn' },
  { categorySlug: 'general', query: '#shorts kannada news', language: 'kn' },
  { categorySlug: 'politics', query: 'kannada politics news', language: 'kn' },
  { categorySlug: 'sports', query: 'kannada sports news', language: 'kn' },
  { categorySlug: 'entertainment', query: 'kannada cinema news', language: 'kn' },
  { categorySlug: 'technology', query: 'kannada technology news', language: 'kn' },
  // Bengali
  { categorySlug: 'general', query: 'bengali news today', language: 'bn' },
  { categorySlug: 'general', query: '#shorts bengali news', language: 'bn' },
  { categorySlug: 'politics', query: 'bengali politics news', language: 'bn' },
  { categorySlug: 'sports', query: 'bengali sports news', language: 'bn' },
  { categorySlug: 'entertainment', query: 'bengali entertainment news', language: 'bn' },
  { categorySlug: 'technology', query: 'bengali technology news', language: 'bn' },
  // Malayalam
  { categorySlug: 'general', query: 'malayalam news today', language: 'ml' },
  { categorySlug: 'general', query: '#shorts malayalam news', language: 'ml' },
  { categorySlug: 'politics', query: 'malayalam politics news', language: 'ml' },
  { categorySlug: 'sports', query: 'malayalam sports news', language: 'ml' },
  { categorySlug: 'entertainment', query: 'malayalam cinema news', language: 'ml' },
  { categorySlug: 'technology', query: 'malayalam technology news', language: 'ml' },
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
  { channelId: 'UC_2irx_BQR7RsBKmUV9fePQ', language: 'te', categorySlug: 'general' },
  { channelId: 'UCZ9m4KOh8Ei60428xeGYDCQ', language: 'te', categorySlug: 'general' },
  { channelId: 'UCPXTXMecYqnRKNdqdVOGSFg', language: 'te', categorySlug: 'general' },
  { channelId: 'UCwqusr8YDwM-3mEYTDeJHzw', language: 'en', categorySlug: 'general' },
  { channelId: 'UCt4t-jeY85JegMlZ-E5UWtA', language: 'hi', categorySlug: 'general' },
  // Tamil channels
  { channelId: 'UCV89v___FDmzRfLU2Oz5YvA', language: 'ta', categorySlug: 'general' },
  { channelId: 'UCFNWpAhjCH98PV6sify5KBQ', language: 'ta', categorySlug: 'general' },
  { channelId: 'UCKMYktpmV0Cd-p99c1g0WjQ', language: 'ta', categorySlug: 'general' },
  // Kannada channels
  { channelId: 'UCI3tKqpCZBeDmZIg_FTCXDQ', language: 'kn', categorySlug: 'general' },
  { channelId: 'UCJ5OPjf3buHlJaPMIlpqkrg', language: 'kn', categorySlug: 'general' },
  { channelId: 'UCNNjc-6MfgZW5Z4RQbD61bw', language: 'kn', categorySlug: 'general' },
  // Bengali channels
  { channelId: 'UC2NKRsJGvWqorl7qRFhCiqg', language: 'bn', categorySlug: 'general' },
  { channelId: 'UCMi-U96VoC1GusKpP_KnYQA', language: 'bn', categorySlug: 'general' },
  { channelId: 'UCv8jY9q4Zv0xMpRdZ0xSQg', language: 'bn', categorySlug: 'general' },
  // Malayalam channels
  { channelId: 'UCWL95J7bR25nz8DUqmISfWA', language: 'ml', categorySlug: 'general' },
  { channelId: 'UCqC5V2u6p0x1H0XoS4xT6w', language: 'ml', categorySlug: 'general' },
  { channelId: 'UCgG3M_mJwB8tMF3vDal_CKg', language: 'ml', categorySlug: 'general' },
];

/**
 * Channel IDs per language — set YOUTUBE_CHANNEL_IDS_TE / _HI / _EN / _TA / _KN / _BN / _ML
 * (or YOUTUBE_CHANNEL_IDS → en).
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
  addFromEnv('YOUTUBE_CHANNEL_IDS_TA', 'ta');
  addFromEnv('YOUTUBE_CHANNEL_IDS_KN', 'kn');
  addFromEnv('YOUTUBE_CHANNEL_IDS_BN', 'bn');
  addFromEnv('YOUTUBE_CHANNEL_IDS_ML', 'ml');
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
