/**
 * YouTube search queries mapped to app category slugs (seed categories).
 * Override per slug via YOUTUBE_SEARCH_JSON env if needed.
 */
const youtubeSearchPlan = [
  { categorySlug: 'general', query: 'india news today', language: 'en' },
  { categorySlug: 'politics', query: 'india politics news', language: 'en' },
  { categorySlug: 'sports', query: 'india sports news', language: 'en' },
  { categorySlug: 'business', query: 'india business news', language: 'en' },
  { categorySlug: 'entertainment', query: 'india entertainment news', language: 'en' },
  { categorySlug: 'technology', query: 'technology news india', language: 'en' },
  { categorySlug: 'health', query: 'india health news', language: 'en' },
  { categorySlug: 'education', query: 'india education news', language: 'en' },
];

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

function getYoutubeChannelIds() {
  const raw = process.env.YOUTUBE_CHANNEL_IDS?.trim();
  if (!raw) return [];
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter((id) => id.startsWith('UC') && id.length >= 10);
}

module.exports = {
  youtubeSearchPlan,
  getYoutubeSearchPlan,
  getYoutubeChannelIds,
};
