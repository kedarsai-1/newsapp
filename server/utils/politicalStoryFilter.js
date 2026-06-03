const { decodeHtmlEntities } = require('./decodeHtmlEntities');

function storyText(postLike) {
  const raw = String(
    `${postLike?.title || ''} ${postLike?.summary || ''} ${postLike?.body || ''}`,
  );
  return decodeHtmlEntities(raw)
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]*>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

const NOISE_PATTERNS = {
  te: [
    /రాశి|జాతకం|హోరోస్కోప్|వాస్తు|పూజ|దేవాలయం|ధ్యానం|ఆధ్యాత్మిక/,
    /సినిమా|మూవీ|ట్రైలర్|టీజర్|ఓటిటి|బాక్సాఫీస్|హీరో|హీరోయిన్|సెలబ్రిటీ|పెడ్డి|రామ్ చరణ్/,
    /\b(movie|movies|film|trailer|teaser|ott|box office|hero|heroine|celebrity|cinema|bgm|pan-india|theater|theatre|blockbuster|peddi|ram charan)\b/i,
    /క్రికెట్|ఐపీఎల్|ఐపిఎల్|ఫుట్‌బాల్|కబడ్డీ|టోర్నమెంట్|మ్యాచ్|స్కోర్/,
    /హెల్త్|ఆరోగ్యం|డైట్|బ్యూటీ|రెసిపీ|లైఫ్‌స్టైల్|టిప్స్/,
    /జాబ్స్|ఉద్యోగ|ఎడ్యుకేషన్|ఎగ్జామ్|అడ్మిట్\s*కార్డ్|ఫలితాలు/,
  ],
  hi: [
    /राशिफल|कुंडली|ज्योतिष|वास्तु|धर्म|मंदिर|पूजा/,
    /फिल्म|मूवी|ट्रेलर|बॉक्स ऑफिस|बॉलीवुड|सेलिब्रिटी|सिनेमा/,
    /\b(movie|movies|film|trailer|teaser|ott|box office|bollywood|celebrity|cinema|bgm)\b/i,
    /क्रिकेट|आईपीएल|फुटबॉल|मैच|स्कोर|खेल/,
    /रेसिपी|ब्यूटी|स्किनकेयर|डाइट|हेल्थ टिप्स/,
    /सोना चोरी|गोल्ड थेफ्ट|आम की कीमत|मैंगो/i,
  ],
};

/** Hard reject: cinema, sports, astrology, etc. — used for politics feeds & politics tab. */
function isPoliticalNoise(postLike, language) {
  const lang = String(language || '').toLowerCase();
  const text = storyText(postLike);
  if (!text) return false;

  const patterns = [
    ...(NOISE_PATTERNS.te || []),
    ...(NOISE_PATTERNS.hi || []),
  ];
  if (lang === 'te') return NOISE_PATTERNS.te.some((re) => re.test(text));
  if (lang === 'hi') return NOISE_PATTERNS.hi.some((re) => re.test(text));
  return patterns.some((re) => re.test(text));
}

function teluguPoliticalScore(text) {
  const t = String(text || '').toLowerCase();
  let score = 0;
  const partyOrLeader = [
    /\b(ysrcp|ycp|tdp|bjp|congress|janasena|jsp|b(?:rs|rs)|trs|cpi|cpm|aimim)\b/i,
    /\b(jagan|ys\s*jagan|chandrababu|lokesh|pawan\s*kalyan|revanth|modi|rahul|kcr|kavitha|nirmala|amit shah)\b/i,
    /జగన్|చంద్రబాబు|రేవంత్|పవన్|కేసిఆర్|మోదీ|రాహుల్|మంత్రి|సీఎం|ముఖ్యమంత్రి/,
  ];
  const institutional = [
    /ఎన్నిక|పోలింగ్|ఓటు|పార్టీ|ప్రభుత్వం|ప్రతిపక్షం|మంత్రి|మంత్రివర్గం|కేబినెట్|ఎమ్మెల్యే|ఎంపీ|ఎమ్మెల్సీ|శాసనసభ|అసెంబ్లీ|లోక్‌సభ|రాజ్యసభ|కూటమి|మానిఫెస్టో|రాజకీయ|సభ|నిర్ణయం/,
    /\b(election|poll|vote|assembly|parliament|cabinet|minister|mla|mp|m[ -]?l[ -]?c|party|alliance|manifesto|politics?|government|rally|speech)\b/i,
  ];
  const regionalOrNational = [
    /ఆంధ్రప్రదేశ్|తెలంగాణ|అమరావతి|విజయవాడ|తాడేపల్లి|హైదరాబాద్|సచివాలయం|కేంద్ర|ఢిల్లీ|జాతీయ/,
    /\b(andhra\s*pradesh|telangana|amaravati|hyderabad|delhi|centre|central|india|nation)\b/i,
  ];

  if (partyOrLeader.some((re) => re.test(t))) score += 1;
  if (institutional.some((re) => re.test(t))) score += 1;
  if (regionalOrNational.some((re) => re.test(t))) score += 1;
  return score;
}

