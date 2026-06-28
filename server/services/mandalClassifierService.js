/**
 * Mandal / tehsil extraction for Phase 2 hyperlocal.
 * Uses geo_mandals gazetteer with in-memory cache.
 */
const { prisma } = require('../config/prisma');

let cacheAt = 0;
let mandalEntries = [];

const CACHE_TTL_MS = Math.max(60_000, Number(process.env.MANDAL_CACHE_TTL_MS || 600_000));

function normalizeText(text) {
  return String(text || '')
    .toLowerCase()
    .replace(/[^\w\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function slugify(text) {
  return normalizeText(text).replace(/\s+/g, '-');
}

async function loadMandalGazetteer(force = false) {
  const now = Date.now();
  if (!force && mandalEntries.length > 0 && now - cacheAt < CACHE_TTL_MS) {
    return mandalEntries;
  }
  const rows = await prisma.geoMandal.findMany({
    select: {
      name: true,
      slug: true,
      district: true,
      state: true,
      aliases: true,
    },
    orderBy: [{ state: 'asc' }, { district: 'asc' }, { name: 'asc' }],
  });
  mandalEntries = rows.flatMap((row) => {
    const terms = [row.name, row.slug.replace(/-/g, ' '), ...(row.aliases || [])];
    return terms
      .map((t) => normalizeText(t))
      .filter(Boolean)
      .map((term) => ({
        term,
        canonical: row.name,
        district: row.district,
        state: row.state,
      }));
  }).sort((a, b) => b.term.length - a.term.length);
  cacheAt = now;
  return mandalEntries;
}

function mapTextToMandal(text, { districtHint = null, stateHint = null } = {}) {
  const hay = normalizeText(text);
  if (!hay || mandalEntries.length === 0) return null;

  const districtNorm = districtHint ? normalizeText(districtHint) : null;
  const stateNorm = stateHint ? normalizeText(stateHint) : null;

  for (const entry of mandalEntries) {
    if (!hay.includes(entry.term)) continue;
    if (districtNorm && normalizeText(entry.district) !== districtNorm) continue;
    if (stateNorm && normalizeText(entry.state) !== stateNorm) continue;
    return {
      mandal: entry.canonical,
      district: entry.district,
      state: entry.state,
    };
  }

  for (const entry of mandalEntries) {
    if (!hay.includes(entry.term)) continue;
    return {
      mandal: entry.canonical,
      district: entry.district,
      state: entry.state,
    };
  }
  return null;
}

async function classifyArticleMandal(article, feedMeta = {}, hints = {}) {
  await loadMandalGazetteer();
  const text = `${article?.title || ''} ${article?.contentSnippet || ''} ${article?.content || ''}`;
  const fromFeed = String(feedMeta.locationMandal || '').trim() || null;
  const districtHint = hints.locationDistrict || feedMeta.locationDistrict || null;
  const stateHint = hints.locationState || feedMeta.locationState || null;

  if (fromFeed) {
    return {
      locationMandal: fromFeed,
      locationDistrict: districtHint,
      locationState: stateHint,
    };
  }

  const matched = mapTextToMandal(text, { districtHint, stateHint });
  if (!matched) {
    return {
      locationMandal: null,
      locationDistrict: districtHint,
      locationState: stateHint,
    };
  }

  return {
    locationMandal: matched.mandal,
    locationDistrict: districtHint || matched.district,
    locationState: stateHint || matched.state,
  };
}

async function searchMandals({ q, district, state, limit = 30 } = {}) {
  await loadMandalGazetteer();
  const query = normalizeText(q);
  const where = {};
  if (district) where.district = { equals: String(district).trim(), mode: 'insensitive' };
  if (state) where.state = { equals: String(state).trim(), mode: 'insensitive' };
  if (query) {
    where.OR = [
      { name: { contains: query, mode: 'insensitive' } },
      { district: { contains: query, mode: 'insensitive' } },
      { aliases: { has: query } },
    ];
  }
  return prisma.geoMandal.findMany({
    where,
    orderBy: [{ state: 'asc' }, { district: 'asc' }, { name: 'asc' }],
    take: Math.min(100, Math.max(1, Number(limit) || 30)),
  });
}

async function listDistricts(state) {
  const where = state
    ? { state: { equals: String(state).trim(), mode: 'insensitive' } }
    : {};
  const rows = await prisma.geoMandal.findMany({
    where,
    distinct: ['district', 'state'],
    select: { district: true, state: true },
    orderBy: [{ state: 'asc' }, { district: 'asc' }],
  });
  return rows;
}

async function listStates() {
  const rows = await prisma.geoMandal.findMany({
    distinct: ['state'],
    select: { state: true },
    orderBy: { state: 'asc' },
  });
  return rows.map((r) => r.state);
}

function primeMandalCache(rows = []) {
  mandalEntries = rows.flatMap((row) => {
    const terms = [row.name, row.slug?.replace(/-/g, ' '), ...(row.aliases || [])];
    return terms
      .map((t) => normalizeText(t))
      .filter(Boolean)
      .map((term) => ({
        term,
        canonical: row.name,
        district: row.district,
        state: row.state,
      }));
  }).sort((a, b) => b.term.length - a.term.length);
  cacheAt = Date.now();
}

module.exports = {
  loadMandalGazetteer,
  primeMandalCache,
  mapTextToMandal,
  classifyArticleMandal,
  searchMandals,
  listDistricts,
  listStates,
  slugify,
};
