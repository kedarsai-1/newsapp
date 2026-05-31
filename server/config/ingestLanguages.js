/**
 * Production language-scoped ingestion (en / hi / te).
 *
 * Modes:
 * - INGEST_PER_LANGUAGE=true — cron runs separate pipelines per language (staggered).
 * - INGEST_WORKER_LANG=te — single-language worker (e.g. dedicated Railway service).
 */

const INGEST_LANGS = ['en', 'hi', 'te'];

function normalizeLanguage(lang) {
  return String(lang || '').trim().toLowerCase();
}

function normalizeLanguages(languages) {
  if (!languages) return [];
  const list = Array.isArray(languages) ? languages : String(languages).split(',');
  return [...new Set(
    list.map(normalizeLanguage).filter((l) => INGEST_LANGS.includes(l)),
  )];
}

function isPerLanguageIngestEnabled() {
  return process.env.INGEST_PER_LANGUAGE === 'true'
    || Boolean(process.env.INGEST_WORKER_LANG?.trim());
}

/** Languages this process should ingest (worker lang or all three). */
function getWorkerLanguages() {
  const worker = normalizeLanguage(process.env.INGEST_WORKER_LANG);
  if (worker && INGEST_LANGS.includes(worker)) return [worker];
  if (isPerLanguageIngestEnabled()) return [...INGEST_LANGS];
  return [];
}

/**
 * Resolve active languages for a run.
 * Explicit `options.languages` wins; else worker/env list; else legacy all-lang batch.
 */
function resolveIngestLanguages(options = {}) {
  const explicit = normalizeLanguages(options.languages);
  if (explicit.length) return explicit;

  const workerLangs = getWorkerLanguages();
  if (workerLangs.length) return workerLangs;

  const raw = process.env.INGEST_LANGUAGES?.trim()
    || process.env.GNEWS_INGEST_LANGS?.trim();
  if (raw) return normalizeLanguages(raw.split(','));

  return [...INGEST_LANGS];
}

function lockKeyForLanguages(languages) {
  const langs = normalizeLanguages(languages);
  if (langs.length === 1) return langs[0];
  if (langs.length === INGEST_LANGS.length
    && INGEST_LANGS.every((l) => langs.includes(l))) {
    return 'global';
  }
  return langs.sort().join('+') || 'global';
}

function filterByLanguages(items, languages, langKey = 'language') {
  const langs = normalizeLanguages(languages);
  if (!langs.length) return items;
  const set = new Set(langs);
  return items.filter((item) => set.has(normalizeLanguage(item?.[langKey])));
}

/** Per-language runtime budget (falls back to INGEST_MAX_RUNTIME_MS). */
function getIngestBudgetMs(language) {
  const lang = normalizeLanguage(language);
  const perLang = lang
    ? process.env[`INGEST_MAX_RUNTIME_MS_${lang.toUpperCase()}`]?.trim()
    : '';
  const raw = perLang || process.env.INGEST_MAX_RUNTIME_MS;
  const onRailway = Boolean(
    process.env.RAILWAY_ENVIRONMENT || process.env.RAILWAY_PROJECT_ID,
  );

  let ms;
  if (raw === undefined || raw === '') {
    ms = onRailway ? 6 * 60 * 1000 : 20 * 60 * 1000;
  } else {
    ms = Number(raw);
    if (onRailway && Number.isFinite(ms) && ms > 10 * 60 * 1000) {
      ms = 10 * 60 * 1000;
    }
  }
  return Number.isFinite(ms) && ms > 0 ? ms : null;
}

/** Default staggered news cron per language (minute offset avoids API/DB pile-up). */
function defaultNewsCronForLanguage(language) {
  const offsets = { en: 0, hi: 1, te: 2 };
  const offset = offsets[normalizeLanguage(language)] ?? 0;
  if (offset === 0) return process.env.SCRAPER_CRON || '*/5 * * * *';
  return `${offset}-59/5 * * * *`;
}

function defaultYoutubeCronForLanguage(language) {
  const offsets = { en: 0, hi: 20, te: 40 };
  const offset = offsets[normalizeLanguage(language)] ?? 0;
  return `${offset} */6 * * *`;
}

function defaultPoliticalCronForLanguage(language) {
  const offsets = { en: 0, hi: 5, te: 10 };
  const offset = offsets[normalizeLanguage(language)] ?? 0;
  return `${offset},${offset + 15},${offset + 30},${offset + 45} * * * *`;
}

function cronForLanguage(baseEnvKey, language, fallbackFn) {
  const lang = normalizeLanguage(language).toUpperCase();
  return process.env[`${baseEnvKey}_${lang}`]?.trim()
    || fallbackFn(language);
}

module.exports = {
  INGEST_LANGS,
  normalizeLanguage,
  normalizeLanguages,
  isPerLanguageIngestEnabled,
  getWorkerLanguages,
  resolveIngestLanguages,
  lockKeyForLanguages,
  filterByLanguages,
  getIngestBudgetMs,
  defaultNewsCronForLanguage,
  defaultYoutubeCronForLanguage,
  defaultPoliticalCronForLanguage,
  cronForLanguage,
};
