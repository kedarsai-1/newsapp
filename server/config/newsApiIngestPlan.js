/**
 * Each run fetches top headlines (NewsAPI or GNews when GNEWS_API_KEY is set) and maps to app categories.
 * `newsApiCategory: null` = general/mixed headlines for the configured country.
 *
 * Only slugs that exist in your DB (seed categories) are listed; unknown slugs are skipped at runtime.
 */
const newsApiIngestPlan = [
  { categorySlug: 'general', newsApiCategory: null },
  { categorySlug: 'sports', newsApiCategory: 'sports' },
  { categorySlug: 'technology', newsApiCategory: 'technology' },
  { categorySlug: 'technology', newsApiCategory: 'science' },
  { categorySlug: 'business', newsApiCategory: 'business' },
  { categorySlug: 'entertainment', newsApiCategory: 'entertainment' },
  { categorySlug: 'health', newsApiCategory: 'health' },
];

module.exports = { newsApiIngestPlan };
