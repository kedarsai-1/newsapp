const { prisma } = require('../config/prisma');
const {
  getWeatherByLocation,
  buildWeatherContext,
  isWeatherQuestion,
  hasValidCoords,
} = require('./weatherService');

const CONTEXT_DAYS = Math.max(7, Number(process.env.CHAT_CONTEXT_DAYS || 30));
const MAX_ARTICLES = Math.max(4, Math.min(12, Number(process.env.CHAT_MAX_ARTICLES || 6)));
const MAX_BODY_CHARS = Math.max(200, Number(process.env.CHAT_ARTICLE_BODY_CHARS || 400));
const MAX_SUMMARY_CHARS = Math.max(120, Number(process.env.CHAT_ARTICLE_SUMMARY_CHARS || 320));
const CHAT_INCLUDE_BODY = process.env.CHAT_INCLUDE_BODY === 'true';
const MAX_HISTORY_TURNS = Math.max(0, Math.min(6, Number(process.env.CHAT_MAX_HISTORY_TURNS || 4)));

const STOP_WORDS = new Set([
  'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
  'what', 'how', 'when', 'where', 'who', 'why', 'which', 'whom',
  'about', 'tell', 'me', 'give', 'latest', 'news', 'today', 'yesterday',
  'this', 'that', 'these', 'those', 'with', 'from', 'for', 'and', 'or',
  'can', 'you', 'please', 'summarize', 'summary', 'explain', 'brief',
  'happening', 'happened', 'update', 'updates', 'say', 'know',
  'weather', 'forecast', 'temperature', 'report', 'rain', 'humidity',
  'whats', 'what\'s', 'current', 'conditions', 'condition',
  'ఏమి', 'ఎలా', 'ఎప్పుడు', 'ఎక్కడ', 'ఈరోజు', 'నిన్న', 'సమాచారం', 'వార్తలు',
  'क्या', 'कैसे', 'कब', 'कहाँ', 'आज', 'कल', 'समाचार', 'बताओ', 'बताइए',
]);

const INTENT_CATEGORY = [
  { slug: 'sports', pattern: /cricket|ipl|sports|football|match|వన్డే|క్రికెట్|खेल|क्रिकेट|मैच/i },
  { slug: 'politics', pattern: /politic|election|modi|rahul|bjp|congress|parliament|assembly|రాజకీయ|ఎన్నిక|राजनीति|चुनाव|मोदी/i },
  { slug: 'business', pattern: /business|market|stock|economy|sensex|nifty|వ్యాపార|ఆర్థిక|व्यापार|बाजार|अर्थव्यवस्था/i },
  { slug: 'technology', pattern: /tech|technology|ai |artificial|smartphone|apple|google|టెక్|తంత్రజ్ఞాన|तकनीक|टेक्नोलॉजी/i },
  { slug: 'entertainment', pattern: /movie|film|bollywood|tollywood|celebrity|entertainment|సినిమా|ఎంటర్టైన్|फिल्म|बॉलीवुड|मनोरंजन/i },
  { slug: 'health', pattern: /health|medical|hospital|disease|covid|ఆరోగ్య|వైద్య|स्वास्थ्य|बीमारी/i },
  { slug: 'weather', pattern: /weather|rain|temperature|forecast|cyclone|storm|monsoon|వాతావరణ|వర్షం|मौसम|बारिश/i },
];

function extractKeywords(query) {
  return String(query || '')
    .toLowerCase()
    .replace(/[^\w\s\u0900-\u097F\u0C00-\u0C7F]/g, ' ')
    .split(/\s+/)
    .map((k) => k.trim())
    .filter((k) => k.length > 2 && !STOP_WORDS.has(k));
}

function detectCategorySlug(query) {
  for (const row of INTENT_CATEGORY) {
    if (row.pattern.test(query)) return row.slug;
  }
  return null;
}

