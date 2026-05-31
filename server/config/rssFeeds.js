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
  { name: 'The Hindu - Politics', url: 'https://www.thehindu.com/news/national/?service=rss', categorySlug: 'politics', language: 'en', politicsScope: 'india', ogImageFallback: true },
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
  { name: 'LiveMint Companies', url: 'https://www.livemint.com/rss/companies', categorySlug: 'business', language: 'en' },
  { name: 'LiveMint Markets', url: 'https://www.livemint.com/rss/markets', categorySlug: 'business', language: 'en' },
  { name: 'Economic Times - Business', url: 'https://economictimes.indiatimes.com/rssfeeds/1898671711.cms', categorySlug: 'business', language: 'en' },
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
  { name: 'India Today', url: 'https://www.indiatoday.in/rss/home', categorySlug: 'general', language: 'en' },
  { name: 'India Today - Politics', url: 'https://www.indiatoday.in/rss/1206514', categorySlug: 'politics', language: 'en', politicsScope: 'india' },
  { name: 'India Today - Sports', url: 'https://www.indiatoday.in/rss/1206516', categorySlug: 'sports', language: 'en' },
  { name: 'India Today - Business', url: 'https://www.indiatoday.in/rss/1206518', categorySlug: 'business', language: 'en' },
  { name: 'India Today - Technology', url: 'https://www.indiatoday.in/rss/1206570', categorySlug: 'technology', language: 'en' },
  { name: 'Indian Express - Top', url: 'https://indianexpress.com/feed/', categorySlug: 'general', language: 'en' },
  { name: 'NDTV - Latest', url: 'https://feeds.feedburner.com/ndtvnews-latest', categorySlug: 'general', language: 'en' },
  { name: 'Moneycontrol - Latest', url: 'https://www.moneycontrol.com/rss/latestnews.xml', categorySlug: 'business', language: 'en' },

  // ═══════════════════════════════════════════════════════════════════════════
  // HINDI - Direct publisher feeds (images in RSS; no Google News redirects).
  // ═══════════════════════════════════════════════════════════════════════════
  { name: 'BBC Hindi', url: 'https://feeds.bbci.co.uk/hindi/rss.xml', categorySlug: 'general', language: 'hi', ogImageFallback: true },
  { name: 'BBC Hindi - India', url: 'https://feeds.bbci.co.uk/hindi/india/rss.xml', categorySlug: 'politics', language: 'hi', politicsScope: 'india', ogImageFallback: true },
  { name: 'BBC Hindi - World', url: 'https://feeds.bbci.co.uk/hindi/world/rss.xml', categorySlug: 'politics', language: 'hi', politicsScope: 'international', ogImageFallback: true },
  { name: 'NDTV Khabar', url: 'https://feeds.feedburner.com/ndtvkhabar-latest', categorySlug: 'general', language: 'hi', ogImageFallback: true },
  { name: 'Prabhat Khabar', url: 'https://www.prabhatkhabar.com/feed', categorySlug: 'general', language: 'hi', ogImageFallback: true },
  // Dainik Bhaskar (only categories with confirmed-working RSS endpoints)
  { name: 'Dainik Bhaskar - Sports', url: 'https://www.bhaskar.com/rss-v1--category-1061.xml', categorySlug: 'sports', language: 'hi', ogImageFallback: true },
  { name: 'Dainik Bhaskar - Education', url: 'https://www.bhaskar.com/rss-v1--category-1051.xml', categorySlug: 'education', language: 'hi', ogImageFallback: true },
  // ABP News (Hindi coverage with thumbnail images)
  { name: 'ABP News - India', url: 'https://news.abplive.com/news/india/feed', categorySlug: 'general', language: 'hi', ogImageFallback: true },
  { name: 'ABP News - Cricket', url: 'https://news.abplive.com/sports/cricket/feed', categorySlug: 'sports', language: 'hi', ogImageFallback: true },
  { name: 'ABP News - Business', url: 'https://news.abplive.com/business/feed', categorySlug: 'business', language: 'hi', ogImageFallback: true },
  { name: 'ABP News - Lifestyle', url: 'https://news.abplive.com/lifestyle/feed', categorySlug: 'health', language: 'hi', ogImageFallback: true },
  // Other Hindi staples
  { name: 'Dainik Jagran', url: 'https://feeds.feedburner.com/JagranNews', categorySlug: 'general', language: 'hi', ogImageFallback: true },
  { name: 'Amar Ujala', url: 'https://www.amarujala.com/rss/breaking-news.xml', categorySlug: 'general', language: 'hi', ogImageFallback: true },
  { name: 'ABP News - Politics', url: 'https://news.abplive.com/news/politics/feed', categorySlug: 'politics', language: 'hi', politicsScope: 'india', ogImageFallback: true },
  { name: 'The Print Hindi - Politics', url: 'https://hindi.theprint.in/category/politics/feed/', categorySlug: 'politics', language: 'hi', politicsScope: 'india', ogImageFallback: true },
  { name: 'The Print Hindi - World', url: 'https://hindi.theprint.in/category/world/feed/', categorySlug: 'politics', language: 'hi', ogImageFallback: true, politicsScope: 'international' },
  { name: 'NDTV Khabar - India', url: 'https://feeds.feedburner.com/ndtvkhabar-india', categorySlug: 'politics', language: 'hi', politicsScope: 'india', ogImageFallback: true },
  { name: 'NDTV Khabar - Sports', url: 'https://feeds.feedburner.com/ndtvkhabar-sports', categorySlug: 'sports', language: 'hi', ogImageFallback: true },
  { name: 'Amar Ujala - Business', url: 'https://www.amarujala.com/rss/business.xml', categorySlug: 'business', language: 'hi', ogImageFallback: true },
  { name: 'Amar Ujala - Technology', url: 'https://www.amarujala.com/rss/technology.xml', categorySlug: 'technology', language: 'hi', ogImageFallback: true },
  { name: 'ABP News - Entertainment', url: 'https://news.abplive.com/entertainment/feed', categorySlug: 'entertainment', language: 'hi', ogImageFallback: true },
  { name: 'Amar Ujala - Lifestyle', url: 'https://www.amarujala.com/rss/lifestyle.xml', categorySlug: 'health', language: 'hi', ogImageFallback: true },
  { name: 'ABP News - Education', url: 'https://news.abplive.com/education/feed', categorySlug: 'education', language: 'hi', ogImageFallback: true },
  { name: 'ABP News - States', url: 'https://news.abplive.com/news/states/feed', categorySlug: 'local', language: 'hi', ogImageFallback: true, politicsScope: 'north' },
  { name: 'Amar Ujala - Uttar Pradesh', url: 'https://www.amarujala.com/rss/uttar-pradesh.xml', categorySlug: 'local', language: 'hi', ogImageFallback: true, politicsScope: 'north' },
  { name: 'Amar Ujala - Punjab', url: 'https://www.amarujala.com/rss/punjab.xml', categorySlug: 'local', language: 'hi', ogImageFallback: true, politicsScope: 'north' },
  { name: 'Amar Ujala - Haryana', url: 'https://www.amarujala.com/rss/haryana.xml', categorySlug: 'local', language: 'hi', ogImageFallback: true, politicsScope: 'north' },
  { name: 'Amar Ujala - Rajasthan', url: 'https://www.amarujala.com/rss/rajasthan.xml', categorySlug: 'local', language: 'hi', ogImageFallback: true, politicsScope: 'north' },
  { name: 'Amar Ujala - Bihar', url: 'https://www.amarujala.com/rss/bihar.xml', categorySlug: 'local', language: 'hi', ogImageFallback: true, politicsScope: 'north' },
  { name: 'Amar Ujala - Delhi', url: 'https://www.amarujala.com/rss/delhi.xml', categorySlug: 'local', language: 'hi', ogImageFallback: true, politicsScope: 'north' },

  // ═══════════════════════════════════════════════════════════════════════════
  // TELUGU - Working feeds with images
  // ═══════════════════════════════════════════════════════════════════════════
  { name: 'TV9 Telugu', url: 'https://www.tv9telugu.com/feed', categorySlug: 'general', language: 'te' },
  { name: 'TV9 Telugu - Politics', url: 'https://www.tv9telugu.com/category/politics/feed', categorySlug: 'politics', language: 'te', ogImageFallback: true, politicsScope: 'india' },
  { name: 'NTV Telugu - Politics', url: 'https://www.ntvtelugu.com/category/politics/feed', categorySlug: 'politics', language: 'te', ogImageFallback: true, politicsScope: 'india' },
  { name: 'TV9 Telugu - International', url: 'https://www.tv9telugu.com/category/international/feed', categorySlug: 'politics', language: 'te', ogImageFallback: true, politicsScope: 'international' },
  { name: 'TV9 Telugu - World', url: 'https://www.tv9telugu.com/category/world/feed', categorySlug: 'politics', language: 'te', ogImageFallback: true, politicsScope: 'international' },
  { name: 'NTV Telugu - World', url: 'https://www.ntvtelugu.com/category/world-news/feed', categorySlug: 'politics', language: 'te', ogImageFallback: true, politicsScope: 'international' },
  { name: 'V6 Velugu - Politics', url: 'https://www.v6velugu.com/category/politics/feed', categorySlug: 'politics', language: 'te', ogImageFallback: true, politicsScope: 'india' },
  { name: 'TV9 Telugu - Andhra Pradesh', url: 'https://www.tv9telugu.com/category/andhra-pradesh/feed', categorySlug: 'local', language: 'te', ogImageFallback: true, politicsScope: 'andhra' },
  { name: 'TV9 Telugu - Telangana', url: 'https://www.tv9telugu.com/category/telangana/feed', categorySlug: 'local', language: 'te', ogImageFallback: true, politicsScope: 'telangana' },
  { name: '10TV Telugu', url: 'https://10tv.in/feed', categorySlug: 'general', language: 'te', ogImageFallback: true },
  { name: 'NTV Telugu', url: 'https://www.ntvtelugu.com/feed', categorySlug: 'general', language: 'te', ogImageFallback: true },
  // TV9 category feeds (WordPress style)
  { name: 'TV9 Telugu - Sports', url: 'https://www.tv9telugu.com/category/sports/feed', categorySlug: 'sports', language: 'te', ogImageFallback: true },
  { name: 'TV9 Telugu - Business', url: 'https://www.tv9telugu.com/category/business/feed', categorySlug: 'business', language: 'te', ogImageFallback: true },
  { name: 'TV9 Telugu - Technology', url: 'https://www.tv9telugu.com/category/technology/feed', categorySlug: 'technology', language: 'te', ogImageFallback: true },
  { name: 'TV9 Telugu - Entertainment', url: 'https://www.tv9telugu.com/category/entertainment/feed', categorySlug: 'entertainment', language: 'te', ogImageFallback: true },
  { name: 'TV9 Telugu - Health', url: 'https://www.tv9telugu.com/category/health/feed', categorySlug: 'health', language: 'te', ogImageFallback: true },
  { name: 'TV9 Telugu - Lifestyle', url: 'https://www.tv9telugu.com/category/lifestyle/feed', categorySlug: 'health', language: 'te', ogImageFallback: true },
  { name: 'TV9 Telugu - Hyderabad', url: 'https://www.tv9telugu.com/category/hyderabad/feed', categorySlug: 'local', language: 'te', ogImageFallback: true },
  { name: 'V6 Velugu', url: 'https://www.v6velugu.com/feed', categorySlug: 'general', language: 'te', ogImageFallback: true },
  { name: 'Andhra Jyothy', url: 'https://www.andhrajyothy.com/rss/feed.xml', categorySlug: 'general', language: 'te', ogImageFallback: true },
  { name: 'Mana Telangana', url: 'https://manatelangana.news/feed/', categorySlug: 'general', language: 'te' },
  { name: 'Mana Telangana - Sports', url: 'https://manatelangana.news/category/sports/feed/', categorySlug: 'sports', language: 'te', ogImageFallback: true },
  // Category URLs can change; keep only confirmed-working endpoints.
  { name: '123Telugu', url: 'https://www.123telugu.com/feed', categorySlug: 'general', language: 'te', ogImageFallback: true },
  { name: '123Telugu - Movies', url: 'https://www.123telugu.com/category/mnews/feed', categorySlug: 'entertainment', language: 'te', ogImageFallback: true },
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
        politicsScope: ['all', 'andhra', 'telangana', 'india', 'international', 'north', 'states', 'delhi'].includes(String(x.politicsScope || '').toLowerCase())
          ? String(x.politicsScope).toLowerCase()
          : undefined,
      }))
      .filter((x) => x.url);
  } catch {
    return null;
  }
}

function getRssFeeds({ languages } = {}) {
  const fromEnv = getRssFeedsFromEnv();
  // Empty array from RSS_FEEDS_JSON='[]' would otherwise silence all RSS ingestion.
  let feeds = (Array.isArray(fromEnv) && fromEnv.length > 0) ? fromEnv : defaultRssFeeds;

  if (languages?.length) {
    const set = new Set(
      languages.map((l) => String(l || '').trim().toLowerCase()).filter(Boolean),
    );
    feeds = feeds.filter((f) => set.has(String(f.language || 'en').toLowerCase()));
  }
  return feeds;
}

module.exports = { getRssFeeds };
