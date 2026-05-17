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

function matchStatusText(match) {
  return String(match?.status || match?.state || match?.msg || '').trim();
}

/** Classify using CricAPI fields — status strings often contain scores, not the word "live". */
function detectMatchStatus(match) {
  const text = matchStatusText(match).toLowerCase();
  const started = match?.matchStarted === true || match?.matchStarted === 'true';

  if (started) return 'live';

  if (
    /match not started|not started yet|starts at|scheduled|upcoming/i.test(text)
    && !/\d+\s*\/\s*\d+/.test(text)
  ) {
    return 'upcoming';
  }

  if (
    /won by|won the|beat |defeated|drawn|tied|no result|abandon|finished|completed|match over/i.test(
      text,
    )
  ) {
    return 'finished';
  }

  if (
    /live|in progress|innings break|stumps|lunch|tea|drinks break|play ongoing|need \d+ runs/i.test(
      text,
    )
  ) {
    return 'live';
  }

  const scores = Array.isArray(match?.score) ? match.score : [];
  const hasRuns = scores.some((s) => {
    const r = s?.r ?? s?.runs;
    return r != null && r !== '';
  });
  if (hasRuns) {
    if (/won|draw|tie|no result|abandon/i.test(text)) return 'finished';
    return 'live';
  }

  if (/\d+\s*\/\s*\d+/.test(text)) return 'live';

  if (text.includes('not started') || text.includes('scheduled')) return 'upcoming';

  return 'upcoming';
}

function normalizeStatus(raw) {
  return detectMatchStatus(typeof raw === 'object' && raw !== null ? raw : { status: raw });
}

function isIplOrMajorLeague(match) {
  const blob = `${match?.series || ''} ${match?.name || ''} ${match?.matchType || ''}`.toLowerCase();
  return (
    /\bipl\b|indian premier league|\bwpl\b|women'?s premier league|tata ipl|syed mushtaq|smat\b|ranji/i.test(
      blob,
    )
  );
}

function mergeRawMatches(lists) {
  const byId = new Map();
  for (const list of lists) {
    if (!Array.isArray(list)) continue;
    for (const m of list) {
      const id = String(m?.id || m?.unique_id || '');
      if (!id) continue;
      if (!byId.has(id)) byId.set(id, m);
    }
  }
  return [...byId.values()];
}

function sortMatchesForDisplay(matches) {
  return [...matches].sort((a, b) => {
    const aIpl = isIplOrMajorLeague(a) ? 1 : 0;
    const bIpl = isIplOrMajorLeague(b) ? 1 : 0;
    if (aIpl !== bIpl) return bIpl - aIpl;
    const ta = new Date(a.dateTimeGMT || a.dateTimeGmt || a.date || 0).getTime();
    const tb = new Date(b.dateTimeGMT || b.dateTimeGmt || b.date || 0).getTime();
    return ta - tb;
  });
}

function normalizeMatchSummary(match) {
  const teams = parseTeams(match);
  const status = detectMatchStatus(match);
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
  let rawList = Array.isArray(body.data) ? body.data : [];

  // currentMatches often omits IPL/WPL — scan /matches pages for major leagues.
  try {
    const leagueRows = [];
    for (const offset of [0, 25, 50, 75]) {
      const more = await cricGet('/matches', { offset });
      const page = Array.isArray(more.data) ? more.data : [];
      for (const m of page) {
        if (isIplOrMajorLeague(m)) leagueRows.push(m);
      }
      if (page.length < 25) break;
    }
    rawList = mergeRawMatches([rawList, leagueRows]);
  } catch (e) {
    console.warn('[cricapi] league matches merge skipped:', e.message);
  }

  rawList = sortMatchesForDisplay(rawList);
  const normalized = rawList.map(normalizeMatchSummary).filter((m) => m.id);

  const live = normalized.filter((m) => m.status === 'live');
  const upcoming = normalized.filter((m) => {
    if (m.status !== 'upcoming') return false;
    // Drop misclassified in-progress rows (scores present).
    return !m.teams.some((t) => t.score != null && String(t.score).trim() !== '');
  });
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
