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
    /\b(recipe|diet tips|skincare|beauty tips|gold theft|jewellery theft|mango price|costco)\b/i,
    /\b(lover|affair|dating|wedding photos?|viral video|tiktok|instagram reel)\b/i,
    /(క్రికెట్|ఐపీఎల్|సినిమా|రాశి|జాతకం|నగలు|దొంగతనం|మామిడి|ప్రేమ|లవర్|వైరల్)/,
    /(क्रिकेट|फिल्म|राशिफल|चोरी|आम|प्रेम)/,
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
  // Politics/local: always require on-topic keywords (RSS section feeds still leak crime/lifestyle).
  if (slug === 'politics' || slug === 'local') {
    return matchesFeedCategory(item, categorySlug, { feedUrl });
  }
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
      /\b(politics|election|government|minister|parliament|assembly|party|vote|poll|cabinet|policy|bjp|congress|modi|mla|mp|cm\b|chief minister|bjp|tdp|ysrcp|jagan|revanth|kcr|rahul)\b|(రాజకీయ|ఎన్నిక|మంత్రి|పార్టీ|శాసనసభ|ముఖ్యమంత్రి|సీఎం|ఎమ్మెల్యే|ఎంపీ|లోక్‌సభ|రాజ్యసభ|రేవంత్|జగన్|చంద్రబాబు|కేసిఆర్|राजनीति|चुनाव|मंत्री|सरकार)/i,
    technology:
      /\b(tech|technology|smartphone|android|ios|ai\b|artificial intelligence|software|hardware|gadget|cyber|semiconductor|chip)\b|(టెక్నాలజీ|స్మార్ట్|टेक्नोलॉजी|स्मार्टफोन)/i,
    entertainment:
      /\b(movie|film|cinema|actor|actress|bollywood|tollywood|music|celebrity|ott|netflix|trailer|box office|tv show|series)\b|(సినిమా|ట్రైలర్|సినిమాల|फिल्म|बॉलीवुड|मनोरंजन)/i,
    health:
      /\b(health|medical|doctor|hospital|disease|vaccine|wellness|fitness|nutrition|mental health|covid|cancer|diabetes)\b|(ఆరోగ్య|వైద్య|स्वास्थ्य|डॉक्टर)/i,
    education:
      /\b(education|school|college|university|exam|student|teacher|admission|scholarship|degree|campus|neet|jee|upsc)\b|(విద్య|పరీక్ష|शिक्षा|परीक्षा|विद्यार्थी)/i,
    local:
      /\b(city|local|traffic|metro|municipal|hyderabad|delhi|mumbai|chennai|bangalore|amaravati|vijayawada|warangal|andhra|telangana|guntur|visakhapatnam|lucknow|chandigarh|noida|patna|jaipur)\b|(హైదరాబాద్|అమరావతి|విజయవాడ|ఆంధ్ర|తెలంగాణ|वाराणसी|लखनऊ|पंजाब|हरियाणा|राजस्थान|बिहार|उत्तर प्रदेश|दिल्ली|हैदराबाद)/i,
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

function postMatchesRegionalPoliticsScope(p, politicsScope) {
  const ps = String(politicsScope || '').toLowerCase();
  const rowScope = String(p?.politicsScope || '').toLowerCase();
  if (!ps || ps === 'all') return true;
  if (ps === 'andhra') return rowScope === 'andhra';
  if (ps === 'telangana') return rowScope === 'telangana';
  if (ps === 'north') return ['north', 'states', 'delhi'].includes(rowScope);
  return false;
}

function storyTextFromPost(p) {
  return `${p?.title || ''} ${p?.summary || ''} ${p?.body || ''}`;
}

