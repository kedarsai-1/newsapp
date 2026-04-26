/**
 * RSS feed sources (production).
 *
 * You can override at runtime with:
 *   RSS_FEEDS_JSON='[{"name":"...","url":"...","categorySlug":"general","language":"en"}]'
 *
 * Notes:
 * - `categorySlug` must exist in your DB (seed categories).
 * - `language` should be ISO 639-1 (en/te/hi).
 */
const defaultRssFeeds = [
  // ═══════════════════════════════════════════════════════════════════════════
  // ENGLISH - Working feeds (category-mapped so category filter works)
  // ═══════════════════════════════════════════════════════════════════════════
  { name: 'Times of India', url: 'https://timesofindia.indiatimes.com/rssfeedstopstories.cms', categorySlug: 'general', language: 'en' },
  { name: 'The Hindu - National', url: 'https://www.thehindu.com/news/national/feeder/default.rss', categorySlug: 'general', language: 'en' },
  // The Hindu section feeds (very reliable)
  { name: 'The Hindu - Sport', url: 'https://www.thehindu.com/sport/feeder/default.rss', categorySlug: 'sports', language: 'en' },
  { name: 'The Hindu - Business', url: 'https://www.thehindu.com/business/feeder/default.rss', categorySlug: 'business', language: 'en' },
  { name: 'The Hindu - Entertainment', url: 'https://www.thehindu.com/entertainment/feeder/default.rss', categorySlug: 'entertainment', language: 'en' },
  { name: 'The Hindu - Technology', url: 'https://www.thehindu.com/sci-tech/technology/feeder/default.rss', categorySlug: 'technology', language: 'en' },
  { name: 'The Hindu - Health', url: 'https://www.thehindu.com/sci-tech/health/feeder/default.rss', categorySlug: 'health', language: 'en' },
  // Local (cities) for "Local" category
  { name: 'The Hindu - Hyderabad', url: 'https://www.thehindu.com/news/cities/Hyderabad/feeder/default.rss', categorySlug: 'local', language: 'en' },
  // TOI section feeds (so users can filter by category)
  { name: 'Times of India - Sports', url: 'https://timesofindia.indiatimes.com/rssfeeds/4719148.cms', categorySlug: 'sports', language: 'en' },
  { name: 'Times of India - Business', url: 'https://timesofindia.indiatimes.com/rssfeeds/1898055.cms', categorySlug: 'business', language: 'en' },
  { name: 'Times of India - World', url: 'https://timesofindia.indiatimes.com/rssfeeds/296589292.cms', categorySlug: 'politics', language: 'en' },
  // Tech feed id varies; keep as best-effort (if it fails it won't break whole run).
  { name: 'Times of India - Technology', url: 'https://timesofindia.indiatimes.com/rssfeeds/5880659.cms', categorySlug: 'technology', language: 'en' },

  // ═══════════════════════════════════════════════════════════════════════════
  // HINDI - Mix of RSS images and og:image fallback
  // ═══════════════════════════════════════════════════════════════════════════
  // NDTV "Hindi" feeds are currently returning many English items; prefer stricter Hindi sources.
  { name: 'News18 Hindi', url: 'https://hindi.news18.com/rss/khabar/nation/nation.xml', categorySlug: 'general', language: 'hi' },
  { name: 'News18 Hindi - Politics', url: 'https://hindi.news18.com/rss/khabar/politics/politics.xml', categorySlug: 'politics', language: 'hi', ogImageFallback: true },
  { name: 'Dainik Jagran', url: 'https://feeds.feedburner.com/JagranNews', categorySlug: 'general', language: 'hi', ogImageFallback: true },
  { name: 'Amar Ujala', url: 'https://www.amarujala.com/rss/breaking-news.xml', categorySlug: 'general', language: 'hi', ogImageFallback: true },
  { name: 'Google News Hindi - Politics', url: 'https://news.google.com/rss/search?q=%E0%A4%B0%E0%A4%BE%E0%A4%9C%E0%A4%A8%E0%A5%80%E0%A4%A4%E0%A4%BF&hl=hi&gl=IN&ceid=IN:hi', categorySlug: 'politics', language: 'hi', resolvePublisherUrl: true },

  // ═══════════════════════════════════════════════════════════════════════════
  // TELUGU - Working feeds with images
  // ═══════════════════════════════════════════════════════════════════════════
  { name: 'TV9 Telugu', url: 'https://www.tv9telugu.com/feed', categorySlug: 'general', language: 'te' },
  { name: 'TV9 Telugu - Andhra Pradesh', url: 'https://www.tv9telugu.com/category/andhra-pradesh/feed', categorySlug: 'politics', language: 'te', ogImageFallback: true },
  { name: 'TV9 Telugu - Telangana', url: 'https://www.tv9telugu.com/category/telangana/feed', categorySlug: 'politics', language: 'te', ogImageFallback: true },
  // TV9 category feeds (WordPress style)
  { name: 'TV9 Telugu - Sports', url: 'https://www.tv9telugu.com/category/sports/feed', categorySlug: 'sports', language: 'te', ogImageFallback: true },
  { name: 'TV9 Telugu - Business', url: 'https://www.tv9telugu.com/category/business/feed', categorySlug: 'business', language: 'te', ogImageFallback: true },
  { name: 'TV9 Telugu - Technology', url: 'https://www.tv9telugu.com/category/technology/feed', categorySlug: 'technology', language: 'te', ogImageFallback: true },
  { name: 'TV9 Telugu - Entertainment', url: 'https://www.tv9telugu.com/category/entertainment/feed', categorySlug: 'entertainment', language: 'te', ogImageFallback: true },
  { name: 'TV9 Telugu - Health', url: 'https://www.tv9telugu.com/category/health/feed', categorySlug: 'health', language: 'te', ogImageFallback: true },
  { name: 'Mana Telangana', url: 'https://manatelangana.news/feed/', categorySlug: 'general', language: 'te' },
  { name: 'Mana Telangana - Sports', url: 'https://manatelangana.news/category/sports/feed/', categorySlug: 'sports', language: 'te', ogImageFallback: true },
  // Category URLs can change; keep only confirmed-working endpoints.
  { name: '123Telugu', url: 'https://www.123telugu.com/feed', categorySlug: 'general', language: 'te', ogImageFallback: true },
  { name: '123Telugu - Movies', url: 'https://www.123telugu.com/category/mnews/feed', categorySlug: 'entertainment', language: 'te', ogImageFallback: true },
  { name: 'Google News Telugu - Politics', url: 'https://news.google.com/rss/search?q=%E0%B0%B0%E0%B0%BE%E0%B0%9C%E0%B0%95%E0%B1%80%E0%B0%AF%E0%B0%BE%E0%B0%B2%E0%B1%81&hl=te&gl=IN&ceid=IN:te', categorySlug: 'politics', language: 'te', resolvePublisherUrl: true },
];

function getRssFeedsFromEnv() {
  const raw = process.env.RSS_FEEDS_JSON?.trim();
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return null;
    return parsed
      .filter((x) => x && typeof x === 'object')
      .map((x) => ({
        name: String(x.name || '').trim() || 'RSS',
        url: String(x.url || '').trim(),
        categorySlug: String(x.categorySlug || 'general').trim(),
        language: String(x.language || 'en').trim().toLowerCase(),
        ogImageFallback: Boolean(x.ogImageFallback),
      }))
      .filter((x) => x.url);
  } catch {
    return null;
  }
}

function getRssFeeds() {
  return getRssFeedsFromEnv() || defaultRssFeeds;
}

module.exports = { getRssFeeds };
