const axios = require('axios');
const memoryCache = require('../utils/memoryCache');

const BASE = (process.env.CRICAPI_BASE_URL || 'https://api.cricapi.com/v1').replace(
  /\/$/,
  '',
);
const API_KEY = process.env.CRICAPI_KEY || process.env.CRIC_API_KEY || '';

const TTL_LIVE_MS = 30 * 1000;
const TTL_MATCH_MS = 60 * 1000;

const client = axios.create({
  baseURL: BASE,
  timeout: Number(process.env.CRICAPI_TIMEOUT_MS) || 12000,
});

function hasKey() {
  return Boolean(API_KEY && API_KEY.trim());
}

function pickThumb(match) {
  const infos = match.teamInfo || match.teamsInfo || [];
  for (const t of infos) {
    if (t?.img) return t.img;
  }
  return match.thumbnail || match.image || null;
}

function formatOvers(o) {
  if (o == null || o === '') return null;
  const n = Number(o);
  if (!Number.isFinite(n)) return String(o);
  return n % 1 === 0 ? String(n) : n.toFixed(1);
}

function parseTeams(match) {
  const names = Array.isArray(match.teams) ? match.teams : [];
  const scores = Array.isArray(match.score) ? match.score : [];
  const byInning = new Map();
  for (const s of scores) {
    const label = String(s.inning || s.innings || '').toLowerCase();
    byInning.set(label, s);
  }

  return names.slice(0, 2).map((name, idx) => {
    const teamName = String(name || '').trim();
    let score = null;
    let overs = null;
    for (const s of scores) {
      const inning = String(s.inning || '').toLowerCase();
      if (inning.includes(teamName.toLowerCase()) || inning.includes(`inning ${idx + 1}`)) {
        const runs = s.r ?? s.runs;
        const wkts = s.w ?? s.wickets;
        if (runs != null) {
          score = wkts != null ? `${runs}/${wkts}` : String(runs);
        }
        overs = formatOvers(s.o ?? s.overs);
        break;
      }
    }
    if (!score && scores[idx]) {
      const s = scores[idx];
      const runs = s.r ?? s.runs;
      const wkts = s.w ?? s.wickets;
      if (runs != null) score = wkts != null ? `${runs}/${wkts}` : String(runs);
      overs = formatOvers(s.o ?? s.overs);
    }
    const info = (match.teamInfo || []).find(
      (t) =>
        String(t.name || '').toLowerCase() === teamName.toLowerCase() ||
        String(t.shortname || t.shortName || '').toLowerCase() ===
          teamName.toLowerCase(),
    );
    return {
      name: teamName,
      shortName: info?.shortname || info?.shortName || teamName.slice(0, 3).toUpperCase(),
      score,
      overs,
    };
  });
}

function normalizeStatus(raw) {
  const s = String(raw || '').toLowerCase();
  if (s.includes('live') || s.includes('started') || s.includes('in progress')) {
    return 'live';
  }
  if (s.includes('not started') || s.includes('upcoming') || s.includes('scheduled')) {
    return 'upcoming';
  }
  if (s.includes('finished') || s.includes('completed') || s.includes('won')) {
    return 'finished';
  }
  return 'upcoming';
}

function normalizeMatchSummary(match) {
  const teams = parseTeams(match);
  const status = normalizeStatus(match.status || match.state || match.matchStarted);
  const time =
    match.dateTimeGMT ||
    match.dateTimeGmt ||
    match.date ||
    match.updatedAt ||
    null;

  return {
    id: String(match.id || match.unique_id || ''),
    teams,
    status,
    statusLabel: String(match.status || match.state || '').trim() || status,
    thumbnail: pickThumb(match),
    time,
    tournament: String(match.series || match.name || match.matchType || 'Cricket').slice(
      0,
      120,
    ),
    venue: String(match.venue || match.ground || '').slice(0, 120),
    result: match.result || match.status || null,
  };
}

function normalizeMatchDetail(raw) {
  const base = normalizeMatchSummary(raw);
  const highlights = [];
  const yt = raw.youtubeUrl || raw.youtube || raw.highlightUrl;
  if (yt) {
    highlights.push({
      id: `yt-${base.id}`,
      title: 'Match highlights',
      thumbnail: base.thumbnail,
      youtubeUrl: yt,
      duration: null,
    });
  }
  return {
    ...base,
    overs: teamsOversLine(raw),
    highlights,
  };
}

function teamsOversLine(match) {
  const teams = parseTeams(match);
  return teams
    .map((t) => (t.overs ? `${t.shortName} ${t.score || '-'} (${t.overs} ov)` : null))
    .filter(Boolean)
    .join(' · ');
}

async function cricGet(path, params = {}) {
  if (!hasKey()) {
    const err = new Error('CricAPI key not configured');
    err.code = 'CRICAPI_DISABLED';
    throw err;
  }
  const res = await client.get(path, {
    params: { apikey: API_KEY, ...params },
  });
  const body = res.data;
  if (body?.status !== 'success' && body?.success === false) {
    throw new Error(body?.message || body?.reason || 'CricAPI request failed');
  }
  return body;
}

async function fetchCurrentMatches() {
  const cacheKey = 'sports:currentMatches';
  const cached = memoryCache.get(cacheKey);
  if (cached) return cached;

  const body = await cricGet('/currentMatches', { offset: 0 });
  const list = Array.isArray(body.data) ? body.data : [];
  const normalized = list.map(normalizeMatchSummary).filter((m) => m.id);

  const live = normalized.filter((m) => m.status === 'live');
  const upcoming = normalized.filter((m) => m.status === 'upcoming');
  const finished = normalized.filter((m) => m.status === 'finished');

  const payload = { live, upcoming, finished, fetchedAt: new Date().toISOString() };
  memoryCache.set(cacheKey, payload, TTL_LIVE_MS);
  return payload;
}

async function fetchMatchById(id) {
  const cacheKey = `sports:match:${id}`;
  const cached = memoryCache.get(cacheKey);
  if (cached) return cached;

  const body = await cricGet('/match_info', { id });
  const raw = body.data || body;
  const detail = normalizeMatchDetail(raw);
  memoryCache.set(cacheKey, detail, TTL_MATCH_MS);
  return detail;
}

module.exports = {
  hasKey,
  fetchCurrentMatches,
  fetchMatchById,
  normalizeMatchSummary,
};
