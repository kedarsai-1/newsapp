#!/usr/bin/env node
/**
 * Targeted AI chat monkey / smoke test.
 * Usage: node scripts/chat-monkey-test.js [baseUrl] [rounds]
 */
const BASE = (process.argv[2] || 'http://127.0.0.1:5001').replace(/\/$/, '');
const ROUNDS = Math.max(1, Number(process.argv[3] || process.env.CHAT_MONKEY_ROUNDS || 5));

const GARBAGE = ['', ' ', 'x'.repeat(8000), '<script>', '🔥'.repeat(100), null];
const PROMPTS = [
  'What is latest cricket news?',
  'Summarize Modi news today',
  'weather report for Hyderabad',
  'whats weather report for pedanandipadu',
  'Tell me about IPL',
  'ఈరోజు వార్తలు',
  'आज की खबर',
  'random gibberish xyzqwerty',
];

const stats = {
  total: 0,
  ok200: 0,
  err400: 0,
  err503: 0,
  err504: 0,
  err500: 0,
  network: 0,
  aiGenerated: 0,
  extractiveFallback: 0,
  emptyAnswer: 0,
  weatherUsed: 0,
  newsDumpOnWeather: 0,
  doubleJson: 0,
  slowOver60s: 0,
  crashes: [],
};

async function chat(body, timeoutMs = 90000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  const start = Date.now();
  try {
    const res = await fetch(`${BASE}/api/news/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      signal: controller.signal,
      body: JSON.stringify(body),
    });
    const ms = Date.now() - start;
    const text = await res.text();
    let parsed = null;
    let doubleJson = false;
    try {
      parsed = JSON.parse(text);
    } catch {
      const parts = text.split('\n').filter((l) => l.trim().startsWith('{'));
      if (parts.length > 1) {
        doubleJson = true;
        parsed = JSON.parse(parts[0]);
      }
    }
    return { status: res.status, ms, parsed, text: text.slice(0, 400), doubleJson };
  } catch (err) {
    return { status: 0, ms: Date.now() - start, error: err.message };
  } finally {
    clearTimeout(timer);
  }
}

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function isNewsDumpOnWeather(answer, message) {
  if (!/weather|rain|forecast|temperature|मौसम|వాతావర/i.test(message)) return false;
  return /Based on recent coverage|Delhi|Israel|LPG|fire broke out/i.test(String(answer || ''));
}

async function oneRound(i) {
  const message = Math.random() < 0.3 ? pick(GARBAGE) : pick(PROMPTS);
  const body = {
    message: message ?? 'hello',
    language: pick(['en', 'hi', 'te', 'fr', '']),
    city: Math.random() < 0.4 ? pick(['Hyderabad', 'Pedanandipadu', 'Delhi', '']) : undefined,
    latitude: pick([17.385, null, 'bad']),
    longitude: pick([78.487, null, 'bad']),
    history: Math.random() < 0.2
      ? [{ role: 'user', content: 'hi' }, { role: 'assistant', content: 'Hello!' }]
      : [],
  };

  const r = await chat(body);
  stats.total += 1;

  if (r.status === 0) {
    stats.network += 1;
    stats.crashes.push({ round: i, error: r.error, body: body.message });
    return;
  }
  if (r.status === 200) stats.ok200 += 1;
  else if (r.status === 400) stats.err400 += 1;
  else if (r.status === 503) stats.err503 += 1;
  else if (r.status === 504) stats.err504 += 1;
  else if (r.status >= 500) stats.err500 += 1;

  if (r.ms > 60000) stats.slowOver60s += 1;
  if (r.doubleJson) stats.doubleJson += 1;

  const d = r.parsed;
  if (d?.success && r.status === 200) {
    if (d.aiGenerated) stats.aiGenerated += 1;
    else if (d.answer) stats.extractiveFallback += 1;
    if (!d.answer?.trim()) stats.emptyAnswer += 1;
    if (d.weather || d.sourcesUsed?.weather) stats.weatherUsed += 1;
    if (isNewsDumpOnWeather(d.answer, body.message)) {
      stats.newsDumpOnWeather += 1;
      stats.crashes.push({ round: i, bug: 'weather_news_dump', message: body.message, answer: d.answer?.slice(0, 200) });
    }
  }
  if (r.status >= 500) {
    stats.crashes.push({ round: i, status: r.status, message: body.message, data: r.text || r.parsed });
  }
}

async function sequentialSmoke() {
  const cases = [
    { label: 'news-en', body: { message: 'Latest IPL cricket news headline?', language: 'en' } },
    { label: 'weather-city', body: { message: 'weather in Hyderabad today', language: 'en', city: 'Hyderabad' } },
    { label: 'weather-place-parse', body: { message: 'whats weather report for pedanandipadu', language: 'en' } },
    { label: 'empty-msg', body: { message: '', language: 'en' } },
    { label: 'huge-msg', body: { message: 'x'.repeat(8000), language: 'en' } },
  ];
  const smoke = [];
  for (const c of cases) {
    const r = await chat(c.body, 120000);
    smoke.push({
      label: c.label,
      status: r.status,
      ms: r.ms,
      aiGenerated: r.parsed?.aiGenerated,
      hasAnswer: Boolean(r.parsed?.answer?.trim()),
      weather: Boolean(r.parsed?.weather || r.parsed?.sourcesUsed?.weather),
      answerPreview: r.parsed?.answer?.slice(0, 120),
    });
  }
  return smoke;
}

async function main() {
  console.log(`Chat monkey test → ${BASE} (${ROUNDS} random rounds + smoke)`);
  const health = await fetch(`${BASE}/api/health`).then((r) => r.json()).catch(() => null);
  console.log('Health AI:', health?.ai?.ok, health?.ai?.chatModelsByLang);

  const smoke = await sequentialSmoke();
  console.log('\n=== SMOKE CASES ===');
  console.log(JSON.stringify(smoke, null, 2));

  for (let i = 0; i < ROUNDS; i += 1) {
    process.stdout.write(`Random round ${i + 1}/${ROUNDS}... `);
    await Promise.all(Array.from({ length: 4 }, () => oneRound(i)));
    console.log('done');
  }

  console.log('\n=== CHAT MONKEY SUMMARY ===');
  console.log(JSON.stringify(stats, null, 2));

  const passRate = stats.total ? ((stats.ok200 / stats.total) * 100).toFixed(1) : 0;
  const aiRate = stats.ok200 ? ((stats.aiGenerated / stats.ok200) * 100).toFixed(1) : 0;
  console.log(`\nPass rate (200): ${passRate}% | True AI on 200s: ${aiRate}%`);

  const failed = stats.err500 + stats.network + stats.doubleJson + stats.newsDumpOnWeather > 0;
  process.exit(failed ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
