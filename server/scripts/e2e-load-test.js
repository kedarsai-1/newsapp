#!/usr/bin/env node
/**
 * Backend E2E functional + concurrent load test.
 * Usage: node scripts/e2e-load-test.js [baseUrl] [--load-only] [--e2e-only]
 */
const BASE = (process.argv.find((a) => a.startsWith('http')) || 'http://127.0.0.1:5001').replace(/\/$/, '');
const LOAD_ONLY = process.argv.includes('--load-only');
const E2E_ONLY = process.argv.includes('--e2e-only');
const CONCURRENT_USERS = Number(process.env.LOAD_VUS || 100);
const LOAD_DURATION_SEC = Number(process.env.LOAD_DURATION_SEC || 60);
const LOAD_RPS_TARGET = Number(process.env.LOAD_RPS_TARGET || 0); // 0 = max per VU loop

const e2e = { pass: 0, fail: 0, cases: [] };
const load = {
  total: 0,
  ok: 0,
  client4xx: 0,
  server5xx: 0,
  network: 0,
  rateLimited: 0,
  latencies: [],
  byEndpoint: {},
};

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function percentile(sorted, p) {
  if (!sorted.length) return 0;
  const idx = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[Math.max(0, idx)];
}

async function request(method, path, {
  body,
  token,
  virtualIp,
  timeout = 30000,
  label,
} = {}) {
  const url = `${BASE}${path}`;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeout);
  const start = Date.now();
  const headers = { Accept: 'application/json' };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  if (token) headers.Authorization = `Bearer ${token}`;
  if (virtualIp) headers['X-Forwarded-For'] = virtualIp;

  try {
    const res = await fetch(url, {
      method,
      headers,
      body: body !== undefined ? JSON.stringify(body) : undefined,
      signal: controller.signal,
    });
    const ms = Date.now() - start;
    const text = await res.text();
    let data = null;
    try { data = text ? JSON.parse(text) : null; } catch { data = text.slice(0, 300); }
    return { status: res.status, ms, data, url, label: label || path };
  } catch (err) {
    return { status: 0, ms: Date.now() - start, error: err.message, url, label: label || path };
  } finally {
    clearTimeout(timer);
  }
}

function assertCase(name, condition, detail = '') {
  if (condition) {
    e2e.pass += 1;
    e2e.cases.push({ name, status: 'PASS', detail });
  } else {
    e2e.fail += 1;
    e2e.cases.push({ name, status: 'FAIL', detail });
  }
}

function recordLoad(r, endpoint) {
  load.total += 1;
  const key = endpoint || r.label || r.url;
  if (!load.byEndpoint[key]) {
    load.byEndpoint[key] = { total: 0, ok: 0, err: 0, latencies: [] };
  }
  const bucket = load.byEndpoint[key];
  bucket.total += 1;
  if (r.status === 0) {
    load.network += 1;
    bucket.err += 1;
  } else if (r.status === 429) {
    load.rateLimited += 1;
    load.client4xx += 1;
    bucket.err += 1;
  } else if (r.status >= 500) {
    load.server5xx += 1;
    bucket.err += 1;
  } else if (r.status >= 400) {
    load.client4xx += 1;
    bucket.err += 1;
  } else {
    load.ok += 1;
    bucket.ok += 1;
    load.latencies.push(r.ms);
    bucket.latencies.push(r.ms);
  }
}