/** Post-filter: keep International chip free of AP/TG/North/India-only rows (mis-tagged RSS). */
function postMatchesPoliticsScopeFilter(p, politicsScope) {
  const ps = String(politicsScope || '').toLowerCase();
  if (!ps || ps === 'all') return true;

  const text = storyTextFromPost(p);
  const rowScope = String(p?.politicsScope || '').toLowerCase();
  const lang = String(p?.language || '').toLowerCase();

  const apTgRegional =
    /(ఆంధ్ర|తెలంగాణ|amaravati|vijayawada|visakhapatnam|guntur|warangal|hyderabad|karimnagar|kurnool|nellore|హైదరాబాద్|అమరావతి|విజయవాడ)/i.test(text)
    || /\b(andhra pradesh|telangana|amaravati)\b/i.test(text);
  const northRegional =
    /(उत्तर प्रदेश|पंजाब|हरियाणा|राजस्थान|बिहार|दिल्ली|यूपी|lucknow|chandigarh|noida)/.test(text)
    || /\b(uttar pradesh|punjab|haryana|rajasthan|bihar)\b/i.test(text);
  const worldMarkers =
    /\b(trump|biden|putin|ukraine|gaza|nato|white house|united nations|britain|uk\b|europe|china|pakistan)\b/i.test(text)
    || /(विदेश|अंतर्राष्ट्रीय|ब्रिटेन|अमेरिका|यूक्रेन|ट्रंप|बाइडेन|पाकिस्तान|चीन)/.test(text)
    || /(విదేశ|అంతర్జాతీయ|అమెరికా|ట్రంప్|బైడెన్|పాకిస్తాన్|చైనా|బ్రిటన్|యూక్రేన్)/i.test(text);

  if (ps === 'international') {
    if (['andhra', 'telangana', 'north', 'states', 'delhi'].includes(rowScope)) return false;
    if (apTgRegional && !worldMarkers) return false;
    if (northRegional && !worldMarkers) return false;
    if (lang === 'te' && rowScope === 'india' && !worldMarkers) return false;
    return true;
  }

  if (ps === 'india') {
    if (rowScope === 'international') return false;
    if (worldMarkers && !/(మోదీ|राहुल|modi|rahul|parliament|lok sabha|ఎన్నిక|चुनाव|bjp|congress)/i.test(text)) {
      return false;
    }
    if (apTgRegional || northRegional) return false;
    return true;
  }

  if (ps === 'andhra' || ps === 'telangana' || ps === 'north') {
    return postMatchesRegionalPoliticsScope(p, ps);
  }

  return true;
}

/** Filter feed rows so category tabs only return on-topic stories. */
function filterPostsForCategory(posts, categorySlug, { politicsScope } = {}) {
  const slug = String(categorySlug || '').toLowerCase();
  const scope = String(politicsScope || '').toLowerCase();
  if (!slug || slug === 'general') return posts;

  return (posts || []).filter((p) => {
    if (String(p?.sourceType || '').toLowerCase() === 'youtube') return true;

    const item = {
      title: p.title,
      summary: p.summary,
      body: p.body,
      sourceUrl: p.sourceUrl,
      sourceName: p.sourceName,
    };
    const postSlug = String(p?.category?.slug || '').toLowerCase();

    // Politics tab + AP/TG/North chip: keep Local-category rows merged from the API query.
    if (
      slug === 'politics'
      && ['andhra', 'telangana', 'north'].includes(scope)
      && postSlug === 'local'
      && postMatchesRegionalPoliticsScope(p, scope)
    ) {
      return matchesFeedCategory(item, 'local', {}) || matchesFeedCategory(item, 'politics', {});
    }

    if (slug === 'politics' && !postMatchesPoliticsScopeFilter(p, scope)) return false;

    if (postSlug === slug) {
      if (isLegacyMiscategorized(p, slug)) return false;
      if (slug === 'politics' || slug === 'local') {
        return matchesFeedCategory(item, slug, {});
      }
      return true;
    }

    if (isLegacyMiscategorized(p, slug)) return false;
    return matchesFeedCategory(item, slug, {});
  });
}

module.exports = {
  matchesFeedCategory,
  passesIngestCategoryGate,
  passesCategoryExclusions,
  isSectionSpecificSource,
  isLegacyMiscategorized,
  postMatchesPoliticsScopeFilter,
  filterPostsForCategory,
};
