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
  { name: 'The Hindu - Politics', url: 'https://www.thehindu.com/news/national/politics/feeder/default.rss', categorySlug: 'politics', language: 'en', politicsScope: 'india', ogImageFallback: true },
  // The Hindu section feeds (very reliable)
  { name: 'The Hindu - Sport', url: 'https://www.thehindu.com/sport/feeder/default.rss', categorySlug: 'sports', language: 'en' },
  { name: 'The Hindu - Business', url: 'https://www.thehindu.com/business/feeder/default.rss', categorySlug: 'business', language: 'en' },
  { name: 'The Hindu - Entertainment', url: 'https://www.thehindu.com/entertainment/feeder/default.rss', categorySlug: 'entertainment', language: 'en' },
  { name: 'The Hindu - Technology', url: 'https://www.thehindu.com/sci-tech/technology/feeder/default.rss', categorySlug: 'technology', language: 'en' },
  { name: 'The Hindu - Health', url: 'https://www.thehindu.com/sci-tech/health/feeder/default.rss', categorySlug: 'health', language: 'en' },
  { name: 'The Hindu - Education', url: 'https://www.thehindu.com/education/feeder/default.rss', categorySlug: 'education', language: 'en' },
  // Local (cities) for "Local" category
  { name: 'The Hindu - Hyderabad', url: 'https://www.thehindu.com/news/cities/Hyderabad/feeder/default.rss', categorySlug: 'local', language: 'en' },
  // TOI section feeds (so users can filter by category)
  { name: 'Times of India - Sports', url: 'https://timesofindia.indiatimes.com/rssfeeds/4719148.cms', categorySlug: 'sports', language: 'en' },
  { name: 'Times of India - Business', url: 'https://timesofindia.indiatimes.com/rssfeeds/1898055.cms', categorySlug: 'business', language: 'en' },
  { name: 'Times of India - World', url: 'https://timesofindia.indiatimes.com/rssfeeds/296589292.cms', categorySlug: 'politics', language: 'en', politicsScope: 'international' },
  { name: 'Times of India - Entertainment', url: 'https://timesofindia.indiatimes.com/rssfeeds/1081479906.cms', categorySlug: 'entertainment', language: 'en' },
  { name: 'Times of India - Education', url: 'https://timesofindia.indiatimes.com/rssfeeds/913168846.cms', categorySlug: 'education', language: 'en' },
  { name: 'Indian Express - Politics', url: 'https://indianexpress.com/section/politics/feed/', categorySlug: 'politics', language: 'en', politicsScope: 'india' },
  { name: 'Indian Express - World', url: 'https://indianexpress.com/section/world/feed/', categorySlug: 'politics', language: 'en', politicsScope: 'international' },
  // Tech feed id varies; keep as best-effort (if it fails it won't break whole run).
  { name: 'Times of India - Technology', url: 'https://timesofindia.indiatimes.com/rssfeeds/5880659.cms', categorySlug: 'technology', language: 'en' },

  // Extra English sources — more stories per category + varied publish timestamps.
  { name: 'NDTV Top Stories', url: 'https://feeds.feedburner.com/ndtvnews-top-stories', categorySlug: 'general', language: 'en' },
  { name: 'NDTV Sports', url: 'https://feeds.feedburner.com/ndtvsports-latest', categorySlug: 'sports', language: 'en' },
  { name: 'NDTV Business', url: 'https://feeds.feedburner.com/ndtvprofit-latest', categorySlug: 'business', language: 'en' },
  { name: 'NDTV Entertainment', url: 'https://feeds.feedburner.com/ndtvmovies-latest', categorySlug: 'entertainment', language: 'en' },
  { name: 'Indian Express - Sports', url: 'https://indianexpress.com/section/sports/feed/', categorySlug: 'sports', language: 'en' },
  { name: 'Indian Express - Technology', url: 'https://indianexpress.com/section/technology/feed/', categorySlug: 'technology', language: 'en' },
  { name: 'Indian Express - Entertainment', url: 'https://indianexpress.com/section/entertainment/feed/', categorySlug: 'entertainment', language: 'en' },
  { name: 'Indian Express - Education', url: 'https://indianexpress.com/section/education/feed/', categorySlug: 'education', language: 'en' },
  { name: 'Indian Express - Business', url: 'https://indianexpress.com/section/business/feed/', categorySlug: 'business', language: 'en' },
  { name: 'Indian Express - Lifestyle', url: 'https://indianexpress.com/section/lifestyle/feed/', categorySlug: 'health', language: 'en' },
  { name: 'Indian Express - Cities', url: 'https://indianexpress.com/section/cities/feed/', categorySlug: 'local', language: 'en' },
  { name: 'LiveMint News', url: 'https://www.livemint.com/rss/news', categorySlug: 'business', language: 'en' },
  { name: 'LiveMint Markets', url: 'https://www.livemint.com/rss/markets', categorySlug: 'business', language: 'en' },
  { name: 'Economic Times', url: 'https://economictimes.indiatimes.com/rssfeedsdefault.cms', categorySlug: 'business', language: 'en' },
  { name: 'Economic Times - Markets', url: 'https://economictimes.indiatimes.com/markets/rssfeeds/1977021501.cms', categorySlug: 'business', language: 'en' },
  { name: 'Gadgets 360', url: 'https://feeds.feedburner.com/gadgets360-latest', categorySlug: 'technology', language: 'en' },
  { name: 'BBC India', url: 'https://feeds.bbci.co.uk/news/world/asia/india/rss.xml', categorySlug: 'general', language: 'en' },
  { name: 'BBC Health', url: 'https://feeds.bbci.co.uk/news/health/rss.xml', categorySlug: 'health', language: 'en' },
  { name: 'BBC Technology', url: 'https://feeds.bbci.co.uk/news/technology/rss.xml', categorySlug: 'technology', language: 'en' },
  { name: 'ESPN Cricinfo', url: 'https://www.espncricinfo.com/rss/content/story/feeds/0.xml', categorySlug: 'sports', language: 'en' },
  // Hindustan Times — `rssfeed.xml` is the actively maintained URL pattern (the older `index.xml` paths now 404).
  { name: 'Hindustan Times - India', url: 'https://www.hindustantimes.com/feeds/rss/india-news/rssfeed.xml', categorySlug: 'general', language: 'en' },
  { name: 'Hindustan Times - Cricket', url: 'https://www.hindustantimes.com/feeds/rss/cricket/rssfeed.xml', categorySlug: 'sports', language: 'en' },
  { name: 'Hindustan Times - Sports', url: 'https://www.hindustantimes.com/feeds/rss/sports/rssfeed.xml', categorySlug: 'sports', language: 'en' },
  { name: 'Hindustan Times - Business', url: 'https://www.hindustantimes.com/feeds/rss/business/rssfeed.xml', categorySlug: 'business', language: 'en' },
  { name: 'Hindustan Times - Entertainment', url: 'https://www.hindustantimes.com/feeds/rss/entertainment/rssfeed.xml', categorySlug: 'entertainment', language: 'en' },
  { name: 'Hindustan Times - Lifestyle', url: 'https://www.hindustantimes.com/feeds/rss/lifestyle/rssfeed.xml', categorySlug: 'health', language: 'en' },
  { name: 'Hindustan Times - Education', url: 'https://www.hindustantimes.com/feeds/rss/education/rssfeed.xml', categorySlug: 'education', language: 'en' },

  // ═══════════════════════════════════════════════════════════════════════════
  // HINDI - Direct publisher feeds (images in RSS; no Google News redirects).
  // ═══════════════════════════════════════════════════════════════════════════
  // News18 Hindi (good Hindi-script coverage)
  { name: 'News18 Hindi', url: 'https://hindi.news18.com/rss/khabar/nation/nation.xml', categorySlug: 'general', language: 'hi' },
  { name: 'News18 Hindi - Politics', url: 'https://hindi.news18.com/rss/khabar/politics/politics.xml', categorySlug: 'politics', language: 'hi', ogImageFallback: true, politicsScope: 'india' },
  { name: 'News18 Hindi - Sports', url: 'https://hindi.news18.com/rss/khabar/sports/sports.xml', categorySlug: 'sports', language: 'hi', ogImageFallback: true },
  { name: 'News18 Hindi - Business', url: 'https://hindi.news18.com/rss/khabar/business/business.xml', categorySlug: 'business', language: 'hi', ogImageFallback: true },
  { name: 'News18 Hindi - Entertainment', url: 'https://hindi.news18.com/rss/khabar/entertainment/entertainment.xml', categorySlug: 'entertainment', language: 'hi', ogImageFallback: true },
  { name: 'News18 Hindi - Lifestyle', url: 'https://hindi.news18.com/rss/khabar/lifestyle/lifestyle.xml', categorySlug: 'health', language: 'hi', ogImageFallback: true },
  { name: 'News18 Hindi - Tech', url: 'https://hindi.news18.com/rss/khabar/business/tech.xml', categorySlug: 'technology', language: 'hi', ogImageFallback: true },
  { name: 'News18 Hindi - Career', url: 'https://hindi.news18.com/rss/khabar/career/career.xml', categorySlug: 'education', language: 'hi', ogImageFallback: true },
  // Dainik Bhaskar (only categories with confirmed-working RSS endpoints)
  { name: 'Dainik Bhaskar - Sports', url: 'https://www.bhaskar.com/rss-v1--category-1061.xml', categorySlug: 'sports', language: 'hi' },
  { name: 'Dainik Bhaskar - Education', url: 'https://www.bhaskar.com/rss-v1--category-1051.xml', categorySlug: 'education', language: 'hi' },
  // ABP News (Hindi coverage with thumbnail images)
  { name: 'ABP News - India', url: 'https://news.abplive.com/news/india/feed', categorySlug: 'general', language: 'hi' },
  { name: 'ABP News - Cricket', url: 'https://news.abplive.com/sports/cricket/feed', categorySlug: 'sports', language: 'hi' },
  { name: 'ABP News - Business', url: 'https://news.abplive.com/business/feed', categorySlug: 'business', language: 'hi' },
  { name: 'ABP News - Lifestyle', url: 'https://news.abplive.com/lifestyle/feed', categorySlug: 'health', language: 'hi' },
  // Other Hindi staples
  { name: 'Dainik Jagran', url: 'https://feeds.feedburner.com/JagranNews', categorySlug: 'general', language: 'hi', ogImageFallback: true },
  { name: 'Amar Ujala', url: 'https://www.amarujala.com/rss/breaking-news.xml', categorySlug: 'general', language: 'hi', ogImageFallback: true },
  { name: 'ABP News - Politics', url: 'https://news.abplive.com/news/politics/feed', categorySlug: 'politics', language: 'hi', politicsScope: 'india' },
  { name: 'The Print Hindi - World', url: 'https://hindi.theprint.in/category/world/feed/', categorySlug: 'politics', language: 'hi', ogImageFallback: true, politicsScope: 'international' },
  { name: 'NDTV Khabar - Sports', url: 'https://feeds.feedburner.com/ndtvkhabar-sports', categorySlug: 'sports', language: 'hi', ogImageFallback: true },
  { name: 'Amar Ujala - Business', url: 'https://www.amarujala.com/rss/business.xml', categorySlug: 'business', language: 'hi', ogImageFallback: true },
  { name: 'Amar Ujala - Technology', url: 'https://www.amarujala.com/rss/technology.xml', categorySlug: 'technology', language: 'hi', ogImageFallback: true },
  { name: 'ABP News - Entertainment', url: 'https://news.abplive.com/entertainment/feed', categorySlug: 'entertainment', language: 'hi' },
  { name: 'Amar Ujala - Lifestyle', url: 'https://www.amarujala.com/rss/lifestyle.xml', categorySlug: 'health', language: 'hi', ogImageFallback: true },
  { name: 'ABP News - Education', url: 'https://news.abplive.com/education/feed', categorySlug: 'education', language: 'hi' },
  { name: 'Amar Ujala - Delhi', url: 'https://www.amarujala.com/rss/delhi.xml', categorySlug: 'local', language: 'hi', ogImageFallback: true },

  // ═══════════════════════════════════════════════════════════════════════════
  // TELUGU - Working feeds with images
  // ═══════════════════════════════════════════════════════════════════════════
  { name: 'TV9 Telugu', url: 'https://www.tv9telugu.com/feed', categorySlug: 'general', language: 'te' },
  { name: 'TV9 Telugu - Andhra Pradesh', url: 'https://www.tv9telugu.com/category/andhra-pradesh/feed', categorySlug: 'politics', language: 'te', ogImageFallback: true, politicsScope: 'andhra' },
  { name: 'TV9 Telugu - Telangana', url: 'https://www.tv9telugu.com/category/telangana/feed', categorySlug: 'politics', language: 'te', ogImageFallback: true, politicsScope: 'telangana' },
  { name: 'Eenadu - Andhra Pradesh', url: 'https://www.eenadu.net/rss/andhra-pradesh.rss', categorySlug: 'politics', language: 'te', ogImageFallback: true, politicsScope: 'andhra' },
  { name: 'Eenadu - Telangana', url: 'https://www.eenadu.net/rss/telangana.rss', categorySlug: 'politics', language: 'te', ogImageFallback: true, politicsScope: 'telangana' },
  // TV9 category feeds (WordPress style)
  { name: 'TV9 Telugu - Sports', url: 'https://www.tv9telugu.com/category/sports/feed', categorySlug: 'sports', language: 'te', ogImageFallback: true },
  { name: 'TV9 Telugu - Business', url: 'https://www.tv9telugu.com/category/business/feed', categorySlug: 'business', language: 'te', ogImageFallback: true },
  { name: 'TV9 Telugu - Technology', url: 'https://www.tv9telugu.com/category/technology/feed', categorySlug: 'technology', language: 'te', ogImageFallback: true },
  { name: 'TV9 Telugu - Entertainment', url: 'https://www.tv9telugu.com/category/entertainment/feed', categorySlug: 'entertainment', language: 'te', ogImageFallback: true },
  { name: 'TV9 Telugu - Health', url: 'https://www.tv9telugu.com/category/health/feed', categorySlug: 'health', language: 'te', ogImageFallback: true },
  { name: 'TV9 Telugu - Lifestyle', url: 'https://www.tv9telugu.com/category/lifestyle/feed', categorySlug: 'health', language: 'te', ogImageFallback: true },
  { name: 'TV9 Telugu - Hyderabad', url: 'https://www.tv9telugu.com/category/hyderabad/feed', categorySlug: 'local', language: 'te', ogImageFallback: true },
  { name: 'Mana Telangana', url: 'https://manatelangana.news/feed/', categorySlug: 'general', language: 'te' },
  { name: 'Mana Telangana - Sports', url: 'https://manatelangana.news/category/sports/feed/', categorySlug: 'sports', language: 'te', ogImageFallback: true },
  // Category URLs can change; keep only confirmed-working endpoints.
  { name: '123Telugu', url: 'https://www.123telugu.com/feed', categorySlug: 'general', language: 'te', ogImageFallback: true },
  { name: '123Telugu - Movies', url: 'https://www.123telugu.com/category/mnews/feed', categorySlug: 'entertainment', language: 'te', ogImageFallback: true },
  { name: 'Eenadu - Politics', url: 'https://www.eenadu.net/rss/politics.rss', categorySlug: 'politics', language: 'te', ogImageFallback: true, politicsScope: 'all' },
  { name: 'Eenadu - Top News', url: 'https://www.eenadu.net/rss/home-top-news.rss', categorySlug: 'general', language: 'te', ogImageFallback: true },
  { name: 'Sakshi - Sports', url: 'https://www.sakshi.com/rss/sports', categorySlug: 'sports', language: 'te', ogImageFallback: true },
  { name: 'Sakshi - Business', url: 'https://www.sakshi.com/rss/business', categorySlug: 'business', language: 'te', ogImageFallback: true },
  { name: 'Sakshi - Technology', url: 'https://www.sakshi.com/rss/technology', categorySlug: 'technology', language: 'te', ogImageFallback: true },
  { name: 'Sakshi - Entertainment', url: 'https://www.sakshi.com/rss/entertainment', categorySlug: 'entertainment', language: 'te', ogImageFallback: true },
  { name: 'Eenadu - Health', url: 'https://www.eenadu.net/rss/health.rss', categorySlug: 'health', language: 'te', ogImageFallback: true },
  { name: 'Sakshi - Education', url: 'https://www.sakshi.com/rss/education', categorySlug: 'education', language: 'te', ogImageFallback: true },
  { name: 'Sakshi - Hyderabad', url: 'https://www.sakshi.com/rss/hyderabad', categorySlug: 'local', language: 'te', ogImageFallback: true },
  { name: 'Eenadu - Sports', url: 'https://www.eenadu.net/rss/sports.rss', categorySlug: 'sports', language: 'te', ogImageFallback: true },
  { name: 'Eenadu - Business', url: 'https://www.eenadu.net/rss/business.rss', categorySlug: 'business', language: 'te', ogImageFallback: true },
  { name: 'Eenadu - Technology', url: 'https://www.eenadu.net/rss/technology.rss', categorySlug: 'technology', language: 'te', ogImageFallback: true },
  { name: 'Eenadu - Cinema', url: 'https://www.eenadu.net/rss/cinema.rss', categorySlug: 'entertainment', language: 'te', ogImageFallback: true },
  { name: 'Eenadu - Education', url: 'https://www.eenadu.net/rss/education.rss', categorySlug: 'education', language: 'te', ogImageFallback: true },
  { name: 'Eenadu - Hyderabad', url: 'https://www.eenadu.net/rss/hyderabad.rss', categorySlug: 'local', language: 'te', ogImageFallback: true },
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
        // og:image fallback is opt-out — set explicit `false` to disable per-feed.
        ogImageFallback: x.ogImageFallback === false ? false : true,
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
  const fromEnv = getRssFeedsFromEnv();
  // Empty array from RSS_FEEDS_JSON='[]' would otherwise silence all RSS ingestion.
  if (Array.isArray(fromEnv) && fromEnv.length > 0) return fromEnv;
  return defaultRssFeeds;
}

module.exports = { getRssFeeds };