async function runE2E() {
  console.log('\n=== E2E FUNCTIONAL TESTS ===\n');

  const health = await request('GET', '/api/health');
  assertCase('GET /api/health returns 200', health.status === 200, `status=${health.status}`);
  assertCase('Health includes postgres connected', health.data?.postgres === 'connected');
  assertCase('Health includes push block', Boolean(health.data?.push?.configured));

  const ready = await request('GET', '/api/ready');
  assertCase('GET /api/ready returns 200', ready.status === 200, `status=${ready.status}`);

  const adminLogin = await request('POST', '/api/auth/login', {
    body: { email: 'admin@newsapp.com', password: 'Admin@123' },
  });
  assertCase('Admin login returns 200 + token', adminLogin.status === 200 && Boolean(adminLogin.data?.token));
  const adminToken = adminLogin.data?.token;

  const reporterLogin = await request('POST', '/api/auth/login', {
    body: { email: 'reporter@newsapp.com', password: 'Reporter@123' },
  });
  assertCase('Reporter login returns 200 + token', reporterLogin.status === 200 && Boolean(reporterLogin.data?.token));
  const reporterToken = reporterLogin.data?.token;

  const badLogin = await request('POST', '/api/auth/login', {
    body: { email: 'admin@newsapp.com', password: 'wrong' },
  });
  assertCase('Bad password returns 401', badLogin.status === 401);

  const me = await request('GET', '/api/auth/me', { token: adminToken });
  assertCase('GET /api/auth/me with token returns 200', me.status === 200 && me.data?.user?.role === 'admin');

  const noAuth = await request('GET', '/api/auth/me');
  assertCase('GET /api/auth/me without token returns 401', noAuth.status === 401);

  const categories = await request('GET', '/api/categories');
  assertCase('GET /api/categories returns 200', categories.status === 200);
  assertCase('Categories list is non-empty', Array.isArray(categories.data?.categories) && categories.data.categories.length > 0);

  const feedEn = await request('GET', '/api/news/feed?page=1&limit=20&language=en');
  assertCase('GET /api/news/feed?language=en returns 200', feedEn.status === 200);
  assertCase('Feed has posts array', Array.isArray(feedEn.data?.posts));
  assertCase('Feed pagination metadata present', feedEn.data?.page !== undefined && feedEn.data?.hasMore !== undefined);

  const feedHi = await request('GET', '/api/news/feed?page=1&limit=10&language=hi');
  assertCase('GET /api/news/feed?language=hi returns 200', feedHi.status === 200);

  const feedTe = await request('GET', '/api/news/feed?page=1&limit=10&language=te');
  assertCase('GET /api/news/feed?language=te returns 200', feedTe.status === 200);

  const badLang = await request('GET', '/api/news/feed?language=xx');
  assertCase('Invalid language returns 400', badLang.status === 400);

  const postId = feedEn.data?.posts?.[0]?.id || feedEn.data?.posts?.[0]?._id;
  if (postId) {
    const post = await request('GET', `/api/news/${postId}`);
    assertCase('GET /api/news/:id returns 200', post.status === 200 && post.data?.post?.id);
    const comments = await request('GET', `/api/news/${postId}/comments`);
    assertCase('GET /api/news/:id/comments returns 200', comments.status === 200);
  } else {
    assertCase('GET /api/news/:id returns 200', false, 'no posts in feed to test');
    assertCase('GET /api/news/:id/comments returns 200', false, 'no posts in feed to test');
  }

  const invalidId = await request('GET', '/api/news/not-a-uuid');
  assertCase('Invalid post UUID returns 400', invalidId.status === 400);

  const dash = await request('GET', '/api/admin/dashboard', { token: adminToken });
  assertCase('Admin dashboard returns 200', dash.status === 200);

  const dashNoAuth = await request('GET', '/api/admin/dashboard');
  assertCase('Admin dashboard without token returns 401', dashNoAuth.status === 401);

  const reporterDash = await request('GET', '/api/admin/dashboard', { token: reporterToken });
  assertCase('Admin dashboard as reporter returns 403', reporterDash.status === 403);

  const pending = await request('GET', '/api/admin/posts/pending', { token: adminToken });
  assertCase('Admin pending posts returns 200', pending.status === 200);

  const weather = await request('GET', '/api/weather?city=Hyderabad&state=Telangana');
  assertCase('GET /api/weather returns 200', weather.status === 200);

  const sports = await request('GET', '/api/sports/live');
  assertCase('GET /api/sports/live returns 200', sports.status === 200);

  const political = await request('GET', '/api/political-videos/feed?page=1&limit=10');
  assertCase('GET /api/political-videos/feed returns 200', political.status === 200);

  const reporterStats = await request('GET', '/api/reporter/stats', { token: reporterToken });
  assertCase('Reporter stats returns 200', reporterStats.status === 200);

  const badFcm = await request('PUT', '/api/auth/fcm-token', {
    token: adminToken,
    body: { fcmToken: 'short' },
  });
  assertCase('Invalid FCM token returns 400', badFcm.status === 400);

  const goodFcm = await request('PUT', '/api/auth/fcm-token', {
    token: adminToken,
    body: { fcmToken: `e2e-test-token-${Date.now()}-${'x'.repeat(40)}` },
  });
  assertCase('Valid FCM token returns 200', goodFcm.status === 200);

  const slug = categories.data?.categories?.[0]?.slug;
  if (slug) {
    const catBySlug = await request('GET', `/api/categories/by-slug/${slug}`);
    assertCase('GET /api/categories/by-slug/:slug returns 200', catBySlug.status === 200);
  }

  const feedCat = await request('GET', `/api/news/feed?category=${categories.data?.categories?.[0]?.slug || 'politics'}&limit=5`);
  assertCase('GET /api/news/feed?category=slug returns 200', feedCat.status === 200);

  for (const c of e2e.cases.filter((x) => x.status === 'FAIL')) {
    console.log(`  FAIL: ${c.name} — ${c.detail}`);
  }
  console.log(`\nE2E: ${e2e.pass} passed, ${e2e.fail} failed (${e2e.pass + e2e.fail} total)\n`);
}

