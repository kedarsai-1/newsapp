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

  const orClauses = [];
  if (keywords.length) {
    for (const kw of keywords) {
      orClauses.push(
        { title: { contains: kw, mode: 'insensitive' } },
        { summary: { contains: kw, mode: 'insensitive' } },
        { body: { contains: kw, mode: 'insensitive' } },
        { tags: { has: kw } },
      );
    }
  }
  if (orClauses.length) where.OR = orClauses;

  return prisma.newsPost.findMany({
    where,
    take: MAX_ARTICLES,
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
}

async function fetchTrendingHeadlines({ lang, excludeIds = [], limit = 6 }) {
  const where = {
    status: 'approved',
    createdAt: { gte: sinceDate() },
  };
  if (lang === 'en' || lang === 'hi' || lang === 'te') where.language = lang;
  if (excludeIds.length) where.id = { notIn: excludeIds };

  return prisma.newsPost.findMany({
    where,
    take: limit,
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
}

async function buildNewsContext({
  query,
  lang,
  articleId,
  category,
  city,
  hasLiveWeather = false,
}) {
  const keywords = extractKeywords(query);
  const intentSlug = detectCategorySlug(query);
  let categorySlug = category || intentSlug;
  // Without live weather, search weather keywords across all news (weather tab may be sparse).
  if (isWeatherQuestion(query) && !hasLiveWeather) {
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
  if (posts.length < 4) {
    usedTrendingFallback = true;
    const trending = await fetchTrendingHeadlines({
      lang,
      excludeIds: [...seen],
      limit: MAX_ARTICLES - posts.length,
    });
    for (const post of trending) pushPost(post);
  }

  const limited = posts.slice(0, MAX_ARTICLES);
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
  const hasLocation = hasValidCoords(latitude ?? lat, longitude ?? lng)
    || String(city || '').trim().length > 0;

  if (!hasLocation) {
    if (isWeatherQuestion(query)) {
      return {
        text: '[Live weather] GPS/city not sent — no live forecast. Answer using weather-related news articles in the context below.',
        meta: null,
      };
    }
    return { text: '', meta: null };
  }

  try {
    const weather = await getWeatherByLocation({
      latitude, longitude, lat, lng, city, state, country,
    });
    return {
      text: buildWeatherContext(weather),
      meta: {
        city: weather.location?.city,
        state: weather.location?.state,
        condition: weather.current?.condition,
        temperatureC: weather.current?.temperatureC,
        source: weather.location?.source,
      },
    };
  } catch (err) {
    console.warn('[ai-chat] Weather context skipped:', err.message);
    return {
      text: isWeatherQuestion(query)
        ? '[Live weather] Could not load live weather. Use weather news articles in context if available.'
        : '',
      meta: null,
    };
  }
}

function buildSystemPrompt(lang) {
  const base =
    'You are "NewsNow Assistant" — a Dailyhunt-style AI news companion for Indian readers. '
    + 'You help users understand the news: headlines, politics, sports, business, technology, '
    + 'entertainment, health, local stories, weather alerts, and current affairs. '
    + 'Use ONLY the provided news context and live weather block (if present). '
    + 'Never tell users to check other apps or websites. '
    + 'You may summarize, explain, compare, or give a quick briefing. '
    + 'Be friendly, factual, and objective. Do not invent facts not supported by the context. '
    + 'If live weather is unavailable, answer from weather-related news articles in the context. '
    + 'If context is thin, say what is known from the articles and what is unclear.';

  if (lang === 'te') {
    return `${base} Respond in Telugu only (Telugu script). Keep answers concise (2–6 sentences) unless the user asks for a detailed summary.`;
  }
  if (lang === 'hi') {
    return `${base} Respond in Hindi only (Devanagari script). Keep answers concise (2–6 sentences) unless the user asks for a detailed summary.`;
  }
  return `${base} Respond in English only. Keep answers concise (2–6 sentences) unless the user asks for a detailed summary.`;
}

function fallbackAnswer(lang) {
  if (lang === 'te') return 'ఈ అంశంపై తాజా వార్తల సమాచారం నాకు అందుబాటులో లేదు. మరొక ప్రశ్న అడగండి.';
  if (lang === 'hi') return 'इस विषय पर मेरे पास पर्याप्त हालिया समाचार नहीं है। कोई और सवाल पूछें।';
  return 'I do not have enough recent news on that topic. Try asking about a specific headline, person, or event.';
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

function buildUserPrompt({ context, query, history, isWeatherQuery, hasLiveWeather }) {
  const historyBlock = formatHistory(history);
  const weatherHint = isWeatherQuery && !hasLiveWeather
    ? 'Instruction: Live forecast is unavailable. Summarize weather-related facts from the news articles below. Do not say you lack real-time access.'
    : null;
  return [
    historyBlock,
    weatherHint,
    `News context:\n${context || 'No matching articles found. Give a helpful response and say coverage is limited.'}`,
    `User question: ${query}`,
    'Answer using only the news context above:',
  ].filter(Boolean).join('\n\n');
}

function isWeakRefusal(answer) {
  return /sorry|do not have access|don't have access|cannot provide|can't provide|recommend checking|weather channel|accuweather|real-time information|does not contain|no information about|not contain any information/i.test(
    String(answer || ''),
  );
}

function extractiveFallback(articles, lang) {
  const lines = articles
    .filter((a) => a.summary || a.title)
    .slice(0, 3)
    .map((a) => a.summary || a.title);
  if (!lines.length) return fallbackAnswer(lang);
  if (lang === 'te') return `తాజా వార్తల ప్రకారం: ${lines.join(' ')}`;
  if (lang === 'hi') return `हालिया समाचार के अनुसार: ${lines.join(' ')}`;
  return `Based on recent coverage: ${lines.join(' ')}`;
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

  const contextBudgetMs = Math.max(
    3000,
    Number(process.env.CHAT_CONTEXT_TIMEOUT_MS || 8000),
  );

  const [weather, news] = await Promise.all([
    withChatBudget(
      buildWeatherContextOptional({
        query, latitude, longitude, lat, lng, city, state, country,
      }),
      contextBudgetMs,
      'chat_weather',
    ).catch((err) => {
      console.warn('[ai-chat] Weather context budget exceeded:', err.message);
      return { text: '', meta: null };
    }),
    withChatBudget(
      buildNewsContext({
        query,
        lang,
        articleId,
        category,
        city,
        hasLiveWeather: false,
      }),
      contextBudgetMs,
      'chat_news',
    ).catch((err) => {
      console.warn('[ai-chat] News context budget exceeded:', err.message);
      return emptyNewsContext();
    }),
  ]);

  const contextParts = [];
  if (weather.text) contextParts.push(weather.text);
  if (news.text) contextParts.push(news.text);
  const context = contextParts.join('\n\n');

  const isWeatherQuery = isWeatherQuestion(query);
  const systemPrompt = buildSystemPrompt(lang);
  const userPrompt = buildUserPrompt({
    context,
    query,
    history,
    isWeatherQuery,
    hasLiveWeather: Boolean(weather.meta),
  });

  const aiProvider = require('./aiProvider');
  let answer = '';
  let aiGenerated = false;
  try {
    answer = await aiProvider.chatWithOllama(systemPrompt, userPrompt, lang);
    aiGenerated = Boolean(answer);
  } catch (err) {
    if (aiProvider.isOllamaAbortError(err)) {
      console.warn('[ai-chat] Ollama chat timed out or aborted; using extractive fallback.');
      answer = '';
    } else {
      throw err;
    }
  }
  const shouldUseExtractive = news.articles.length > 0 && (
    !answer
    || isWeakRefusal(answer)
    || (isWeatherQuery && !weather.meta)
  );
  if (shouldUseExtractive) {
    answer = extractiveFallback(news.articles, lang);
    aiGenerated = false;
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
  buildSystemPrompt,
  formatArticle,
  MAX_ARTICLES,
  CONTEXT_DAYS,
};
