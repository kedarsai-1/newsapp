/**
 * Keep ingested stories in the RSS feed's target category (reject obvious mismatches).
 */

const EXCLUDE_BY_CATEGORY = {
  business: [
    /\b(cricket|football|soccer|tennis|hockey|ipl\b|premier league|world cup|match report|wicket|stumps|innings|goal scored)\b/i,
    /\b(election|polling|ballot|parliament|assembly session|cabinet minister|mla\b|mp\b|bjp|congress|tdp|ysrcp|modi|rahul|jagan)\b/i,
    /\b(movie|film|trailer|teaser|box office|bollywood|tollywood|celebrity wedding|ott release)\b/i,
    /(క్రికెట్|ఫుట్‌బాల్|ఐపీఎల్|మ్యాచ్|ఎన్నిక|పార్టీ|మంత్రి|సినిమా|ట్రైలర్)/,
    /(क्रिकेट|फुटबॉल|चुनाव|मंत्री|सिनेमा|फिल्म)/,
  ],
  sports: [
    /\b(sensex|nifty|stock market|ipo\b|quarterly results|gdp|inflation|rbi\b|sebi\b|merger|acquisition)\b/i,
    /\b(election|parliament|cabinet minister|assembly poll)\b/i,
    /(సెన్సెక్స్|నిఫ్టీ|షేర్ల|ఎన్నిక|మంత్రి)/,
    /(सेंसेक्स|निफ्टी|चुनाव)/,
  ],
  politics: [
    /\b(cricket|ipl\b|football score|box office|movie review|horoscope|zodiac)\b/i,
    /\b(recipe|diet tips|skincare|beauty tips)\b/i,
    /(క్రికెట్|ఐపీఎల్|సినిమా|రాశి|జాతకం)/,
    /(क्रिकेट|फिल्म|राशिफल)/,
  ],
  technology: [
    /\b(cricket|ipl\b|election rally|box office)\b/i,
    /\b(recipe|horoscope)\b/i,
  ],
  entertainment: [
    /\b(sensex|nifty|stock market|gdp|inflation|rbi policy)\b/i,
    /\b(election results|polling booth|parliament session)\b/i,
    /\b(cricket|ipl\b|football final)\b/i,
  ],
  health: [
    /\b(cricket|ipl\b|election|parliament|stock market|sensex)\b/i,
    /\b(movie release|box office)\b/i,
  ],
  education: [
    /\b(cricket|ipl\b|box office|sensex|election rally)\b/i,
  ],
};

/** Feed/article URL looks like a dedicated section feed (trust after exclusions). */
const SECTION_URL_HINTS = {
  business: /\/(business|markets|economy|companies|industry|finance|money)\/|ndtvprofit|economictimes\.indiatimes\.com\/markets|livemint\.com\/rss\/(markets|companies)/i,
  sports: /\/(sport|sports|cricket)\/|ndtvsports|espncricinfo/i,
  politics: /\/(politics|national\/politics|world|andhra-pradesh|telangana)\/|theprint\.in\/category\/(politics|world)/i,
  technology: /\/(technology|tech|sci-tech\/technology)\/|gadgets360/i,
  entertainment: /\/(entertainment|movies|cinema|lifestyle\/entertainment)\/|ndtvmovies|123telugu/i,
  health: /\/(health|wellness|lifestyle)\/|bbc\.co\.uk\/news\/health/i,
  education: /\/(education|career|learning)\//i,
  local: /\/(cities|local|hyderabad|delhi|andhra-pradesh|telangana)\//i,
};

function storyText(item) {
  return `${item?.title || ''} ${item?.summary || ''} ${item?.body || ''}`;
}

function isSectionSpecificSource(categorySlug, feedUrl, articleUrl) {
  const hint = SECTION_URL_HINTS[categorySlug];
  if (!hint) return false;
  return hint.test(String(feedUrl || '')) || hint.test(String(articleUrl || ''));
}

function matchesFeedCategory(item, categorySlug, { feedUrl } = {}) {
  const slug = String(categorySlug || 'general').toLowerCase();
  if (slug === 'general') return true;

  const text = storyText(item);
  const articleUrl = item?.sourceUrl || '';

  const exclusions = EXCLUDE_BY_CATEGORY[slug] || [];
  for (const re of exclusions) {
    if (re.test(text)) return false;
  }

  if (isSectionSpecificSource(slug, feedUrl, articleUrl)) return true;

  // Broad/top-story feeds mapped to a category: require a positive keyword signal.
  const INCLUDE_BY_CATEGORY = {
    business: /\b(business|market|stocks?|sensex|nifty|rupee|economy|economic|gdp|inflation|rbi|sebi|ipo|earnings|revenue|profit|corporate|finance|trade|budget|investment|bank|startup)\b/i,
    sports: /\b(sport|cricket|football|tennis|hockey|match|tournament|league|ipl|goal|wicket|olympic|athlete|coach|stadium)\b/i,
    politics: /\b(politics|election|government|minister|parliament|assembly|party|vote|poll|cabinet|policy|bjp|congress|modi|mla|mp)\b/i,
    technology: /\b(tech|technology|smartphone|android|ios|ai\b|artificial intelligence|software|hardware|gadget|cyber|semiconductor|chip)\b/i,
    entertainment: /\b(movie|film|cinema|actor|actress|bollywood|tollywood|music|celebrity|ott|netflix|trailer|box office|tv show|series)\b/i,
    health: /\b(health|medical|doctor|hospital|disease|vaccine|wellness|fitness|nutrition|mental health|covid|cancer|diabetes)\b/i,
    education: /\b(education|school|college|university|exam|student|teacher|admission|scholarship|degree|campus|neet|jee|upsc)\b/i,
    local: /\b(city|local|traffic|metro|municipal|hyderabad|delhi|mumbai|chennai|bangalore|amaravati|vijayawada|warangal)\b/i,
  };

  const inc = INCLUDE_BY_CATEGORY[slug];
  if (!inc) return true;
  return inc.test(text) || inc.test(articleUrl);
}

module.exports = {
  matchesFeedCategory,
  isSectionSpecificSource,
};
