#!/usr/bin/env node
/**
 * Targeted RSS ingest for agriculture, education, crime, and jobs.
 * Usage: node scripts/backfillCategoryFeeds.js [en] [hi] [te]
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });

const { runIngestion } = require('../services/newsIngestionService');

const CATEGORY_SLUGS = ['agriculture', 'education', 'crime', 'jobs'];
const langs = process.argv.slice(2).filter(Boolean);
const languages = langs.length ? langs : ['en', 'hi', 'te'];

async function main() {
  console.log(
    `[backfill] categories=${CATEGORY_SLUGS.join(',')} languages=${languages.join(',')}`,
  );
  const result = await runIngestion({
    triggeredBy: 'backfill-category-feeds',
    languages,
    categorySlugs: CATEGORY_SLUGS,
    includeYoutube: false,
    includePolitical: false,
  });
  console.log(JSON.stringify(result, null, 2));
  process.exit(result.success ? 0 : 1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
