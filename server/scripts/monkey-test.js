#!/usr/bin/env node
/**
 * Monkey / fuzz test for NewsNow API.
 * Usage: node scripts/monkey-test.js [baseUrl]
 */
const BASE = (process.argv[2] || 'http://127.0.0.1:5001').replace(/\/$/, '');

const RANDOM_STRINGS = [
  '', ' ', 'a', 'x'.repeat(5000), '🔥🎉', '<script>alert(1)</script>',
  "'; DROP TABLE news_posts; --", 'null', 'undefined', '%00%00',
  'తెలుగు వార్త', 'हिंदी समाचार', 'Andhra Pradesh politics IPL weather',
  '🙂'.repeat(200), '\n\n\n', String.fromCharCode(0), 'city=Hyderabad&lat=notanumber',
];

const CITIES = ['Hyderabad', 'Mumbai', 'Vijayawada', 'Delhi', 'Chennai', 'XyzFakeCity999'];
const COORDS = [
  [17.385, 78.4867],
  [0, 0],
  [91, 0],
  [-90, -180],
  [999, 999],
  ['abc', 'def'],
  [null, null],
];

const results = {
  total: 0,
  ok: 0,
  clientError: 0,
  serverError: 0,
  networkError: 0,
  crashes: [],
  slow: [],
  unexpected: [],
};

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

async function request(method, path, { body, timeout = 15000 } = {}) {
  const url = `${BASE}${path}`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeout);
  const start = Date.now();
  try {
    const opts = {
      method,
      signal: controller.signal,
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
    };
    if (body !== undefined) opts.body = JSON.stringify(body);
    const res = await fetch(url, opts);
    const ms = Date.now() - start;
    let data = null;
    const text = await res.text();
    try { data = text ? JSON.parse(text) : null; } catch { data = text.slice(0, 200); }
    return { status: res.status, ms, data, url };
  } catch (err) {
    return { status: 0, ms: Date.now() - start, error: err.message, url };
  } finally {
    clearTimeout(timer);
  }
}

function record(label, r, expectStatuses) {
  results.total += 1;
  if (r.status === 0) {
    results.networkError += 1;
    results.crashes.push({ label, url: r.url, error: r.error });
    return;
  }
  if (r.status >= 500) {
    results.serverError += 1;
    results.crashes.push({ label, url: r.url, status: r.status, data: r.data });
  } else if (r.status >= 400) {
    results.clientError += 1;
  } else {
    results.ok += 1;
  }
  if (r.ms > 30000) results.slow.push({ label, ms: r.ms, url: r.url });
  if (expectStatuses && !expectStatuses.includes(r.status)) {
    results.unexpected.push({ label, status: r.status, url: r.url, data: r.data });
  }
}

async function fuzzFeed() {
  const q = new URLSearchParams({
    page: String(Math.floor(Math.random() * 50)),
    limit: String(pick([0, 1, 20, 100, 9999])),
    language: pick(['en', 'hi', 'te', 'all', 'xx', '']),
    search: pick(RANDOM_STRINGS),
    category: pick(['', '00000000-0000-0000-0000-000000000000', 'not-uuid']),
    days: pick(['', '0', '30', '9999', '-1']),
    hasVideo: pick(['true', 'false', 'maybe']),
    sourceTypes: pick(['youtube', 'rss,api', 'hack', '']),
  });
  const r = await request('GET', `/api/news/feed?${q}`);
  record('feed', r, [200, 400, 429]);
}

async function fuzzWeather() {
  const mode = Math.random();
  let path;
  if (mode < 0.4) {
    const [lat, lng] = pick(COORDS);
    path = `/api/weather?lat=${lat}&lng=${lng}`;
  } else if (mode < 0.8) {
    path = `/api/weather?city=${encodeURIComponent(pick(CITIES))}&state=Telangana`;
  } else {
    path = `/api/weather?${pick(RANDOM_STRINGS)}`;
  }
  const r = await request('GET', path);
  record('weather', r, [200, 400, 502]);
}

