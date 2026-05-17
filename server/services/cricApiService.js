const axios = require('axios');
const memoryCache = require('../utils/memoryCache');

const BASE = (process.env.CRICAPI_BASE_URL || 'https://api.cricapi.com/v1').replace(
  /\/$/,
  '',
);
const API_KEY = process.env.CRICAPI_KEY || process.env.CRIC_API_KEY || '';

const TTL_LIVE_MS = 30 * 1000;
const TTL_MATCH_MS = 60 * 1000;
const TTL_SERIES_MS = 15 * 60 * 1000;

/** Fallback when /series search is rate-limited — IPL 2025 on CricAPI. */
const DEFAULT_LEAGUE_SERIES_IDS = [
  'd5a498c8-7596-4b93-8ab0-e0efc3345312',
];

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

function yearFromName(name) {
  const m = String(name || '').match(/\b(20\d{2})\b/);
  return m ? Number(m[1]) : 0;
}

function configuredLeagueSeriesIds() {
  const raw = process.env.CRICAPI_LEAGUE_SERIES_IDS || process.env.CRICAPI_IPL_SERIES_ID || '';
  const fromEnv = raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  return fromEnv.length ? fromEnv : DEFAULT_LEAGUE_SERIES_IDS;
}

async function findLatestLeagueSeries(search) {
  const body = await cricGet('/series', { search });
  const list = (body.data || []).filter((s) => {
    const name = String(s.name || '').toLowerCase();
    if (search === 'IPL') {
      return /indian premier league|\(ipl\)/i.test(name);
    }
    if (search === 'WPL') {
      return /women.?s premier league|\(wpl\)/i.test(name);
    }
    return name.includes(String(search).toLowerCase());
  });
  list.sort((a, b) => yearFromName(b.name) - yearFromName(a.name));
  return list[0] || null;
}

async function fetchSeriesMatchList(seriesId) {
  const cacheKey = `sports:series:${seriesId}`;
  const hit = memoryCache.get(cacheKey);
  if (hit) return hit;

  const body = await cricGet('/series_info', { id: seriesId });
  const list = Array.isArray(body.data?.matchList) ? body.data.matchList : [];
  memoryCache.set(cacheKey, list, TTL_SERIES_MS);
  return list;
}

/** IPL/WPL fixtures from series_info (currentMatches often omits them). */
async function fetchLeagueSeriesMatches() {
  const cacheKey = 'sports:leagueSeriesMatches';
  const cached = memoryCache.get(cacheKey);
  if (cached) return cached;

  const ids = new Set(configuredLeagueSeriesIds());
  try {
    for (const search of ['IPL', 'WPL']) {
      const series = await findLatestLeagueSeries(search);
      if (series?.id) ids.add(String(series.id));
    }
  } catch (e) {
    console.warn('[cricapi] series search skipped:', e.message);
  }

  const merged = [];
  for (const seriesId of ids) {
    try {
      const rows = await fetchSeriesMatchList(seriesId);
      merged.push(...rows);
    } catch (e) {
      console.warn(`[cricapi] series_info ${seriesId} failed:`, e.message);
    }
  }

  memoryCache.set(cacheKey, merged, TTL_SERIES_MS);
  return merged;
}

function leagueMatchesForFeed(rawList) {
  const now = Date.now();
  const live = rawList.filter((m) => m.matchStarted && !m.matchEnded);
  const upcoming = rawList.filter((m) => {
    if (m.matchEnded) return false;
    if (!m.matchStarted) return true;
    const t = new Date(m.dateTimeGMT || m.dateTimeGmt || m.date || 0).getTime();
    if (!Number.isFinite(t) || t === 0) {
      return /starts at|not started/i.test(String(m.status || ''));
    }
    return t >= now - 6 * 60 * 60 * 1000;
  });
  if (live.length || upcoming.length) return [...live, ...upcoming];

  // Season complete — still surface recent IPL fixtures in the app.
  return rawList
    .filter((m) => m.matchEnded)
    .sort(
      (a, b) =>
        new Date(b.dateTimeGMT || b.dateTimeGmt || b.date || 0) -
        new Date(a.dateTimeGMT || a.dateTimeGmt || a.date || 0),
    )
    .slice(0, 8);
}

