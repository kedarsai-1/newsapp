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
  { name: 'Times of India - World', url: 'https://timesofindia.indiatimes.com/rssfeeds/296589292.cms', categorySlug: 'politics', language: 'en', politicsScope: 'international' },
  { name: 'Google News English - India Politics', url: 'https://news.google.com/rss/search?q=india+politics&hl=en-IN&gl=IN&ceid=IN:en', categorySlug: 'politics', language: 'en', resolvePublisherUrl: true, politicsScope: 'india' },
  { name: 'Google News English - International Politics', url: 'https://news.google.com/rss/search?q=international+politics&hl=en-US&gl=US&ceid=US:en', categorySlug: 'politics', language: 'en', resolvePublisherUrl: true, politicsScope: 'international' },
  // Tech feed id varies; keep as best-effort (if it fails it won't break whole run).
  { name: 'Times of India - Technology', url: 'https://timesofindia.indiatimes.com/rssfeeds/5880659.cms', categorySlug: 'technology', language: 'en' },

  // ═══════════════════════════════════════════════════════════════════════════
  // HINDI - Mix of RSS images and og:image fallback
  // ═══════════════════════════════════════════════════════════════════════════
  // NDTV "Hindi" feeds are currently returning many English items; prefer stricter Hindi sources.
  { name: 'News18 Hindi', url: 'https://hindi.news18.com/rss/khabar/nation/nation.xml', categorySlug: 'general', language: 'hi' },
  { name: 'News18 Hindi - Politics', url: 'https://hindi.news18.com/rss/khabar/politics/politics.xml', categorySlug: 'politics', language: 'hi', ogImageFallback: true, politicsScope: 'india' },
  { name: 'Dainik Jagran', url: 'https://feeds.feedburner.com/JagranNews', categorySlug: 'general', language: 'hi', ogImageFallback: true },
  { name: 'Amar Ujala', url: 'https://www.amarujala.com/rss/breaking-news.xml', categorySlug: 'general', language: 'hi', ogImageFallback: true },
  { name: 'Google News Hindi - Politics', url: 'https://news.google.com/rss/search?q=%E0%A4%AD%E0%A4%BE%E0%A4%B0%E0%A4%A4+%E0%A4%B0%E0%A4%BE%E0%A4%9C%E0%A4%A8%E0%A5%80%E0%A4%A4%E0%A4%BF&hl=hi&gl=IN&ceid=IN:hi', categorySlug: 'politics', language: 'hi', resolvePublisherUrl: true, politicsScope: 'india' },
  { name: 'Google News Hindi - International Politics', url: 'https://news.google.com/rss/search?q=%E0%A4%85%E0%A4%82%E0%A4%A4%E0%A4%B0%E0%A5%8D%E0%A4%B0%E0%A4%BE%E0%A4%B7%E0%A5%8D%E0%A4%9F%E0%A5%8D%E0%A4%B0%E0%A5%80%E0%A4%AF+%E0%A4%B0%E0%A4%BE%E0%A4%9C%E0%A4%A8%E0%A5%80%E0%A4%A4%E0%A4%BF&hl=hi&gl=IN&ceid=IN:hi', categorySlug: 'politics', language: 'hi', resolvePublisherUrl: true, politicsScope: 'international' },

  // ═══════════════════════════════════════════════════════════════════════════
  // TELUGU - Working feeds with images
  // ═══════════════════════════════════════════════════════════════════════════
  { name: 'TV9 Telugu', url: 'https://www.tv9telugu.com/feed', categorySlug: 'general', language: 'te' },
  { name: 'TV9 Telugu - Andhra Pradesh', url: 'https://www.tv9telugu.com/category/andhra-pradesh/feed', categorySlug: 'politics', language: 'te', ogImageFallback: true, politicsScope: 'andhra' },
  { name: 'TV9 Telugu - Telangana', url: 'https://www.tv9telugu.com/category/telangana/feed', categorySlug: 'politics', language: 'te', ogImageFallback: true, politicsScope: 'telangana' },
  { name: 'Google News Telugu - Andhra Politics', url: 'https://news.google.com/rss/search?q=%E0%B0%86%E0%B0%82%E0%B0%A7%E0%B1%8D%E0%B0%B0%E0%B0%AA%E0%B1%8D%E0%B0%B0%E0%B0%A6%E0%B1%87%E0%B0%B6%E0%B1%8D+%E0%B0%B0%E0%B0%BE%E0%B0%9C%E0%B0%95%E0%B1%80%E0%B0%AF%E0%B0%BE%E0%B0%B2%E0%B1%81&hl=te&gl=IN&ceid=IN:te', categorySlug: 'politics', language: 'te', resolvePublisherUrl: true, politicsScope: 'andhra' },
  { name: 'Google News Telugu - Telangana Politics', url: 'https://news.google.com/rss/search?q=%E0%B0%A4%E0%B1%86%E0%B0%B2%E0%B0%82%E0%B0%97%E0%B0%BE%E0%B0%A3+%E0%B0%B0%E0%B0%BE%E0%B0%9C%E0%B0%95%E0%B1%80%E0%B0%AF%E0%B0%BE%E0%B0%B2%E0%B1%81&hl=te&gl=IN&ceid=IN:te', categorySlug: 'politics', language: 'te', resolvePublisherUrl: true, politicsScope: 'telangana' },
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
  { name: 'Google News Telugu - Politics', url: 'https://news.google.com/rss/search?q=%E0%B0%B0%E0%B0%BE%E0%B0%9C%E0%B0%95%E0%B1%80%E0%B0%AF%E0%B0%BE%E0%B0%B2%E0%B1%81&hl=te&gl=IN&ceid=IN:te', categorySlug: 'politics', language: 'te', resolvePublisherUrl: true, politicsScope: 'all' },
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
        resolvePublisherUrl: Boolean(x.resolvePublisherUrl),
        preferredHost: x.preferredHost ? String(x.preferredHost).trim() : undefined,
        politicsScope: ['all', 'andhra', 'telangana', 'india', 'international'].includes(String(x.politicsScope || '').toLowerCase())
          ? String(x.politicsScope).toLowerCase()
          : undefined,
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
