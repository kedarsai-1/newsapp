/**
 * Report hyperlocal district coverage: RSS feeds vs approved local posts.
 * Run: node -r dotenv/config scripts/auditDistrictCoverage.js [--json]
 */
const { prisma } = require('../config/prisma');
const geo = require('../data/geoMandalsSeed');
const { getRssFeeds } = require('../config/rssFeeds');
const { TE_DISTRICTS, HI_DISTRICTS } = require('../config/districtRssFeeds');

const AP = 'Andhra Pradesh';
const TG = 'Telangana';

function districtTargets() {
  const te = TE_DISTRICTS.map((d) => ({ district: d.district, state: d.state }));
  const hiFromGeo = geo.filter((g) => g.state !== AP && g.state !== TG);
  const hiFromRss = HI_DISTRICTS.map((d) => ({ district: d.district, state: d.state }));
  const hiKeys = new Set();
  const hi = [];
  for (const row of [...hiFromGeo, ...hiFromRss]) {
    const key = `${row.district}|${row.state}`;
    if (hiKeys.has(key)) continue;
    hiKeys.add(key);
    hi.push(row);
  }
  return { te, hi, all: [...te, ...hi] };
}

function feedCoverage(feeds) {
  const byDistrict = new Map();
  for (const f of feeds) {
    if (!f.locationDistrict) continue;
    const lang = String(f.language || 'en').toLowerCase();
    const key = `${f.locationDistrict}|${lang}`;
    if (!byDistrict.has(key)) byDistrict.set(key, []);
    byDistrict.get(key).push(f.name);
  }
  return byDistrict;
}

async function postCoverage() {
  const rows = await prisma.newsPost.groupBy({
    by: ['locationDistrict', 'language'],
    where: {
      status: 'approved',
      category: { slug: 'local' },
      language: { in: ['te', 'hi'] },
      locationDistrict: { not: null },
    },
    _count: { id: true },
  });
  const map = new Map();
  for (const r of rows) {
    map.set(`${r.locationDistrict}|${r.language}`, r._count.id);
  }
  return map;
}

function summarize(targets, lang, feedMap, postMap) {
  const withFeed = [];
  const withPosts = [];
  const gaps = [];

  for (const { district, state } of targets) {
    const key = `${district}|${lang}`;
    const hasFeed = feedMap.has(key);
    const postCount = postMap.get(key) || 0;
    if (hasFeed) withFeed.push(district);
    if (postCount > 0) withPosts.push({ district, state, count: postCount });
    if (!postCount) {
      gaps.push({
        district,
        state,
        hasFeed,
        feedNames: feedMap.get(key) || [],
      });
    }
  }

  return {
    total: targets.length,
    withFeed: withFeed.length,
    withPosts: withPosts.length,
    zeroPosts: gaps.length,
    gaps,
    topPosts: withPosts.sort((a, b) => b.count - a.count).slice(0, 15),
  };
}

async function main() {
  const { te, hi } = districtTargets();
  const feeds = getRssFeeds();
  const localDistrictFeeds = feeds.filter((f) => f.locationDistrict && f.categorySlug === 'local');
  const feedMap = feedCoverage(localDistrictFeeds);
  const postMap = await postCoverage();

  const teSummary = summarize(
    te.map((g) => ({ district: g.district, state: g.state })),
    'te',
    feedMap,
    postMap,
  );
  const hiSummary = summarize(
    hi.map((g) => ({ district: g.district, state: g.state })),
    'hi',
    feedMap,
    postMap,
  );

  const report = {
    generatedAt: new Date().toISOString(),
    feedConfig: {
      teDistrictFeeds: TE_DISTRICTS.length,
      hiDistrictFeeds: HI_DISTRICTS.length,
      localDistrictFeedsInRss: localDistrictFeeds.length,
      teFeedDistricts: new Set(
        localDistrictFeeds.filter((f) => f.language === 'te').map((f) => f.locationDistrict),
      ).size,
      hiFeedDistricts: new Set(
        localDistrictFeeds.filter((f) => f.language === 'hi').map((f) => f.locationDistrict),
      ).size,
    },
    telugu: teSummary,
    hindi: hiSummary,
  };

  if (process.argv.includes('--json')) {
    console.log(JSON.stringify(report, null, 2));
  } else {
    console.log('=== Hyperlocal District Coverage Audit ===\n');
    console.log(`RSS local district feeds: ${report.feedConfig.localDistrictFeedsInRss}`);
    console.log(`  Telugu districts with feeds: ${report.feedConfig.teFeedDistricts} / ${te.length}`);
    console.log(`  Hindi districts with feeds: ${report.feedConfig.hiFeedDistricts} / ${hi.length}\n`);

    console.log('--- Telugu (te) ---');
    console.log(`Posts: ${teSummary.withPosts}/${teSummary.total} districts`);
    console.log(`Feeds: ${teSummary.withFeed}/${teSummary.total} districts`);
    if (teSummary.zeroPosts) {
      console.log(`Zero local posts (${teSummary.zeroPosts}):`);
      for (const g of teSummary.gaps) {
        console.log(`  - ${g.district} (${g.state}) feed=${g.hasFeed ? 'yes' : 'NO'}`);
      }
    }

    console.log('\n--- Hindi (hi) ---');
    console.log(`Posts: ${hiSummary.withPosts}/${hiSummary.total} districts`);
    console.log(`Feeds: ${hiSummary.withFeed}/${hiSummary.total} districts`);
    if (hiSummary.zeroPosts) {
      console.log(`Zero local posts (${hiSummary.zeroPosts}):`);
      for (const g of hiSummary.gaps) {
        console.log(`  - ${g.district} (${g.state}) feed=${g.hasFeed ? 'yes' : 'NO'}`);
      }
    }
  }

  await prisma.$disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