const LOAD_SCENARIOS = [
  { weight: 40, method: 'GET', path: () => '/api/news/feed?page=1&limit=20&language=en', label: 'feed_en' },
  { weight: 15, method: 'GET', path: () => '/api/categories', label: 'categories' },
  { weight: 10, method: 'GET', path: (ctx) => ctx.postId ? `/api/news/${ctx.postId}` : '/api/news/feed?page=1&limit=1', label: 'post_detail' },
  { weight: 10, method: 'GET', path: () => '/api/health', label: 'health' },
  { weight: 8, method: 'GET', path: () => '/api/weather?city=Hyderabad&state=Telangana', label: 'weather' },
  { weight: 7, method: 'GET', path: () => '/api/sports/live', label: 'sports_live' },
  { weight: 5, method: 'GET', path: () => '/api/political-videos/feed?page=1&limit=10', label: 'political_feed' },
  { weight: 5, method: 'GET', path: () => '/api/news/feed?page=2&limit=20&language=hi', label: 'feed_hi' },
];

function pickScenario() {
  const total = LOAD_SCENARIOS.reduce((s, x) => s + x.weight, 0);
  let r = Math.random() * total;
  for (const s of LOAD_SCENARIOS) {
    r -= s.weight;
    if (r <= 0) return s;
  }
  return LOAD_SCENARIOS[0];
}

async function virtualUserLoop(vuId, ctx, endAt) {
  const virtualIp = `10.99.${Math.floor(vuId / 256)}.${vuId % 256}`;
  let token = ctx.tokens[vuId % ctx.tokens.length];

  while (Date.now() < endAt) {
    const scenario = pickScenario();
    const path = typeof scenario.path === 'function' ? scenario.path(ctx) : scenario.path;
    const r = await request(scenario.method, path, {
      token: scenario.label === 'auth_me' ? token : undefined,
      virtualIp,
      label: scenario.label,
    });
    recordLoad(r, scenario.label);

    if (LOAD_RPS_TARGET > 0) {
      await new Promise((res) => setTimeout(res, 1000 / LOAD_RPS_TARGET));
    }
  }
}