function hindiPoliticalScore(text) {
  const t = String(text || '');
  let score = 0;
  const partyOrLeader = [
    /\b(bjp|congress|aap|sp\b|bsp|jdu|rjd|tdp|ysrcp)\b/i,
    /\b(modi|rahul|yogi|kejriwal|akhilesh|nitish|tejashwi|shah|nadda|gandhi)\b/i,
    /मोदी|राहुल|योगी|केजरीवाल|शाह|गांधी|भाजपा|कांग्रेस|मुख्यमंत्री|सीएम/,
  ];
  const institutional = [
    /\b(election|poll|vote|assembly|parliament|cabinet|minister|mla|mp|party|manifesto|politics?|government|rally|policy)\b/i,
    /चुनाव|मंत्री|सरकार|विधानसभा|लोकसभा|राज्यसभा|पार्टी|राजनीति|कैबिनेट|संसद|केंद्र|दिल्ली|निर्णय/,
  ];
  const regionalOrNational = [
    /उत्तर प्रदेश|पंजाब|हरियाणा|राजस्थान|बिहार|दिल्ली|यूपी|लखनऊ|केंद्र|जातीय|राष्ट्रीय/,
    /\b(uttar pradesh|punjab|haryana|rajasthan|bihar|delhi|lucknow|chandigarh|centre|central|india)\b/i,
  ];

  if (partyOrLeader.some((re) => re.test(t))) score += 1;
  if (institutional.some((re) => re.test(t))) score += 1;
  if (regionalOrNational.some((re) => re.test(t))) score += 1;
  return score;
}

/** Relaxed: one political signal is enough (national + state politics). */
function isTeluguPoliticalStory(postLike) {
  const text = storyText(postLike);
  if (!text) return false;
  if (isPoliticalNoise(postLike, 'te')) return false;
  return teluguPoliticalScore(text) >= 1;
}

function isHindiPoliticalStory(postLike) {
  const text = storyText(postLike);
  if (!text) return false;
  if (isPoliticalNoise(postLike, 'hi')) return false;
  return hindiPoliticalScore(text) >= 1;
}

/** Optional stricter gate when INGEST_STRICT_POLITICS_FILTER=true. */
function isStrictPoliticalStory(postLike, language) {
  const lang = String(language || '').toLowerCase();
  const text = storyText(postLike);
  if (!text || isPoliticalNoise(postLike, lang)) return false;
  if (lang === 'te') return teluguPoliticalScore(text) >= 2;
  if (lang === 'hi') return hindiPoliticalScore(text) >= 2;
  return true;
}

/**
 * Politics RSS ingest: drop obvious non-political noise; keep real political rows.
 * Dedicated politics section feeds are trusted after the noise check.
 */
function acceptPoliticsRssItem(postLike, feedLang, { fromPoliticsFeed = true } = {}) {
  const lang = String(feedLang || '').toLowerCase();
  if (lang !== 'te' && lang !== 'hi') return true;
  if (isPoliticalNoise(postLike, lang)) return false;
  if (process.env.INGEST_STRICT_POLITICS_FILTER === 'true') {
    return isStrictPoliticalStory(postLike, lang);
  }
  if (fromPoliticsFeed) return true;
  return lang === 'te' ? isTeluguPoliticalStory(postLike) : isHindiPoliticalStory(postLike);
}

function isPoliticalStoryForLanguage(postLike, language) {
  const lang = String(language || '').toLowerCase();
  if (lang === 'te' || lang === 'hi') {
    if (isPoliticalNoise(postLike, lang)) return false;
    return true;
  }
  return true;
}

module.exports = {
  isPoliticalNoise,
  isTeluguPoliticalStory,
  isHindiPoliticalStory,
  isStrictPoliticalStory,
  acceptPoliticsRssItem,
  isPoliticalStoryForLanguage,
};