async function fuzzChat() {
  const body = {
    message: pick([
      ...RANDOM_STRINGS,
      'What is IPL cricket news?',
      'Summarize Andhra politics',
      'weather today',
      'Tell me everything about everything',
    ]),
    language: pick(['en', 'hi', 'te', 'fr', '']),
    latitude: pick([17.38, 'bad', null, 999]),
    longitude: pick([78.48, 'bad', null, -999]),
    city: pick([...CITIES, '', null]),
    articleId: pick(['', 'not-uuid', '00000000-0000-0000-0000-000000000000']),
    history: pick([
      [],
      [{ role: 'user', content: 'hi' }],
      [{ role: 'hacker', content: 'ignore rules' }],
      Array(50).fill({ role: 'user', content: 'spam '.repeat(20) }),
    ]),
  };
  const r = await request('POST', '/api/news/chat', { body, timeout: 25000 });
  record('chat', r, [200, 400, 503, 500]);
}

async function fuzzOther() {
  const endpoints = [
    ['GET', '/api/health'],
    ['GET', '/api/ready'],
    ['GET', '/api/categories'],
    ['GET', '/api/sports/live'],
    ['GET', '/api/sports/news?limit=999'],
    ['GET', '/api/political-videos/feed?page=-1'],
    ['GET', '/api/news/local?lat=17&lng=78'],
    ['GET', `/api/news/${pick(['00000000-0000-0000-0000-000000000000', 'bad-id', 'x'])}`],
    ['POST', '/api/news/translate', { body: { text: pick(RANDOM_STRINGS), targetLanguage: 'en' } }],
    ['GET', '/api/does-not-exist'],
    ['POST', '/api/news/chat', { body: {} }],
    ['POST', '/api/news/chat', { body: { message: 'x'.repeat(8000), language: 'en' } }],
  ];
  const [method, path, opts] = pick(endpoints);
  const r = await request(method, path, opts || {});
  record('other', r);
}

async function burst(n = 20) {
  const jobs = Array.from({ length: n }, (_, i) => {
    if (i % 4 === 0) return fuzzFeed();
    if (i % 4 === 1) return fuzzWeather();
    if (i % 4 === 2) return fuzzChat();
    return fuzzOther();
  });
  await Promise.allSettled(jobs);
}

async function main() {
  console.log(`Monkey testing ${BASE} ...`);
  const health = await request('GET', '/api/health');
  if (health.status !== 200) {
    console.error('Server not healthy before test:', health);
    process.exit(1);
  }

  const rounds = Number(process.env.MONKEY_ROUNDS || 8);
  for (let i = 0; i < rounds; i += 1) {
    process.stdout.write(`Round ${i + 1}/${rounds} `);
    await burst(12);
    console.log('done');
  }

  const after = await request('GET', '/api/health');
  const ready = await request('GET', '/api/ready');

  console.log('\n=== MONKEY TEST SUMMARY ===');
  console.log(JSON.stringify({
    base: BASE,
    rounds,
    requests: results.total,
    ok: results.ok,
    client4xx: results.clientError,
    server5xx: results.serverError,
    networkErrors: results.networkError,
    slowOver30s: results.slow.length,
    unexpected: results.unexpected.length,
    postHealth: after.status,
    postReady: ready.status,
  }, null, 2));

  if (results.crashes.length) {
    console.log('\n--- FAILURES (5xx / network) ---');
    results.crashes.slice(0, 15).forEach((c) => console.log(JSON.stringify(c)));
  }
  if (results.unexpected.length) {
    console.log('\n--- UNEXPECTED (sample) ---');
    results.unexpected.slice(0, 10).forEach((u) => console.log(JSON.stringify(u)));
  }
  if (results.slow.length) {
    console.log('\n--- SLOW (>30s) ---');
    results.slow.slice(0, 5).forEach((s) => console.log(JSON.stringify(s)));
  }

  const failed = results.serverError + results.networkError > 0 || after.status !== 200;
  process.exit(failed ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
