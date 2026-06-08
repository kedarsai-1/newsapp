#!/usr/bin/env node
/**
 * AI chat soak under concurrent virtual users (queue-aware timeouts).
 * Usage: node scripts/chat-soak-test.js [baseUrl]
 * Env: CHAT_SOAK_VUS=30 CHAT_SOAK_DURATION_SEC=120 CHAT_SOAK_LANG=te
 */
const BASE = (process.argv.find((a) => a.startsWith('http')) || 'http://127.0.0.1:5001').replace(/\/$/, '');
const VUS = Math.max(1, Number(process.env.CHAT_SOAK_VUS || 30));
const DURATION_SEC = Math.max(30, Number(process.env.CHAT_SOAK_DURATION_SEC || 120));
const LANG = String(process.env.CHAT_SOAK_LANG || 'te').toLowerCase();
const CLIENT_TIMEOUT_MS = Math.max(
  120_000,
  Number(process.env.CHAT_SOAK_CLIENT_TIMEOUT_MS || 360_000),
);

const QUESTIONS = {
  en: [
    'What are the latest cricket updates?',
    'Summarize Andhra Pradesh politics news.',
    'Any business market news today?',
  ],
  hi: [
    'आज की मुख्य राजनीति खबरें क्या हैं?',
    'क्रिकेट में क्या हुआ?',
  ],
  te: [
    'ఆంధ్ర ప్రదేశ్ రాజకీయ వార్తలు ఏమిటి?',
    'ఈరోజు క్రికెట్ వార్తలు చెప్పండి.',
    'తాజా వ్యాపార వార్తలు ఉన్నాయా?',
  ],
};

const stats = {
  total: 0,
  ok200: 0,
  aiGenerated: 0,
  extractive: 0,
  s504: 0,
  s503: 0,
  s5xx: 0,
  network: 0,
  latencies: [],
  headerErrors: 0,
};

function percentile(sorted, p) {
  if (!sorted.length) return 0;
  const idx = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[Math.max(0, idx)];
}

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

async function chatRequest(vuId) {
  const virtualIp = `10.88.${Math.floor(vuId / 256)}.${vuId % 256}`;
  const message = pick(QUESTIONS[LANG] || QUESTIONS.en);
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), CLIENT_TIMEOUT_MS);
  const start = Date.now();
  try {
    const res = await fetch(`${BASE}/api/news/chat`, {
      method: 'POST',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        'X-Forwarded-For': virtualIp,
      },
      body: JSON.stringify({ message, language: LANG, city: 'Hyderabad' }),
      signal: ac.signal,
    });
    const ms = Date.now() - start;
    const text = await res.text();
    let data = null;
    try { data = text ? JSON.parse(text) : null; } catch { data = null; }

    stats.total += 1;
    stats.latencies.push(ms);
    if (res.status === 200) {
      stats.ok200 += 1;
      if (data?.aiGenerated === true) stats.aiGenerated += 1;
      else stats.extractive += 1;
    } else if (res.status === 504) stats.s504 += 1;
    else if (res.status === 503) stats.s503 += 1;
    else if (res.status >= 500) stats.s5xx += 1;
    return { status: res.status, ms, aiGenerated: data?.aiGenerated === true };
  } catch (err) {
    stats.total += 1;
    stats.network += 1;
    return { status: 0, ms: Date.now() - start, error: err.message };
  } finally {
    clearTimeout(timer);
  }
}

async function vuLoop(vuId, endAt) {
  while (Date.now() < endAt) {
    // eslint-disable-next-line no-await-in-loop
    await chatRequest(vuId);
  }
}

async function main() {
  console.log(`\n=== CHAT SOAK: ${VUS} VUs × ${DURATION_SEC}s lang=${LANG} ===`);
  console.log(`Target: ${BASE}\n`);

  const health = await fetch(`${BASE}/api/health?refresh=1`).then((r) => r.json()).catch(() => null);
  console.log('Pre-soak health:', {
    postgres: health?.postgres,
    aiOk: health?.ai?.ok,
    chatModels: health?.ai?.chatModelsByLang,
  });

  const preRestarts = await import('node:child_process').then(({ execSync }) =>
    execSync("pm2 jlist 2>/dev/null | node -e \"let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const j=JSON.parse(d)[0];console.log(j.pm2_env.restart_time);})\"", { encoding: 'utf8' }).trim(),
  ).catch(() => '?');

  const endAt = Date.now() + DURATION_SEC * 1000;
  const workers = Array.from({ length: VUS }, (_, i) => vuLoop(i + 1, endAt));
  await Promise.all(workers);

  const sorted = [...stats.latencies].sort((a, b) => a - b);
  const aiRate = stats.ok200 ? ((stats.aiGenerated / stats.ok200) * 100).toFixed(1) : '0';

  console.log('\n--- CHAT SOAK SUMMARY ---');
  console.log(JSON.stringify({
    vus: VUS,
    durationSec: DURATION_SEC,
    totalRequests: stats.total,
    ok200: stats.ok200,
    aiGenerated: stats.aiGenerated,
    aiGeneratedPct: Number(aiRate),
    extractiveFallback: stats.extractive,
    http504: stats.s504,
    http503: stats.s503,
    server5xx: stats.s5xx,
    networkErrors: stats.network,
    latencyMs: {
      p50: percentile(sorted, 50),
      p95: percentile(sorted, 95),
      p99: percentile(sorted, 99),
      max: sorted[sorted.length - 1] || 0,
    },
  }, null, 2));

  const postRestarts = await import('node:child_process').then(({ execSync }) =>
    execSync("pm2 jlist 2>/dev/null | node -e \"let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const j=JSON.parse(d)[0];console.log(j.pm2_env.restart_time);})\"", { encoding: 'utf8' }).trim(),
  ).catch(() => '?');
  console.log(`PM2 restarts: ${preRestarts} → ${postRestarts}`);

  const pass = stats.s504 === 0 && stats.s5xx === 0 && stats.network === 0
    && Number(aiRate) >= 50;
  console.log(`\n=== CHAT SOAK: ${pass ? 'PASS' : 'FAIL'} ===\n`);
  process.exit(pass ? 0 : 1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
