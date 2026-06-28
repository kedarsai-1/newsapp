const { defaultCategories } = require('./defaultCategories');

/**
 * NewsAPI / GNews category param per app slug (null = mixed/general headlines).
 * GNews only supports a subset — unknown values map to `general` in newsApiService.
 */
const NEWS_API_CATEGORY_BY_SLUG = {
  general: null,
  politics: 'nation',
  sports: 'sports',
  technology: 'technology',
  entertainment: 'entertainment',
  business: 'business',
  health: 'health',
  education: null,
  local: null,
  crime: null,
  weather: null,
};

/**
 * One ingest pass per DB category so every tab gets API headlines (en/te/hi via GNEWS_INGEST_LANGS).
 */
const newsApiIngestPlan = defaultCategories
  .filter((cat) => !['crime', 'weather'].includes(cat.slug))
  .map((cat) => ({
  categorySlug: cat.slug,
  newsApiCategory: NEWS_API_CATEGORY_BY_SLUG[cat.slug] ?? null,
}));

// Extra technology/science pass for the technology tab.
newsApiIngestPlan.push({
  categorySlug: 'technology',
  newsApiCategory: 'science',
});

module.exports = { newsApiIngestPlan, NEWS_API_CATEGORY_BY_SLUG };