/** Pull a place name from natural weather questions, e.g. "weather report for Pedanandipadu". */
function extractWeatherPlace(query) {
  const q = String(query || '').trim();
  if (!q || !isWeatherQuestion(q)) return null;

  const trailing = q.match(
    /\b(?:for|in|at|of|near)\s+([A-Za-z\u0900-\u097F\u0C00-\u0C7F][\w\s.'-]{1,48})\s*\??\s*$/iu,
  );
  if (trailing?.[1]) return trailing[1].trim();

  const prefix = q.match(
    /^([A-Za-z\u0900-\u097F\u0C00-\u0C7F][\w\s.'-]{1,48})\s+weather\b/iu,
  );
  if (prefix?.[1]) return prefix[1].trim();

  const placeKeywords = extractKeywords(q).filter((k) => ![
    'weather', 'forecast', 'temperature', 'report', 'rain', 'humidity',
    'cyclone', 'storm', 'monsoon', 'tomorrow', 'today',
  ].includes(k));
  if (placeKeywords.length === 1) return placeKeywords[0];
  if (placeKeywords.length > 1) return placeKeywords.join(' ');

  return null;
}

function sinceDate() {
  return new Date(Date.now() - CONTEXT_DAYS * 24 * 60 * 60 * 1000);
}

function truncateText(text, maxChars) {
  const raw = String(text || '').replace(/\s+/g, ' ').trim();
  if (raw.length <= maxChars) return raw;
  return `${raw.slice(0, maxChars)}…`;
}

function truncateBody(text) {
  return truncateText(text, MAX_BODY_CHARS);
}

function truncateSummary(text) {
  return truncateText(text, MAX_SUMMARY_CHARS);
}

function formatArticle(post, idx) {
  const date = post.sourcePublishedAt || post.createdAt;
  const dateStr = date ? new Date(date).toLocaleDateString() : '';
  const category = post.category?.name || post.category?.slug || '';
  const lines = [
    `[Article ${idx + 1}]`,
    `Title: ${post.title}`,
    category ? `Category: ${category}` : null,
    dateStr ? `Date: ${dateStr}` : null,
    post.summary ? `Summary: ${truncateSummary(post.summary)}` : null,
    post.body && CHAT_INCLUDE_BODY ? `Details: ${truncateBody(post.body)}` : null,
  ].filter(Boolean);
  return lines.join('\n');
}

function buildRelatedArticles(posts) {
  return posts.map((p) => ({
    id: p.id,
    title: p.title,
    summary: p.summary || null,
    category: p.category?.name || p.category?.slug || null,
    publishedAt: p.sourcePublishedAt || p.createdAt,
  }));
}

async function resolveCategoryId(slug) {
  if (!slug) return null;
  const cat = await prisma.category.findFirst({
    where: { slug: String(slug).toLowerCase(), isActive: true },
    select: { id: true },
  });
  return cat?.id || null;
}

async function fetchArticleById(articleId, lang) {
  if (!articleId) return null;
  const where = { id: String(articleId), status: 'approved' };
  if (lang === 'en' || lang === 'hi' || lang === 'te') where.language = lang;
  return prisma.newsPost.findFirst({
    where,
    select: {
      id: true,
      title: true,
      summary: true,
      body: true,
      sourcePublishedAt: true,
      createdAt: true,
      category: { select: { name: true, slug: true } },
    },
  });
}

async function searchNewsArticles({
  query,
  lang,
  keywords,
  categorySlug,
  city,
  excludeIds = [],
}) {
  const where = {
    status: 'approved',
    createdAt: { gte: sinceDate() },
  };
  if (lang === 'en' || lang === 'hi' || lang === 'te') where.language = lang;
  if (excludeIds.length) where.id = { notIn: excludeIds };

  const categoryId = await resolveCategoryId(categorySlug);
  if (categoryId) where.categoryId = categoryId;

  const cityName = String(city || '').trim();
  if (cityName) {
    where.locationCity = { equals: cityName, mode: 'insensitive' };
  }

  // When a category is detected (e.g. sports), do not require keyword hits in SQL —
  // cricket headlines rarely contain the word "sports".
  if (keywords.length && !categoryId) {
    const orClauses = [];
    for (const kw of keywords) {
      orClauses.push(
        { title: { contains: kw, mode: 'insensitive' } },
        { summary: { contains: kw, mode: 'insensitive' } },
        { body: { contains: kw, mode: 'insensitive' } },
        { tags: { has: kw } },
      );
    }
    where.OR = orClauses;
  }

  const rows = await prisma.newsPost.findMany({
    where,
    take: MAX_ARTICLES * 2,
    orderBy: [
      { isBreaking: 'desc' },
      { isFeatured: 'desc' },
      { sourcePublishedAt: 'desc' },
      { createdAt: 'desc' },
    ],
    select: {
      id: true,
      title: true,
      summary: true,
      body: true,
      sourcePublishedAt: true,
      createdAt: true,
      category: { select: { name: true, slug: true } },
    },
  });

  const filtered = filterArticlesForChat(rows, lang, categorySlug);
  const ranked = keywords.length
    ? rankArticlesByQuery(filtered, query)
    : filtered;
  return ranked.slice(0, MAX_ARTICLES);
}

async function fetchTrendingHeadlines({ lang, excludeIds = [], limit = 6, categorySlug = null }) {
  const where = {
    status: 'approved',
    createdAt: { gte: sinceDate() },
  };
  if (lang === 'en' || lang === 'hi' || lang === 'te') where.language = lang;
  if (excludeIds.length) where.id = { notIn: excludeIds };

  const categoryId = await resolveCategoryId(categorySlug);
  if (categoryId) where.categoryId = categoryId;

  const rows = await prisma.newsPost.findMany({
    where,
    take: limit * 2,
    orderBy: [
      { isBreaking: 'desc' },
      { sourcePublishedAt: 'desc' },
      { createdAt: 'desc' },
    ],
    select: {
      id: true,
      title: true,
      summary: true,
      body: true,
      sourcePublishedAt: true,
      createdAt: true,
      category: { select: { name: true, slug: true } },
    },
  });

  return filterArticlesForChat(rows, lang, categorySlug).slice(0, limit);
}

async function buildNewsContext({
  query,
  lang,
  articleId,
  category,
  city,
  hasLiveWeather = false,
  skipTrendingFallback = false,
}) {
  const keywords = extractKeywords(query);
  const intentSlug = detectCategorySlug(query);
  let categorySlug = category || intentSlug;
  const weatherQuery = isWeatherQuestion(query);
  // Weather questions: prefer live forecast; don't pull unrelated trending news.
  if (weatherQuery && (hasLiveWeather || skipTrendingFallback)) {
    categorySlug = category || 'weather';
  } else if (weatherQuery && !hasLiveWeather) {
    categorySlug = category || null;
  }
  const posts = [];
  const seen = new Set();

  const pushPost = (post) => {
    if (!post || seen.has(post.id)) return;
    seen.add(post.id);
    posts.push(post);
  };

  const pinned = await fetchArticleById(articleId, lang);
  if (pinned) pushPost(pinned);

  const matched = await searchNewsArticles({
    query,
    lang,
    keywords,
    categorySlug,
    city,
    excludeIds: [...seen],
  });
  for (const post of matched) pushPost(post);

  let usedTrendingFallback = false;
  if (!skipTrendingFallback && posts.length < 4) {
    usedTrendingFallback = true;
    const trending = await fetchTrendingHeadlines({
      lang,
      excludeIds: [...seen],
      limit: MAX_ARTICLES - posts.length,
      categorySlug: categorySlug || null,
    });
    for (const post of trending) pushPost(post);
  }

  const limited = rankArticlesByQuery(
    filterArticlesForChat(posts, lang, categorySlug),
    query,
  ).slice(0, MAX_ARTICLES);
  const text = limited.length
    ? limited.map((p, i) => formatArticle(p, i)).join('\n\n')
    : '';

  return {
    text,
    articles: limited,
    relatedArticles: buildRelatedArticles(limited),
    meta: {
      keywords,
      categorySlug: categorySlug || null,
      articlePinned: Boolean(pinned),
      trendingFallback: usedTrendingFallback && matched.length < 4,
      articleCount: limited.length,
    },
  };
}

function withChatBudget(promise, ms, label) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`${label}_timeout`)), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

function emptyNewsContext() {
  return {
    text: '',
    articles: [],
    relatedArticles: [],
    meta: {
      keywords: [],
      categorySlug: null,
      articlePinned: false,
      trendingFallback: false,
      articleCount: 0,
    },
  };
}

async function buildWeatherContextOptional({
  query,
  latitude,
  longitude,
  lat,
  lng,
  city,
  state,
  country,
}) {
  const inferredPlace = extractWeatherPlace(query);
  const resolvedCity = String(city || inferredPlace || '').trim();
  const hasLocation = hasValidCoords(latitude ?? lat, longitude ?? lng)
    || resolvedCity.length > 0;

  if (!hasLocation) {
    if (isWeatherQuestion(query)) {
      return {
        text: '[Live weather] Location not provided. Include a place in your question (e.g. "weather in Hyderabad") or enable GPS.',
        meta: null,
        inferredPlace: null,
      };
    }
    return { text: '', meta: null, inferredPlace: null };
  }

  try {
    const weather = await getWeatherByLocation({
      latitude, longitude, lat, lng, city: resolvedCity, state, country,
    });
    return {
      text: buildWeatherContext(weather),
      meta: {
        city: weather.location?.city,
        state: weather.location?.state,
        condition: weather.current?.condition,
        temperatureC: weather.current?.temperatureC,
        apparentTemperatureC: weather.current?.apparentTemperatureC,
        humidityPercent: weather.current?.humidityPercent,
        windSpeedKmh: weather.current?.windSpeedKmh,
        precipitationMm: weather.current?.precipitationMm,
        source: weather.location?.source,
        query: weather.location?.query || resolvedCity,
      },
      inferredPlace: inferredPlace || resolvedCity,
    };
  } catch (err) {
    console.warn('[ai-chat] Weather context skipped:', err.message);
    return {
      text: isWeatherQuestion(query)
        ? `[Live weather] Could not load forecast for "${resolvedCity}". ${err.message}`
        : '',
      meta: null,
      inferredPlace: inferredPlace || resolvedCity,
    };
  }
}

function buildSystemPrompt(lang) {
  if (lang === 'te') {
    return (
      'మీరు "NewsNow Assistant" — భారతీయ పాఠకుల కోసం తెలుగు వార్తా సహాయకుడు. '
      + 'రాజకీయాలు, క్రీడలు, వ్యాపారం, సాంకేతికత, మనోరంజనం, ఆరోగ్యం, స్థానిక వార్తలు, వాతావరణం. '
      + 'ఇచ్చిన వార్తా సందర్భం మరియు లైవ్ వాతావరణ బ్లాక్ మాత్రమే ఉపయోగించండి. '
      + 'ఇతర యాప్‌లు, వెబ్‌సైట్‌లు చూడమని చెప్పవద్దు. '
      + 'వాస్తవాలను కల్పించవద్దు. సందర్భం తక్కువైతే అది చెప్పండి. '
      + 'ప్రశ్న అడగవద్దు — సమాధానం మాత్రమే ఇవ్వండి. సందర్భంలోని వార్తలను సంగ్రహించండి. '
      + 'సమాధానం పూర్తిగా తెలుగు లిపిలో మాత్రమే. 2–6 వాక్యాలు. ఇంగ్లీష్ లేదు.'
    );
  }
  if (lang === 'hi') {
    return (
      'आप "NewsNow Assistant" हैं — भारतीय पाठकों के लिए हिंदी समाचार सहायक। '
      + 'राजनीति, खेल, व्यापार, तकनीक, मनोरंजन, स्वास्थ्य, स्थानीय समाचार, मौसम। '
      + 'केवल दिए गए समाचार संदर्भ और लाइव मौसम ब्लॉक का उपयोग करें। '
      + 'दूसरे ऐप या वेबसाइट देखने को न कहें। '
      + 'तथ्य गढ़ें नहीं। संदर्भ कम हो तो बताएं। '
      + 'प्रश्न मत पूछें — केवल उत्तर दें। संदर्भ की खबरों का सारांश दें। '
      + 'उत्तर पूरी तरह देवनागरी में ही। 2–6 वाक्य। अंग्रेज़ी नहीं।'
    );
  }
  return (
    'You are "NewsNow Assistant" — a Dailyhunt-style AI news companion for Indian readers. '
    + 'You help users understand the news: headlines, politics, sports, business, technology, '
    + 'entertainment, health, local stories, weather alerts, and current affairs. '
    + 'Use ONLY the provided news context and live weather block (if present). '
    + 'Never tell users to check other apps or websites. '
    + 'You may summarize, explain, compare, or give a quick briefing. '
    + 'Be friendly, factual, and objective. Do not invent facts not supported by the context. '
    + 'If live weather is unavailable, say you could not fetch it — do not substitute unrelated news headlines. '
    + 'If context is thin, say what is known from the articles and what is unclear. '
    + 'Respond in English only. Keep answers concise (2–6 sentences) unless the user asks for a detailed summary.'
  );
}

/** Stricter retry prompt when the first Indic answer is empty, English, or a refusal. */
function buildStrictSystemPrompt(lang) {
  if (lang === 'te') {
    return (
      'మీరు తెలుగు వార్తా సహాయకుడు. కింద ఇచ్చిన వార్తా సందర్భం నుండి మాత్రమే సమాధానం ఇవ్వండి. '
      + 'తెలుగు లిపిలో 2–4 వాక్యాలు. ఇంగ్లీష్, అపోలజీ, "నాకు యాక్సెస్ లేదు" అని చెప్పవద్దు.'
    );
  }
  if (lang === 'hi') {
    return (
      'आप हिंदी समाचार सहायक हैं। नीचे दिए संदर्भ से ही उत्तर दें। '
      + 'देवनागरी में 2–4 वाक्य। अंग्रेज़ी, माफी, "मुझे एक्सेस नहीं" न लिखें।'
    );
  }
  return buildSystemPrompt(lang);
}

function weatherFallbackAnswer(lang, place) {
  const where = place ? ` for ${place}` : '';
  if (lang === 'te') {
    return `"${where.trim() || 'ఆ ప్రదేశం'}" కోసం వాతావరణ సమాచారం లోడ్ కాలేదు. స్థలం పేరు సరిచూడండి లేదా GPS ప్రారంభించండి.`;
  }
  if (lang === 'hi') {
    return `मैं${where} का मौसम अभी लोड नहीं कर पाया। स्थान का नाम जाँचें या GPS चालू करें।`;
  }
  return `I couldn't load the weather forecast${where}. Check the place name or enable location, then try again.`;
}

function fallbackAnswer(lang) {
  if (lang === 'te') return 'ఈ అంశంపై తాజా వార్తల సమాచారం నాకు అందుబాటులో లేదు. మరొక ప్రశ్న అడగండి.';
  if (lang === 'hi') return 'इस विषय पर मेरे पास पर्याप्त हालिया समाचार नहीं है। कोई और सवाल पूछें।';
  return 'I do not have enough recent news on that topic. Try asking about a specific headline, person, or event.';
}

function buildWeatherAnswerFromMeta(meta, lang) {
  const place = [meta.city, meta.state].filter(Boolean).join(', ')
    || meta.query
    || 'the location';
  const cond = meta.condition || 'unknown conditions';
  const temp = meta.temperatureC != null ? `${meta.temperatureC}°C` : null;
  const feels = meta.apparentTemperatureC != null ? `${meta.apparentTemperatureC}°C` : null;
  const humidity = meta.humidityPercent != null ? `${meta.humidityPercent}%` : null;
  const wind = meta.windSpeedKmh != null ? `${meta.windSpeedKmh} km/h` : null;
  const rain = meta.precipitationMm != null ? `${meta.precipitationMm} mm` : null;

  if (lang === 'te') {
    const parts = [`${place}లో ప్రస్తుతం ${cond}`];
    if (temp) parts.push(`ఉష్ణోగ్రత ${temp}${feels ? ` (${feels} అనిపిస్తుంది)` : ''}`);
    if (humidity) parts.push(`తేమ ${humidity}`);
    if (wind) parts.push(`గాలి వేగం ${wind}`);
    if (rain && Number(meta.precipitationMm) > 0) parts.push(`వర్షపాతం ${rain}`);
    return `${parts.join(', ')}.`;
  }
  if (lang === 'hi') {
    const parts = [`${place} में अभी ${cond}`];
    if (temp) parts.push(`तापमान ${temp}${feels ? ` (महसूस ${feels})` : ''}`);
    if (humidity) parts.push(`नमी ${humidity}`);
    if (wind) parts.push(`हवा की गति ${wind}`);
    if (rain && Number(meta.precipitationMm) > 0) parts.push(`वर्षा ${rain}`);
    return `${parts.join(', ')}।`;
  }
  const parts = [`Current weather in ${place}: ${cond}`];
  if (temp) parts.push(`temperature ${temp}`);
  if (feels) parts.push(`feels like ${feels}`);
  if (humidity) parts.push(`humidity ${humidity}`);
  if (wind) parts.push(`wind ${wind}`);
  return `${parts.join(', ')}.`;
}

function formatHistory(history = []) {
  if (!Array.isArray(history) || !history.length) return '';
  const turns = history
    .filter((t) => t && (t.role === 'user' || t.role === 'assistant') && String(t.content || '').trim())
    .slice(-MAX_HISTORY_TURNS * 2)
    .map((t) => `${t.role === 'user' ? 'User' : 'Assistant'}: ${String(t.content).trim()}`);
  if (!turns.length) return '';
  return `Recent conversation:\n${turns.join('\n')}\n`;
}

function buildUserPrompt({
  context,
  query,
  history,
  isWeatherQuery,
  hasLiveWeather,
  lang = 'en',
}) {
  const historyBlock = formatHistory(history);
  const l = String(lang || 'en').toLowerCase();

  let weatherHint = null;
  let contextLabel = 'Context:';
  let questionLabel = 'User question:';
  let answerLabel = 'Answer using only the context above:';

  if (l === 'te') {
    contextLabel = 'సందర్భం:';
    questionLabel = 'వినియోగదారు ప్రశ్న:';
    answerLabel = isWeatherQuery
      ? 'లైవ్ వాతావరణ బ్లాక్ మాత్రమే ఉపయోగించి సమాధానం ఇవ్వండి:'
      : 'పై సందర్భం మాత్రమే ఉపయోగించి తెలుగులో సమాధానం ఇవ్వండి:';
    if (isWeatherQuery && hasLiveWeather) {
      weatherHint = 'సూచన: కింద లైవ్ వాతావరణ బ్లాక్ మాత్రమే ఉపయోగించండి. అసంబంధిత వార్తలు చెప్పవద్దు.';
    } else if (isWeatherQuery && !hasLiveWeather) {
      weatherHint = 'సూచన: వాతావరణం లోడ్ కాలేదు. స్థలం పేరు తప్పు కావచ్చు అని చెప్పండి. అసంబంధిత వార్తలు చెప్పవద్దు.';
    }
  } else if (l === 'hi') {
    contextLabel = 'संदर्भ:';
    questionLabel = 'उपयोगकर्ता प्रश्न:';
    answerLabel = isWeatherQuery
      ? 'केवल लाइव मौसम ब्लॉक का उपयोग कर उत्तर दें:'
      : 'ऊपर दिए संदर्भ से ही हिंदी में उत्तर दें:';
    if (isWeatherQuery && hasLiveWeather) {
      weatherHint = 'निर्देश: नीचे लाइव मौसम ब्लॉक ही उपयोग करें। असंबंधित समाचार न बताएं।';
    } else if (isWeatherQuery && !hasLiveWeather) {
      weatherHint = 'निर्देश: मौसम लोड नहीं हुआ। स्थान का नाम जाँचें। असंबंधित समाचार न बताएं।';
    }
  } else {
    weatherHint = isWeatherQuery && hasLiveWeather
      ? 'Instruction: Answer ONLY with the live weather block below. Do not mention unrelated news headlines.'
      : (isWeatherQuery && !hasLiveWeather
        ? 'Instruction: Live forecast is unavailable. Say you could not fetch weather for that place and ask the user to check the spelling or add state (e.g. Pedanandipadu, Andhra Pradesh). Do not summarize unrelated news.'
        : null);
    answerLabel = isWeatherQuery
      ? 'Answer the weather question using only the live weather block above:'
      : 'Answer using only the context above:';
  }

  const noContext = l === 'te'
    ? 'సరిపడా సందర్భం లేదు.'
    : (l === 'hi' ? 'पर्याप्त संदर्भ नहीं मिला।' : 'No matching context found.');

  return [
    historyBlock,
    weatherHint,
    `${contextLabel}\n${context || noContext}`,
    `${questionLabel} ${query}`,
    answerLabel,
  ].filter(Boolean).join('\n\n');
}

function isWeakRefusal(answer) {
  const t = String(answer || '');
  return /sorry|do not have access|don't have access|cannot provide|can't provide|recommend checking|weather channel|accuweather|real-time information|does not contain|no information about|not contain any information|i am an ai|as an ai|language model|check (?:the )?(?:news|website|web)|visit (?:our )?website|subscribe to|unable to provide|don't have (?:real-time|live|current)/i.test(t)
    || /నాకు.*(యాక్సెస్|సమాచారం).*లేదు|వెబ్‌సైట్|చూడండి|క్షమించ/i.test(t)
    || /मुझे.*(पता|जानकारी|एक्सेस).*नहीं|वेबसाइट|देखें|क्षमा|नहीं कर सकता/i.test(t);
}

function isAnswerInTargetLanguage(answer, lang) {
  const { validateLanguageOutput } = require('./aiProvider');
  return Boolean(validateLanguageOutput(answer, lang, {
    maxChars: Number(process.env.CHAT_ANSWER_MAX_CHARS || 700),
  }));
}

const BOILERPLATE_LINE = /youtube|facebook|twitter|instagram|telegram|subscribe|follow us|search us on|jansatta|live news|share this|download app|click here|http|www\./i;

/** Drop mis-tagged or wrong-script articles from chat context (e.g. Hindi body tagged language=en). */
function scriptRatios(text) {
  const t = String(text || '');
  const indic = (t.match(/[\u0900-\u0D7F]/g) || []).length;
  const latin = (t.match(/[A-Za-z]/g) || []).length;
  const telugu = (t.match(/[\u0C00-\u0C7F]/g) || []).length;
  const total = indic + latin + telugu;
  return { indic, latin, telugu, total };
}

function articleMatchesLanguage(article, lang) {
  const blob = `${article.title || ''} ${article.summary || ''}`;
  const { indic, latin, telugu, total } = scriptRatios(blob);
  if (total < 8) return true;

  if (lang === 'en') {
    return indic / total < 0.12 && telugu / total < 0.12;
  }
  if (lang === 'hi') {
    return indic / total >= 0.22;
  }
  if (lang === 'te') {
    return telugu / total >= 0.18 || indic / total >= 0.22;
  }
  return true;
}

function filterArticlesForChat(articles, lang, categorySlug = null) {
  const slug = categorySlug ? String(categorySlug).toLowerCase() : null;
  return (articles || []).filter((article) => {
    if (slug && article.category?.slug !== slug) return false;
    return articleMatchesLanguage(article, lang);
  });
}

/** Strip social/YouTube junk from RSS summaries used in extractive chat fallback. */
function sanitizeExtractiveText(text) {
  let t = String(text || '').trim();
  if (!t) return '';
  t = t.replace(/^\[संदर्भ\]\s*/i, '');
  t = t.replace(/^\[Article \d+\]\s*/im, '');
  t = t.replace(/https?:\/\/\S+/gi, ' ');
  t = t.replace(/\bwww\.\S+/gi, ' ');
  const sentences = t
    .split(/(?<=[.!?।])\s+|[\n\r]+/)
    .map((s) => s.replace(/\.{3,}/g, '.').trim())
    .filter((s) => s.length > 12 && !BOILERPLATE_LINE.test(s));
  t = sentences.join(' ').replace(/\s+/g, ' ').trim();
  return truncateText(t, 420);
}

/** Map Indic place names to Latin spellings used in ingested headlines. */
const PLACE_ALIASES = {
  delhi: ['delhi', 'दिल्ली', 'नई दिल्ली', 'new delhi'],
  hyderabad: ['hyderabad', 'हैदराबाद', 'హైదరాబాద్', 'హైదరాబాద్'],
  mumbai: ['mumbai', 'मुंबई', 'బాంబే'],
  chennai: ['chennai', 'चेन्नई', 'చెన్నై'],
  bangalore: ['bangalore', 'bengaluru', 'बेंगलुरु', 'బెంగళూరు'],
  andhra: ['andhra', 'ఆంధ్ర', 'आंध्र'],
  telangana: ['telangana', 'తెలంగాణ', 'तेलंगाना'],
};

function expandQueryKeywords(keywords) {
  const out = new Set(keywords.map((k) => String(k).toLowerCase()));
  for (const kw of keywords) {
    const low = String(kw).toLowerCase();
    for (const aliases of Object.values(PLACE_ALIASES)) {
      if (aliases.some((a) => a.toLowerCase() === low || low.includes(a.toLowerCase()))) {
        aliases.forEach((a) => out.add(a.toLowerCase()));
      }
    }
  }
  return [...out];
}

function scoreArticleForQuery(article, query) {
  const keywords = expandQueryKeywords(extractKeywords(query));
  const intentSlug = detectCategorySlug(query);
  const blob = `${article.title || ''} ${article.summary || ''}`.toLowerCase();
  let score = 0;
  for (const kw of keywords) {
    if (blob.includes(kw.toLowerCase())) score += 4;
  }
  if (intentSlug && article.category?.slug === intentSlug) score += 3;
  if (article.summary && article.summary.length > 50) score += 1;
  return score;
}

function rankArticlesByQuery(articles, query) {
  return [...articles].sort(
    (a, b) => scoreArticleForQuery(b, query) - scoreArticleForQuery(a, query),
  );
}

function isLowQualityAnswer(answer, { isWeatherQuery = false } = {}) {
  const t = String(answer || '').trim();
  if (!t) return true;
  if (isWeatherQuery) return t.length < 12;
  if (t.length < 40) return true;
  if (/^\[संदर्भ\]|^\[Live weather\]|\[Article \d+\]/i.test(t)) return true;
  if (/शीर्षकः|वर्णनः|^Title:/i.test(t)) return true;
  if (/[?？]\s*$/.test(t) && t.length < 120
    && /తెలుసా|ఏంటో|చెప్పమో|ఎలా ఉంది\?|बताइए|बताओ\?|क्या है\?/i.test(t)) {
    return true;
  }
  if (/కలుద్దాం|సిద్ధాంతంలో|గారూ\.\.\./i.test(t)) return true;
  return false;
}

function isAnswerRelevant(query, answer, keywords = []) {
  const kws = expandQueryKeywords(
    (keywords && keywords.length) ? keywords : extractKeywords(query),
  );
  if (!kws.length) return true;
  const ans = String(answer || '').toLowerCase();
  const hits = kws.filter((kw) => ans.includes(String(kw).toLowerCase())).length;
  if (hits >= 1) return true;
  return ans.length >= 100;
}

function isAcceptableChatAnswer(answer, lang, { query, keywords, isWeatherQuery } = {}) {
  if (!answer || isWeakRefusal(answer)) return false;
  if (!isAnswerInTargetLanguage(answer, lang)) return false;
  if (isLowQualityAnswer(answer, { isWeatherQuery })) return false;
  if (!isWeatherQuery && !isAnswerRelevant(query, answer, keywords)) return false;
  return true;
}

function extractiveFallback(articles, lang, query = '') {
  const intentSlug = detectCategorySlug(query);
  const pool = filterArticlesForChat(articles, lang, intentSlug);
  const ranked = rankArticlesByQuery(pool, query);
  const top = ranked
    .map((a) => ({
      ...a,
      clean: sanitizeExtractiveText(a.summary || a.title),
    }))
    .filter((a) => a.clean.length > 20 && articleMatchesLanguage({ ...a, title: a.clean, summary: '' }, lang))
    .slice(0, 2);
  if (!top.length) return fallbackAnswer(lang);

  if (lang === 'te') {
    const parts = top.map((a, i) => (
      i === 0 ? a.clean : `మరో వార్త: ${a.clean}`
    ));
    return parts.join(' ');
  }
  if (lang === 'hi') {
    const parts = top.map((a, i) => (
      i === 0 ? a.clean : `एक और खबर: ${a.clean}`
    ));
    return parts.join(' ');
  }
  return `Based on recent coverage: ${top.map((a) => a.clean).join(' ')}`;
}

async function generateChatAnswer({
  aiProvider,
  systemPrompt,
  userPrompt,
  lang,
  query,
  keywords,
  isWeatherQuery = false,
}) {
  const opts = { query, keywords, isWeatherQuery };
  let answer = '';
  try {
    answer = await aiProvider.chatWithOllama(systemPrompt, userPrompt, lang);
  } catch (err) {
    if (aiProvider.isOllamaAbortError(err)) {
      console.warn('[ai-chat] Ollama chat timed out or aborted; using extractive fallback.');
      return { answer: '', aiGenerated: false };
    }
    throw err;
  }

  if (isAcceptableChatAnswer(answer, lang, opts)) {
    return { answer, aiGenerated: true };
  }

  if (lang === 'hi' || lang === 'te') {
    try {
      const retry = await aiProvider.chatWithOllama(
        buildStrictSystemPrompt(lang),
        userPrompt,
        lang,
      );
      if (isAcceptableChatAnswer(retry, lang, opts)) {
        return { answer: retry, aiGenerated: true };
      }
    } catch (err) {
      if (!aiProvider.isOllamaAbortError(err)) throw err;
    }
  }

  return { answer: '', aiGenerated: false };
}

async function runNewsChat(input = {}) {
  const {
    message,
    language = 'en',
    latitude,
    longitude,
    lat,
    lng,
    city,
    state,
    country,
    articleId,
    category,
    history,
  } = input;

  const query = String(message || '').trim();
  const lang = String(language || 'en').toLowerCase().trim();
  const isWeatherQuery = isWeatherQuestion(query);

  const contextBudgetMs = Math.max(
    3000,
    Number(process.env.CHAT_CONTEXT_TIMEOUT_MS || 8000),
  );

  const weather = await withChatBudget(
    buildWeatherContextOptional({
      query, latitude, longitude, lat, lng, city, state, country,
    }),
    contextBudgetMs,
    'chat_weather',
  ).catch((err) => {
    console.warn('[ai-chat] Weather context budget exceeded:', err.message);
    return { text: '', meta: null, inferredPlace: extractWeatherPlace(query) };
  });

  const news = (isWeatherQuery && weather.meta)
    ? emptyNewsContext()
    : await withChatBudget(
      buildNewsContext({
        query,
        lang,
        articleId,
        category,
        city,
        hasLiveWeather: Boolean(weather.meta),
        skipTrendingFallback: isWeatherQuery,
      }),
      contextBudgetMs,
      'chat_news',
    ).catch((err) => {
      console.warn('[ai-chat] News context budget exceeded:', err.message);
      return emptyNewsContext();
    });

  const contextParts = [];
  if (weather.text) contextParts.push(weather.text);
  if (!isWeatherQuery || !weather.meta) {
    if (news.text) contextParts.push(news.text);
  }
  const context = contextParts.join('\n\n');
  const systemPrompt = buildSystemPrompt(lang);
  const userPrompt = buildUserPrompt({
    context,
    query,
    history,
    isWeatherQuery,
    hasLiveWeather: Boolean(weather.meta),
    lang,
  });

  const aiProvider = require('./aiProvider');
  const chatResult = await generateChatAnswer({
    aiProvider,
    systemPrompt,
    userPrompt,
    lang,
    query,
    keywords: news.meta.keywords,
    isWeatherQuery,
  });
  let answer = sanitizeExtractiveText(
    String(chatResult.answer || '').replace(/\[Article \d+\]/gi, '').trim(),
  );
  let aiGenerated = chatResult.aiGenerated;

  const minWeatherChars = Math.max(40, Number(process.env.CHAT_WEATHER_MIN_CHARS || 50));

  if (isWeatherQuery) {
    const weatherAnswerWeak = !answer
      || isWeakRefusal(answer)
      || isLowQualityAnswer(answer, { isWeatherQuery: true })
      || answer.length < minWeatherChars;
    if (weatherAnswerWeak) {
      if (weather.meta) {
        answer = buildWeatherAnswerFromMeta(weather.meta, lang);
      } else {
        answer = weatherFallbackAnswer(
          lang,
          weather.inferredPlace || extractWeatherPlace(query),
        );
      }
      aiGenerated = false;
    }
  } else if (news.articles.length > 0) {
    const needsFallback = !answer
      || !isAcceptableChatAnswer(answer, lang, {
        query,
        keywords: news.meta.keywords,
        isWeatherQuery: false,
      });
    if (needsFallback) {
      answer = extractiveFallback(news.articles, lang, query);
      aiGenerated = false;
    }
  } else if (!answer) {
    answer = fallbackAnswer(lang);
  }

  return {
    answer,
    aiGenerated,
    relatedArticles: news.relatedArticles,
    weather: weather.meta,
    sourcesUsed: {
      weather: Boolean(weather.meta),
      newsArticles: news.meta.articleCount,
      articlePinned: news.meta.articlePinned,
      trendingFallback: news.meta.trendingFallback,
      category: news.meta.categorySlug,
      keywords: news.meta.keywords,
    },
  };
}

module.exports = {
  runNewsChat,
  extractKeywords,
  detectCategorySlug,
  extractWeatherPlace,
  buildSystemPrompt,
  buildStrictSystemPrompt,
  isWeakRefusal,
  isAnswerInTargetLanguage,
  isLowQualityAnswer,
  isAnswerRelevant,
  isAcceptableChatAnswer,
  sanitizeExtractiveText,
  rankArticlesByQuery,
  extractiveFallback,
  filterArticlesForChat,
  articleMatchesLanguage,
  formatArticle,
  buildWeatherAnswerFromMeta,
  weatherFallbackAnswer,
  MAX_ARTICLES,
  CONTEXT_DAYS,
};
