const fs = require('fs');
const path = require('path');
const axios = require('axios');
const memoryCache = require('../utils/memoryCache');

const BASE = (process.env.CRICAPI_BASE_URL || 'https://api.cricapi.com/v1').replace(
  /\/$/,
  '',
);
const API_KEY = process.env.CRICAPI_KEY || process.env.CRIC_API_KEY || '';

const TTL_LIVE_MS = 45 * 1000;
const TTL_MATCH_MS = 60 * 1000;
const TTL_SERIES_MS = 6 * 60 * 60 * 1000;
const TTL_STALE_MS = 24 * 60 * 60 * 1000;

/** Last-resort series ids when /series search fails. */
const DEFAULT_LEAGUE_SERIES_IDS = [
  '87c62aac-bc3c-4738-ab93-19da0690488f', // IPL 2026
  'd5a498c8-7596-4b93-8ab0-e0efc3345312', // IPL 2025
];

const FINISHED_IPL_MAX_AGE_MS = 14 * 24 * 60 * 60 * 1000;

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
  const ended = match?.matchEnded === true || match?.matchEnded === 'true';
  const started = match?.matchStarted === true || match?.matchStarted === 'true';

  if (ended) return 'finished';
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

/** IPL season label year (Mar–May window; Jan–Feb still prior season). */
function currentIplSeasonYear() {
  const now = new Date();
  const y = now.getUTCFullYear();
  const month = now.getUTCMonth();
  return month < 2 ? y - 1 : y;
}

function matchSeasonYear(match) {
  const fromSeries = yearFromName(match?.series || match?.name || '');
  if (fromSeries) return fromSeries;
  const t = new Date(match?.dateTimeGMT || match?.dateTimeGmt || match?.date || 0).getTime();
  if (Number.isFinite(t) && t > 0) return new Date(t).getUTCFullYear();
  return 0;
}

function matchTimeMs(match) {
  const t = new Date(match?.dateTimeGMT || match?.dateTimeGmt || match?.date || 0).getTime();
  return Number.isFinite(t) ? t : 0;
}