function normalizeBattingRow(row) {
  return {
    name: String(row?.batsman?.name || row?.name || '').trim(),
    dismissal: String(row?.['dismissal-text'] || row?.dismissal || 'not out').trim(),
    runs: Number(row?.r ?? row?.runs ?? 0),
    balls: Number(row?.b ?? row?.balls ?? 0),
    fours: Number(row?.['4s'] ?? row?.fours ?? 0),
    sixes: Number(row?.['6s'] ?? row?.sixes ?? 0),
    strikeRate: Number(row?.sr ?? row?.strikeRate ?? 0),
  };
}

function normalizeBowlingRow(row) {
  return {
    name: String(row?.bowler?.name || row?.name || '').trim(),
    overs: Number(row?.o ?? row?.overs ?? 0),
    maidens: Number(row?.m ?? row?.maidens ?? 0),
    runs: Number(row?.r ?? row?.runs ?? 0),
    wickets: Number(row?.w ?? row?.wickets ?? 0),
    economy: Number(row?.eco ?? row?.economy ?? 0),
  };
}

function normalizeScorecardInnings(raw) {
  const innings = Array.isArray(raw?.scorecard) ? raw.scorecard : [];
  return innings.map((inn) => ({
    label: String(inn.inning || inn.team || 'Innings').trim(),
    extras: inn.extras != null ? String(inn.extras) : null,
    totals: inn.totals != null ? String(inn.totals) : null,
    batting: (inn.batting || []).map(normalizeBattingRow).filter((b) => b.name),
    bowling: (inn.bowling || []).map(normalizeBowlingRow).filter((b) => b.name),
  }));
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

function normalizeMatchDetail(raw, scorecardInnings = []) {
  const base = normalizeMatchSummary(raw);
  return {
    ...base,
    overs: teamsOversLine(raw),
    tossWinner: raw.tossWinner || null,
    tossChoice: raw.tossChoice || null,
    matchWinner: raw.matchWinner || null,
    scorecard: scorecardInnings,
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

  try {
    const leagueRows = leagueMatchesForFeed(await fetchLeagueSeriesMatches()).map((m) => ({
      ...m,
      series: m.series || 'Indian Premier League',
    }));
    rawList = mergeRawMatches([rawList, leagueRows]);
  } catch (e) {
    console.warn('[cricapi] IPL/WPL series merge skipped:', e.message);
  }

  rawList = sortMatchesForDisplay(rawList);
  const normalized = rawList.map(normalizeMatchSummary).filter((m) => m.id);

  const live = normalized.filter((m) => m.status === 'live');
  const upcoming = normalized.filter((m) => {
    if (m.status !== 'upcoming') return false;
    return !m.teams.some((t) => t.score != null && String(t.score).trim() !== '');
  });
  const finished = normalized.filter((m) => m.status === 'finished');

  const ipl = normalized
    .filter((m) => isIplOrMajorLeague(m) || /super kings|knight riders|royal challengers|mumbai indians|sunrisers|delhi capitals|punjab kings|rajasthan royal|gujarat titans|lucknow super/i.test(
      `${m.tournament} ${m.teams.map((t) => t.name).join(' ')}`,
    ))
    .slice(0, 12);

  const payload = { live, upcoming, finished, ipl, fetchedAt: new Date().toISOString() };
  memoryCache.set(cacheKey, payload, TTL_LIVE_MS);
  return payload;
}

async function fetchMatchById(id) {
  const cacheKey = `sports:match:${id}`;
  const cached = memoryCache.get(cacheKey);
  if (cached) return cached;

  let raw = null;
  let scorecardInnings = [];

  try {
    const scBody = await cricGet('/match_scorecard', { id });
    raw = scBody.data || scBody;
    scorecardInnings = normalizeScorecardInnings(raw);
  } catch (e) {
    console.warn(`[cricapi] match_scorecard ${id}:`, e.message);
  }

  if (!raw?.teams?.length) {
    const body = await cricGet('/match_info', { id });
    raw = body.data || body;
    if (!scorecardInnings.length) {
      scorecardInnings = normalizeScorecardInnings(raw);
    }
  }

  const detail = normalizeMatchDetail(raw, scorecardInnings);
  memoryCache.set(cacheKey, detail, TTL_MATCH_MS);
  return detail;
}

module.exports = {
  hasKey,
  fetchCurrentMatches,
  fetchMatchById,
  normalizeMatchSummary,
};
