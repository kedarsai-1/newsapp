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

/** Telugu / Hindi publisher paths (article URLs) — section feeds already set category at ingest. */
const INDIC_SECTION_URL_HINTS = {
  business: /\/(business|economy|markets|finance|money|వ్యాపార|ఆర్థిక|बिजनेस|अर्थव्यवस्था)\//i,
  sports: /\/(sport|sports|cricket|క్రీడ|క్రీడల|खेल|क्रिकेट)\//i,
  politics: /\/(politics|national|world|andhra-pradesh|telangana|రాజకీయ|राजनीति)\//i,
  technology: /\/(technology|tech|sci-tech|టెక్నాలజీ|टेक्नोलॉजी|टेक)\//i,
  entertainment: /\/(entertainment|movies|cinema|సినిమా|मनोरंजन|फिल्म)\//i,
  health: /\/(health|wellness|lifestyle|ఆరోగ్య|स्वास्थ्य)\//i,
  education: /\/(education|career|విద్య|शिक्षा)\//i,
  local: /\/(hyderabad|delhi|cities|local|amaravati|warangal|హైదరాబాద్)\//i,
};

function storyText(item) {
  return `${item?.title || ''} ${item?.summary || ''} ${item?.body || ''}`;
}

function isSectionSpecificSource(categorySlug, feedUrl, articleUrl) {
  const slug = String(categorySlug || '').toLowerCase();
  const feed = String(feedUrl || '');
  const article = String(articleUrl || '');
  const enHint = SECTION_URL_HINTS[slug];
  const indicHint = INDIC_SECTION_URL_HINTS[slug];
  if (enHint && (enHint.test(feed) || enHint.test(article))) return true;
  if (indicHint && (indicHint.test(feed) || indicHint.test(article))) return true;
  return false;
}

function passesCategoryExclusions(item, categorySlug) {
  const slug = String(categorySlug || 'general').toLowerCase();
  if (slug === 'general') return true;
  const text = storyText(item);
  const exclusions = EXCLUDE_BY_CATEGORY[slug] || [];
  for (const re of exclusions) {
    if (re.test(text)) return false;
  }
  return true;
}

/**
 * Ingest gate: trust RSS/API categorySlug by default; only drop obvious cross-topic noise.
 * Set INGEST_STRICT_CATEGORY_FILTER=true to require keyword signals (legacy behavior).
 */
function passesIngestCategoryGate(item, categorySlug, { feedUrl } = {}) {
  const slug = String(categorySlug || 'general').toLowerCase();
  if (slug === 'general') return true;
  if (!passesCategoryExclusions(item, slug)) return false;
  if (process.env.INGEST_STRICT_CATEGORY_FILTER === 'true') {
    return matchesFeedCategory(item, categorySlug, { feedUrl });
  }
  return true;
}

function matchesFeedCategory(item, categorySlug, { feedUrl } = {}) {
  const slug = String(categorySlug || 'general').toLowerCase();
  if (slug === 'general') return true;

  const text = storyText(item);
  const articleUrl = item?.sourceUrl || '';

  if (!passesCategoryExclusions(item, slug)) return false;

  if (isSectionSpecificSource(slug, feedUrl, articleUrl)) return true;

  // Broad/top-story feeds mapped to a category: require a positive keyword signal.
  const INCLUDE_BY_CATEGORY = {
    business:
      /\b(business|market|stocks?|sensex|nifty|rupee|economy|economic|gdp|inflation|rbi|sebi|ipo|earnings|revenue|profit|corporate|finance|trade|budget|investment|bank|startup)\b|(వ్యాపార|ఆర్థిక|షేర్|సెన్సెక్స్|निफ्टी|सेंसेक्स|बिजनेस|अर्थव्यवस्था|शेयर)/i,
    sports:
      /\b(sport|cricket|football|tennis|hockey|match|tournament|league|ipl|goal|wicket|olympic|athlete|coach|stadium)\b|(క్రికెట్|ఐపీఎల్|క్రీడ|మ్యాచ్|फुटबॉल|क्रिकेट|खेल|मैच)/i,
    politics:
      /\b(politics|election|government|minister|parliament|assembly|party|vote|poll|cabinet|policy|bjp|congress|modi|mla|mp)\b|(రాజకీయ|ఎన్నిక|మంత్రి|పార్టీ|శాసనసభ|राजनीति|चुनाव|मंत्री|सरकार)/i,
    technology:
      /\b(tech|technology|smartphone|android|ios|ai\b|artificial intelligence|software|hardware|gadget|cyber|semiconductor|chip)\b|(టెక్నాలజీ|స్మార్ట్|टेक्नोलॉजी|स्मार्टफोन)/i,
    entertainment:
      /\b(movie|film|cinema|actor|actress|bollywood|tollywood|music|celebrity|ott|netflix|trailer|box office|tv show|series)\b|(సినిమా|ట్రైలర్|సినిమాల|फिल्म|बॉलीवुड|मनोरंजन)/i,
    health:
      /\b(health|medical|doctor|hospital|disease|vaccine|wellness|fitness|nutrition|mental health|covid|cancer|diabetes)\b|(ఆరోగ్య|వైద్య|स्वास्थ्य|डॉक्टर)/i,
    education:
      /\b(education|school|college|university|exam|student|teacher|admission|scholarship|degree|campus|neet|jee|upsc)\b|(విద్య|పరీక్ష|शिक्षा|परीक्षा|विद्यार्थी)/i,
    local:
      /\b(city|local|traffic|metro|municipal|hyderabad|delhi|mumbai|chennai|bangalore|amaravati|vijayawada|warangal)\b|(హైదరాబాద్|అమరావతి|విజయవాడ|हैदराबाद|दिल्ली|मुंबई)/i,
  };

  const inc = INCLUDE_BY_CATEGORY[slug];
  if (!inc) return true;
  return inc.test(text) || inc.test(articleUrl);
}

/** Legacy RSS labels that were mapped to the wrong category before feed fixes. */
const LEGACY_MISCATEGORIZED = [
  {
    categorySlug: 'business',
    sourcePattern: /rss\s*·\s*livemint news/i,
  },
];

function isLegacyMiscategorized(post, categorySlug) {
  const slug = String(categorySlug || '').toLowerCase();
  const src = String(post?.sourceName || '');
  for (const rule of LEGACY_MISCATEGORIZED) {
    if (rule.categorySlug !== slug) continue;
    if (!rule.sourcePattern.test(src)) continue;
    return !matchesFeedCategory(post, slug, {});
  }
  return false;
}

/** Filter feed rows so category tabs only return on-topic stories. */
function filterPostsForCategory(posts, categorySlug) {
  const slug = String(categorySlug || '').toLowerCase();
  if (!slug || slug === 'general') return posts;
  return (posts || []).filter((p) => {
    if (String(p?.sourceType || '').toLowerCase() === 'youtube') return true;

    const postSlug = String(p?.category?.slug || '').toLowerCase();
    // Ingestion already assigns category from section RSS / API plan — trust it on read.
    if (postSlug === slug) {
      return !isLegacyMiscategorized(p, slug);
    }

    if (isLegacyMiscategorized(p, slug)) return false;
    return matchesFeedCategory(
      {
        title: p.title,
        summary: p.summary,
        body: p.body,
        sourceUrl: p.sourceUrl,
        sourceName: p.sourceName,
      },
      slug,
      {},
    );
  });
}

module.exports = {
  matchesFeedCategory,
  passesIngestCategoryGate,
  passesCategoryExclusions,
  isSectionSpecificSource,
  isLegacyMiscategorized,
  filterPostsForCategory,
};