function formatScorecardField(val) {
  if (val == null || val === '') return null;
  if (typeof val === 'string') {
    const s = val.trim();
    return s && s !== '[object Object]' ? s : null;
  }
  if (typeof val === 'number' && Number.isFinite(val)) return String(val);
  if (typeof val === 'object') {
    const parts = [];
    for (const [k, v] of Object.entries(val)) {
      if (v == null || v === '') continue;
      const label = String(k)
        .replace(/_/g, ' ')
        .replace(/([a-z])([A-Z])/g, '$1 $2')
        .trim();
      parts.push(`${label}: ${v}`);
    }
    return parts.length ? parts.join(', ') : null;
  }
  const s = String(val).trim();
  return s && s !== '[object Object]' ? s : null;
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
    if (search === 'IPL' || /^indian premier league/i.test(String(search))) {
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
async function resolveLeagueSeriesIds() {
  const cacheKey = 'sports:resolvedLeagueSeriesIds';
  const hit = memoryCache.get(cacheKey);
  if (hit) return hit;

  const ids = new Set(configuredLeagueSeriesIds());
  const seasonYear = currentIplSeasonYear();
  try {
    for (const search of [
      `Indian Premier League ${seasonYear}`,
      'IPL',
      'WPL',
    ]) {
      const series = await findLatestLeagueSeries(search);
      if (series?.id) ids.add(String(series.id));
    }
  } catch (e) {
    console.warn('[cricapi] series search skipped:', e.message);
  }

  const out = [...ids];
  memoryCache.set(cacheKey, out, TTL_SERIES_MS);
  return out;
}

async function fetchLeagueSeriesMatches() {
  const cacheKey = 'sports:leagueSeriesMatches';
  const cached = memoryCache.get(cacheKey);
  if (cached) return cached;

  const merged = [];
  for (const seriesId of await resolveLeagueSeriesIds()) {
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
  const seasonYear = currentIplSeasonYear();
  const inSeason = (m) => {
    const y = matchSeasonYear(m);
    return !y || y >= seasonYear - 1;
  };
  const relevant = rawList.filter(inSeason);

  const live = relevant.filter((m) => m.matchStarted && !m.matchEnded);
  const upcoming = relevant.filter((m) => {
    if (m.matchEnded) return false;
    if (!m.matchStarted) return true;
    const t = matchTimeMs(m);
    if (!t) {
      return /starts at|not started/i.test(String(m.status || ''));
    }
    return t >= now - 6 * 60 * 60 * 1000;
  });
  if (live.length || upcoming.length) return [...live, ...upcoming];

  // Off-season / between matches: only very recent finished games (not last year's full slate).
  return relevant
    .filter((m) => m.matchEnded)
    .filter((m) => {
      const t = matchTimeMs(m);
      return t > 0 && t >= now - FINISHED_IPL_MAX_AGE_MS;
    })
    .sort((a, b) => matchTimeMs(b) - matchTimeMs(a))
    .slice(0, 6);
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
  const normalized = innings.map((inn) => ({
    label: String(inn.inning || inn.team || 'Innings').trim(),
    extras: formatScorecardField(inn.extras),
    totals: formatScorecardField(inn.totals),
    batting: (inn.batting || []).map(normalizeBattingRow).filter((b) => b.name),
    bowling: (inn.bowling || []).map(normalizeBowlingRow).filter((b) => b.name),
  }));
  if (normalized.length) return normalized;
  return buildBasicScorecardFromRaw(raw);
}

/** Team totals when full scorecard API is unavailable or rate-limited. */
function buildBasicScorecardFromRaw(raw) {
  const scores = Array.isArray(raw?.score) ? raw.score : [];
  if (!scores.length) return [];
  return scores.map((s) => {
    const runs = s.r ?? s.runs;
    const wkts = s.w ?? s.wickets;
    const overs = formatOvers(s.o ?? s.overs);
    const totals =
      runs != null
        ? `${runs}/${wkts ?? 0}${overs ? ` in ${overs} overs` : ''}`
        : null;
    return {
      label: String(s.inning || s.innings || 'Innings').trim(),
      extras: null,
      totals,
      batting: [],
      bowling: [],
    };
  });
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
    result: formatScorecardField(match.result) || matchStatusText(match) || null,
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
  if (body?.status && body.status !== 'success') {
    const err = new Error(body?.message || body?.reason || 'CricAPI request failed');
    err.code = /blocked|limit|quota|exceeded/i.test(String(err.message))
      ? 'CRICAPI_RATE_LIMIT'
      : 'CRICAPI_ERROR';
    throw err;
  }
  return body;
}

function loadIplFallbackMatches() {
  try {
    const filePath = path.join(__dirname, '../data/ipl2025-fallback.json');
    if (!fs.existsSync(filePath)) return [];
    const parsed = JSON.parse(fs.readFileSync(filePath, 'utf8'));
    return Array.isArray(parsed) ? parsed : [];
  } catch (e) {
    console.warn('[cricapi] IPL fallback file read failed:', e.message);
    return [];
  }
}

function findFallbackMatchById(id) {
  return loadIplFallbackMatches().find((m) => String(m.id) === String(id)) || null;
}

function isIplMatchNormalized(m) {
  return (
    isIplOrMajorLeague({ series: m.tournament, name: m.tournament })
    || /super kings|knight riders|royal challengers|mumbai indians|sunrisers|delhi capitals|punjab kings|rajasthan royal|gujarat titans|lucknow super/i.test(
      `${m.tournament} ${m.teams.map((t) => t.name).join(' ')}`,
    )
  );
}

function seasonYearFromNormalized(m) {
  return yearFromName(m.tournament) || (m.time ? new Date(m.time).getUTCFullYear() : 0);
}

function buildLivePayload(rawList) {
  rawList = sortMatchesForDisplay(rawList);
  const normalized = rawList.map(normalizeMatchSummary).filter((m) => m.id);

  const live = [];
  const upcoming = [];
  const liveIds = new Set();
  const upcomingIds = new Set();

  for (const m of normalized) {
    if (m.status === 'live' && !liveIds.has(m.id)) {
      live.push(m);
      liveIds.add(m.id);
    }
  }
  for (const m of normalized) {
    if (m.status !== 'upcoming' || upcomingIds.has(m.id)) continue;
    if (m.teams.some((t) => t.score != null && String(t.score).trim() !== '')) continue;
    upcoming.push(m);
    upcomingIds.add(m.id);
  }

  // Live/upcoming IPL must appear under "Live now" / "Upcoming", not only under IPL.
  for (const m of normalized) {
    if (!isIplMatchNormalized(m)) continue;
    if (m.status === 'live' && !liveIds.has(m.id)) {
      live.unshift(m);
      liveIds.add(m.id);
    } else if (m.status === 'upcoming' && !upcomingIds.has(m.id)) {
      if (!m.teams.some((t) => t.score != null && String(t.score).trim() !== '')) {
        upcoming.push(m);
        upcomingIds.add(m.id);
      }
    }
  }

  const finished = normalized.filter((m) => m.status === 'finished');
  const seasonYear = currentIplSeasonYear();
  const now = Date.now();

  const ipl = normalized
    .filter((m) => isIplMatchNormalized(m) && !liveIds.has(m.id) && !upcomingIds.has(m.id))
    .filter((m) => {
      if (m.status === 'live' || m.status === 'upcoming') return true;
      if (m.status !== 'finished') return false;
      const y = seasonYearFromNormalized(m);
      if (y && y < seasonYear - 1) return false;
      const t = m.time ? new Date(m.time).getTime() : 0;
      return Number.isFinite(t) && t > 0 && t >= now - FINISHED_IPL_MAX_AGE_MS;
    })
    .slice(0, 8);

  const iplSeasonYear =
    ipl.map(seasonYearFromNormalized).find((y) => y > 0)
    || live.map(seasonYearFromNormalized).find((y) => y > 0)
    || seasonYear;

  const iplSectionTitle =
    live.some(isIplMatchNormalized) || upcoming.some(isIplMatchNormalized)
      ? `IPL ${iplSeasonYear}`
      : ipl.length
        ? `IPL ${iplSeasonYear} · Recent`
        : `IPL ${iplSeasonYear}`;

  return {
    live,
    upcoming,
    finished,
    ipl,
    iplSeasonYear,
    iplSectionTitle,
    fetchedAt: new Date().toISOString(),
  };
}

async function fetchCurrentMatches() {
  const cacheKey = 'sports:currentMatches';
  const staleKey = 'sports:currentMatches:stale';
  const cached = memoryCache.get(cacheKey);
  if (cached) return cached;

  try {
    let rawList = [];
    let rateLimited = false;
    let warning = null;

    // 1) International + live (primary — one API call per refresh)
    try {
      const body = await cricGet('/currentMatches', { offset: 0 });
      rawList = Array.isArray(body.data) ? body.data : [];
    } catch (e) {
      rateLimited = e.code === 'CRICAPI_RATE_LIMIT';
      console.warn('[cricapi] currentMatches skipped:', e.message);
      if (!rateLimited) throw e;
    }

    // 2) IPL supplement — use 6h cache only when rate-limited; otherwise refresh cache quietly
    const leagueCacheKey = 'sports:leagueSeriesMatches';
    let leagueRaw = memoryCache.get(leagueCacheKey);
    if (!leagueRaw && !rateLimited) {
      try {
        leagueRaw = await fetchLeagueSeriesMatches();
      } catch (e) {
        console.warn('[cricapi] IPL/WPL series merge skipped:', e.message);
      }
    }
    if (Array.isArray(leagueRaw) && leagueRaw.length) {
      const leagueRows = leagueMatchesForFeed(leagueRaw).map((m) => ({
        ...m,
        series: m.series || 'Indian Premier League',
      }));
      rawList = mergeRawMatches([rawList, leagueRows]);
    }

    // 3) Offline IPL snapshot only when API returned nothing at all (never mix with live data)
    if (!rawList.length) {
      const fallback = loadIplFallbackMatches().filter((m) => {
        const y = matchSeasonYear(m);
        return !y || y >= currentIplSeasonYear() - 1;
      });
      if (fallback.length) {
        rawList = fallback;
        warning =
          'Live API limit reached — showing saved IPL results. International & live scores return when quota resets.';
      } else {
        const err = new Error('No cricket matches returned from CricAPI');
        err.code = 'CRICAPI_EMPTY';
        throw err;
      }
    } else if (rateLimited && rawList.length) {
      warning = 'Some score updates may be delayed (API limit). Pull to refresh shortly.';
    }

    const payload = { ...buildLivePayload(rawList), ...(warning ? { warning } : {}) };
    memoryCache.set(cacheKey, payload, TTL_LIVE_MS);
    memoryCache.set(staleKey, payload, TTL_STALE_MS);
    return payload;
  } catch (e) {
    const stale = memoryCache.get(staleKey);
    if (stale) {
      return {
        ...stale,
        stale: true,
        warning:
          e.code === 'CRICAPI_RATE_LIMIT'
            ? 'Cricket scores are temporarily limited. Showing last saved matches.'
            : 'Could not refresh scores. Showing last saved matches.',
      };
    }
    throw e;
  }
}

async function fetchMatchById(id) {
  const cacheKey = `sports:match:${id}`;
  const cached = memoryCache.get(cacheKey);
  if (cached) return cached;

  let raw = null;
  try {
    const body = await cricGet('/match_info', { id });
    raw = body.data || body;
  } catch (e) {
    raw = findFallbackMatchById(id);
    if (!raw) throw e;
  }

  let scorecardInnings = buildBasicScorecardFromRaw(raw);

  try {
    const scBody = await cricGet('/match_scorecard', { id });
    const fullRaw = scBody.data || scBody;
    if (fullRaw?.teams?.length) raw = fullRaw;
    const fullCard = normalizeScorecardInnings(fullRaw);
    if (fullCard.some((inn) => inn.batting.length > 0)) {
      scorecardInnings = fullCard;
    }
  } catch (e) {
    console.warn(`[cricapi] match_scorecard ${id}:`, e.message);
    if (!scorecardInnings.length) {
      scorecardInnings = buildBasicScorecardFromRaw(raw);
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
