const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  extractKeywords,
  detectCategorySlug,
  extractWeatherPlace,
  buildSystemPrompt,
  buildStrictSystemPrompt,
  buildWeatherAnswerFromMeta,
  isWeakRefusal,
  isLowQualityAnswer,
  isAnswerRelevant,
  isAcceptableChatAnswer,
  sanitizeExtractiveText,
  rankArticlesByQuery,
  extractiveFallback,
  formatArticle,
} = require('../../services/newsChatService');

describe('newsChatService', () => {
  it('extracts keywords and drops stop words', () => {
    const words = extractKeywords('What is the latest cricket news today?');
    assert.ok(words.includes('cricket'));
    assert.ok(!words.includes('what'));
    assert.ok(!words.includes('latest'));
    assert.ok(!words.includes('news'));
  });

  it('detects topic categories from natural questions', () => {
    assert.equal(detectCategorySlug('IPL match score update'), 'sports');
    assert.equal(detectCategorySlug('Modi election speech'), 'politics');
    assert.equal(detectCategorySlug('Apple new iPhone launch'), 'technology');
    assert.equal(detectCategorySlug('Will it rain tomorrow?'), 'weather');
    assert.equal(detectCategorySlug('random hello'), null);
  });

  it('extracts place names from weather questions', () => {
    assert.equal(
      extractWeatherPlace('whats weather report for pedanandipadu'),
      'pedanandipadu',
    );
    assert.equal(extractWeatherPlace('weather in Hyderabad'), 'Hyderabad');
    assert.equal(extractWeatherPlace('Delhi weather today'), 'Delhi');
    assert.equal(extractWeatherPlace('latest cricket news'), null);
  });

  it('uses native-language system prompts for hi/te', () => {
    assert.match(buildSystemPrompt('en'), /Dailyhunt-style/i);
    assert.match(buildSystemPrompt('hi'), /देवनागरी/);
    assert.match(buildSystemPrompt('te'), /తెలుగు లిపిలో/);
    assert.match(buildStrictSystemPrompt('hi'), /देवनागरी/);
    assert.match(buildStrictSystemPrompt('te'), /తెలుగు/);
  });

  it('detects weak refusals in English and Indic', () => {
    assert.equal(isWeakRefusal('Sorry, I do not have access to real-time information.'), true);
    assert.equal(isWeakRefusal('నాకు తాజా సమాచారం యాక్సెస్ లేదు'), true);
    assert.equal(isWeakRefusal('मुझे इसकी जानकारी नहीं है'), true);
    assert.equal(isWeakRefusal('హైదరాబాద్‌లో ఈరోజు వర్షం అవకాశం ఉంది'), false);
  });

  it('sanitizes extractive text and removes social boilerplate', () => {
    const raw = 'You can search us on youtube by: jansatta hindi news. . . . भारत ने मैच जीता।';
    const clean = sanitizeExtractiveText(raw);
    assert.match(clean, /भारत ने मैच जीता/);
    assert.doesNotMatch(clean, /youtube/i);
  });

  it('flags low-quality rhetorical answers', () => {
    assert.equal(isLowQualityAnswer('ఈరోజు క్రికెట్ వార్తలు ఏంటో తెలుసా?'), true);
    assert.equal(isLowQualityAnswer('సత్యనారాయణ గారూ... మనం సిద్ధాంతంలో కలుద్దాం.!'), true);
    assert.equal(
      isLowQualityAnswer('హైదరాబాద్‌లో ఈరోజు వర్షం అవకాశం ఉంది. తాపం 32 డిగ్రీలు.'),
      false,
    );
  });

  it('ranks articles by query keywords', () => {
    const articles = [
      { title: 'Philippines earthquake', summary: 'World news', category: { slug: 'politics' } },
      { title: 'Delhi metro update', summary: 'दिल्ली मेट्रो में नई लाइन', category: { slug: 'general' } },
    ];
    const ranked = rankArticlesByQuery(articles, 'दिल्ली की ताज़ा खबर');
    assert.match(ranked[0].title, /Delhi/i);
  });

  it('builds rich Hindi weather answers from meta', () => {
    const ans = buildWeatherAnswerFromMeta({
      city: 'Hyderabad',
      condition: 'overcast',
      temperatureC: 27.3,
      apparentTemperatureC: 30.5,
      humidityPercent: 70,
      windSpeedKmh: 9.6,
    }, 'hi');
    assert.match(ans, /Hyderabad|हैदराबाद/);
    assert.match(ans, /27\.3/);
    assert.match(ans, /नमी 70%/);
  });

  it('extractive fallback prefers cleaned summary text', () => {
    const out = extractiveFallback([
      {
        title: 'Cricket',
        summary: 'You can search us on youtube. मानव सुथार ने पहले टेस्ट में तीन विकेट लिए।',
        category: { slug: 'sports' },
      },
    ], 'hi', 'आज क्रिकेट की खबर');
    assert.match(out, /मानव सुथार/);
    assert.doesNotMatch(out, /youtube/i);
  });

  it('formats article context with summary by default (no body)', () => {
    const text = formatArticle({
      title: 'Test headline',
      summary: 'Short summary',
      body: 'Long body '.repeat(50),
      sourcePublishedAt: new Date('2026-06-07'),
      category: { name: 'Politics', slug: 'politics' },
    }, 0);
    assert.match(text, /Test headline/);
    assert.match(text, /Politics/);
    assert.match(text, /Summary: Short summary/);
    assert.doesNotMatch(text, /Details:/);
  });

  it('includes body snippet when CHAT_INCLUDE_BODY=true', () => {
    const prev = process.env.CHAT_INCLUDE_BODY;
    process.env.CHAT_INCLUDE_BODY = 'true';
    delete require.cache[require.resolve('../../services/newsChatService')];
    const { formatArticle: formatWithBody } = require('../../services/newsChatService');
    const text = formatWithBody({
      title: 'Test headline',
      summary: 'Short summary',
      body: 'Long body '.repeat(50),
      sourcePublishedAt: new Date('2026-06-07'),
      category: { name: 'Politics', slug: 'politics' },
    }, 0);
    assert.match(text, /Details:/);
    delete require.cache[require.resolve('../../services/newsChatService')];
    if (prev === undefined) delete process.env.CHAT_INCLUDE_BODY;
    else process.env.CHAT_INCLUDE_BODY = prev;
  });
});
