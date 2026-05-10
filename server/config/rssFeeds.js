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
  { name: 'The Hindu - Education', url: 'https://www.thehindu.com/education/feeder/default.rss', categorySlug: 'education', language: 'en' },
  // Local (cities) for "Local" category
  { name: 'The Hindu - Hyderabad', url: 'https://www.thehindu.com/news/cities/Hyderabad/feeder/default.rss', categorySlug: 'local', language: 'en' },
  // TOI section feeds (so users can filter by category)
  { name: 'Times of India - Sports', url: 'https://timesofindia.indiatimes.com/rssfeeds/4719148.cms', categorySlug: 'sports', language: 'en' },
  { name: 'Times of India - Business', url: 'https://timesofindia.indiatimes.com/rssfeeds/1898055.cms', categorySlug: 'business', language: 'en' },
  { name: 'Times of India - World', url: 'https://timesofindia.indiatimes.com/rssfeeds/296589292.cms', categorySlug: 'politics', language: 'en', politicsScope: 'international' },
  { name: 'Times of India - Entertainment', url: 'https://timesofindia.indiatimes.com/rssfeeds/1081479906.cms', categorySlug: 'entertainment', language: 'en' },
  { name: 'Times of India - Education', url: 'https://timesofindia.indiatimes.com/rssfeeds/913168846.cms', categorySlug: 'education', language: 'en' },
  { name: 'Google News English - India Politics', url: 'https://news.google.com/rss/search?q=india+politics&hl=en-IN&gl=IN&ceid=IN:en', categorySlug: 'politics', language: 'en', resolvePublisherUrl: true, politicsScope: 'india' },
  { name: 'Google News English - International Politics', url: 'https://news.google.com/rss/search?q=international+politics&hl=en-US&gl=US&ceid=US:en', categorySlug: 'politics', language: 'en', resolvePublisherUrl: true, politicsScope: 'international' },
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
  // HINDI - Direct publisher feeds across all categories + Google News fallbacks.
  // NDTV "Hindi" feeds frequently return English items; prefer stricter Hindi sources.
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
  // Google News Hindi — politics scope + per-category fallbacks (very fresh).
  { name: 'Google News Hindi - Politics', url: 'https://news.google.com/rss/search?q=%E0%A4%AD%E0%A4%BE%E0%A4%B0%E0%A4%A4+%E0%A4%B0%E0%A4%BE%E0%A4%9C%E0%A4%A8%E0%A5%80%E0%A4%A4%E0%A4%BF&hl=hi&gl=IN&ceid=IN:hi', categorySlug: 'politics', language: 'hi', resolvePublisherUrl: true, politicsScope: 'india' },
  { name: 'Google News Hindi - International Politics', url: 'https://news.google.com/rss/search?q=%E0%A4%85%E0%A4%82%E0%A4%A4%E0%A4%B0%E0%A5%8D%E0%A4%B0%E0%A4%BE%E0%A4%B7%E0%A5%8D%E0%A4%9F%E0%A5%8D%E0%A4%B0%E0%A5%80%E0%A4%AF+%E0%A4%B0%E0%A4%BE%E0%A4%9C%E0%A4%A8%E0%A5%80%E0%A4%A4%E0%A4%BF&hl=hi&gl=IN&ceid=IN:hi', categorySlug: 'politics', language: 'hi', resolvePublisherUrl: true, politicsScope: 'international' },
  // q=खेल (sports)
  { name: 'Google News Hindi - Sports', url: 'https://news.google.com/rss/search?q=%E0%A4%96%E0%A5%87%E0%A4%B2&hl=hi&gl=IN&ceid=IN:hi', categorySlug: 'sports', language: 'hi', resolvePublisherUrl: true },
  // q=व्यापार (business)
  { name: 'Google News Hindi - Business', url: 'https://news.google.com/rss/search?q=%E0%A4%B5%E0%A5%8D%E0%A4%AF%E0%A4%BE%E0%A4%AA%E0%A4%BE%E0%A4%B0&hl=hi&gl=IN&ceid=IN:hi', categorySlug: 'business', language: 'hi', resolvePublisherUrl: true },
  // q=टेक्नोलॉजी (technology)
  { name: 'Google News Hindi - Technology', url: 'https://news.google.com/rss/search?q=%E0%A4%9F%E0%A5%87%E0%A4%95%E0%A5%8D%E0%A4%A8%E0%A5%8B%E0%A4%B2%E0%A5%89%E0%A4%9C%E0%A5%80&hl=hi&gl=IN&ceid=IN:hi', categorySlug: 'technology', language: 'hi', resolvePublisherUrl: true },
  // q=मनोरंजन (entertainment)
  { name: 'Google News Hindi - Entertainment', url: 'https://news.google.com/rss/search?q=%E0%A4%AE%E0%A4%A8%E0%A5%8B%E0%A4%B0%E0%A4%82%E0%A4%9C%E0%A4%A8&hl=hi&gl=IN&ceid=IN:hi', categorySlug: 'entertainment', language: 'hi', resolvePublisherUrl: true },
  // q=स्वास्थ्य (health)
  { name: 'Google News Hindi - Health', url: 'https://news.google.com/rss/search?q=%E0%A4%B8%E0%A5%8D%E0%A4%B5%E0%A4%BE%E0%A4%B8%E0%A5%8D%E0%A4%A5%E0%A5%8D%E0%A4%AF&hl=hi&gl=IN&ceid=IN:hi', categorySlug: 'health', language: 'hi', resolvePublisherUrl: true },
  // q=शिक्षा (education)
  { name: 'Google News Hindi - Education', url: 'https://news.google.com/rss/search?q=%E0%A4%B6%E0%A4%BF%E0%A4%95%E0%A5%8D%E0%A4%B7%E0%A4%BE&hl=hi&gl=IN&ceid=IN:hi', categorySlug: 'education', language: 'hi', resolvePublisherUrl: true },
  // q=दिल्ली (local — Delhi as default Hindi-belt city)
  { name: 'Google News Hindi - Delhi', url: 'https://news.google.com/rss/search?q=%E0%A4%A6%E0%A4%BF%E0%A4%B2%E0%A5%8D%E0%A4%B2%E0%A5%80&hl=hi&gl=IN&ceid=IN:hi', categorySlug: 'local', language: 'hi', resolvePublisherUrl: true },

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
  { name: 'TV9 Telugu - Lifestyle', url: 'https://www.tv9telugu.com/category/lifestyle/feed', categorySlug: 'health', language: 'te', ogImageFallback: true },
  { name: 'TV9 Telugu - Hyderabad', url: 'https://www.tv9telugu.com/category/hyderabad/feed', categorySlug: 'local', language: 'te', ogImageFallback: true },
  { name: 'Mana Telangana', url: 'https://manatelangana.news/feed/', categorySlug: 'general', language: 'te' },
  { name: 'Mana Telangana - Sports', url: 'https://manatelangana.news/category/sports/feed/', categorySlug: 'sports', language: 'te', ogImageFallback: true },
  // Category URLs can change; keep only confirmed-working endpoints.
  { name: '123Telugu', url: 'https://www.123telugu.com/feed', categorySlug: 'general', language: 'te', ogImageFallback: true },
  { name: '123Telugu - Movies', url: 'https://www.123telugu.com/category/mnews/feed', categorySlug: 'entertainment', language: 'te', ogImageFallback: true },
  // Google News Telugu — broad topic searches, very fresh and reliable.
  { name: 'Google News Telugu - Politics', url: 'https://news.google.com/rss/search?q=%E0%B0%B0%E0%B0%BE%E0%B0%9C%E0%B0%95%E0%B1%80%E0%B0%AF%E0%B0%BE%E0%B0%B2%E0%B1%81&hl=te&gl=IN&ceid=IN:te', categorySlug: 'politics', language: 'te', resolvePublisherUrl: true, politicsScope: 'all' },
  // q=క్రీడలు (sports)
  { name: 'Google News Telugu - Sports', url: 'https://news.google.com/rss/search?q=%E0%B0%95%E0%B1%8D%E0%B0%B0%E0%B1%80%E0%B0%A1%E0%B0%B2%E0%B1%81&hl=te&gl=IN&ceid=IN:te', categorySlug: 'sports', language: 'te', resolvePublisherUrl: true },
  // q=వ్యాపారం (business)
  { name: 'Google News Telugu - Business', url: 'https://news.google.com/rss/search?q=%E0%B0%B5%E0%B1%8D%E0%B0%AF%E0%B0%BE%E0%B0%AA%E0%B0%BE%E0%B0%B0%E0%B0%82&hl=te&gl=IN&ceid=IN:te', categorySlug: 'business', language: 'te', resolvePublisherUrl: true },
  // q=టెక్నాలజీ (technology)
  { name: 'Google News Telugu - Technology', url: 'https://news.google.com/rss/search?q=%E0%B0%9F%E0%B1%86%E0%B0%95%E0%B1%8D%E0%B0%A8%E0%B0%BE%E0%B0%B2%E0%B0%9C%E0%B1%80&hl=te&gl=IN&ceid=IN:te', categorySlug: 'technology', language: 'te', resolvePublisherUrl: true },
  // q=సినిమా (entertainment / cinema)
  { name: 'Google News Telugu - Entertainment', url: 'https://news.google.com/rss/search?q=%E0%B0%B8%E0%B0%BF%E0%B0%A8%E0%B0%BF%E0%B0%AE%E0%B0%BE&hl=te&gl=IN&ceid=IN:te', categorySlug: 'entertainment', language: 'te', resolvePublisherUrl: true },
  // q=ఆరోగ్యం (health)
  { name: 'Google News Telugu - Health', url: 'https://news.google.com/rss/search?q=%E0%B0%86%E0%B0%B0%E0%B1%8B%E0%B0%97%E0%B1%8D%E0%B0%AF%E0%B0%82&hl=te&gl=IN&ceid=IN:te', categorySlug: 'health', language: 'te', resolvePublisherUrl: true },
  // q=విద్య (education)
  { name: 'Google News Telugu - Education', url: 'https://news.google.com/rss/search?q=%E0%B0%B5%E0%B0%BF%E0%B0%A6%E0%B1%8D%E0%B0%AF&hl=te&gl=IN&ceid=IN:te', categorySlug: 'education', language: 'te', resolvePublisherUrl: true },
  // q=హైదరాబాద్ (Hyderabad — local)
  { name: 'Google News Telugu - Hyderabad', url: 'https://news.google.com/rss/search?q=%E0%B0%B9%E0%B1%88%E0%B0%A6%E0%B0%B0%E0%B0%BE%E0%B0%AC%E0%B0%BE%E0%B0%A6%E0%B1%8D&hl=te&gl=IN&ceid=IN:te', categorySlug: 'local', language: 'te', resolvePublisherUrl: true },
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