async function runLoadTest() {
  console.log(`\n=== LOAD TEST: ${CONCURRENT_USERS} concurrent users for ${LOAD_DURATION_SEC}s ===\n`);

  const feed = await request('GET', '/api/news/feed?page=1&limit=5&language=en');
  const postId = feed.data?.posts?.[0]?.id || feed.data?.posts?.[0]?._id || null;

  const tokens = [];
  const login = await request('POST', '/api/auth/login', {
    body: { email: 'admin@newsapp.com', password: 'Admin@123' },
  });
  if (login.data?.token) tokens.push(login.data.token);

  for (let i = 0; i < 5; i += 1) {
    const email = `loadtest${Date.now()}${i}@e2e.test`;
    const reg = await request('POST', '/api/auth/register', {
      body: { name: `Load User ${i}`, email, password: 'Test1234', role: 'user' },
      virtualIp: `10.98.0.${i + 1}`,
    });
    if (reg.data?.token) tokens.push(reg.data.token);
  }

  const ctx = { postId, tokens: tokens.length ? tokens : [null] };
  const endAt = Date.now() + LOAD_DURATION_SEC * 1000;
  const startMem = process.memoryUsage();

  const workers = [];
  for (let vu = 0; vu < CONCURRENT_USERS; vu += 1) {
    workers.push(virtualUserLoop(vu + 1, ctx, endAt));
  }

  console.log(`  Started ${CONCURRENT_USERS} virtual users (unique X-Forwarded-For per VU)...`);
  await Promise.all(workers);

  const sorted = [...load.latencies].sort((a, b) => a - b);
  const errorRate = load.total ? ((load.server5xx + load.network) / load.total * 100).toFixed(2) : '0';
  const successRate = load.total ? ((load.ok / load.total) * 100).toFixed(2) : '0';

  console.log('\n--- LOAD TEST SUMMARY ---');
  console.log(JSON.stringify({
    concurrentUsers: CONCURRENT_USERS,
    durationSec: LOAD_DURATION_SEC,
    totalRequests: load.total,
    successful: load.ok,
    successRatePct: Number(successRate),
    client4xx: load.client4xx,
    rateLimited429: load.rateLimited,
    server5xx: load.server5xx,
    networkErrors: load.network,
    errorRatePct: Number(errorRate),
    latencyMs: {
      min: sorted[0] || 0,
      p50: percentile(sorted, 50),
      p95: percentile(sorted, 95),
      p99: percentile(sorted, 99),
      max: sorted[sorted.length - 1] || 0,
      avg: sorted.length ? Math.round(sorted.reduce((a, b) => a + b, 0) / sorted.length) : 0,
    },
    requestsPerSec: (load.total / LOAD_DURATION_SEC).toFixed(1),
  }, null, 2));

  console.log('\n--- PER ENDPOINT ---');
  for (const [ep, stats] of Object.entries(load.byEndpoint).sort((a, b) => b[1].total - a[1].total)) {
    const lat = [...stats.latencies].sort((a, b) => a - b);
    console.log(`  ${ep}: ${stats.ok}/${stats.total} ok, p95=${percentile(lat, 95)}ms`);
  }

  const postHealth = await request('GET', '/api/health');
  console.log('\n--- POST-LOAD HEALTH ---');
  console.log(`  status=${postHealth.status}, postgres=${postHealth.data?.postgres}, push.enabled=${postHealth.data?.push?.enabled}`);

  return {
    passed: load.server5xx === 0 && load.network === 0 && Number(errorRate) < 5,
    errorRate: Number(errorRate),
    p95: percentile(sorted, 95),
  };
}

async function main() {
  console.log(`Backend E2E + Load Test → ${BASE}`);
  let loadResult = { passed: true, errorRate: 0, p95: 0 };

  if (!LOAD_ONLY) await runE2E();
  if (!E2E_ONLY) loadResult = await runLoadTest();

  const e2eOk = e2e.fail === 0;
  const overall = (LOAD_ONLY || e2eOk) && loadResult.passed;

  console.log(`\n=== OVERALL: ${overall ? 'PASS' : 'FAIL'} ===\n`);
  process.exit(overall ? 0 : 1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
