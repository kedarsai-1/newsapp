/**
 * Backfill location_city / district / mandal / state on existing posts.
 * Run: node -r dotenv/config scripts/backfillPostLocations.js [--dry-run] [--limit=5000]
 */
const { prisma } = require('../config/prisma');
const { mapTextToDistrict, CITY_TO_DISTRICT } = require('../services/districtClassifierService');
const {
  loadMandalGazetteer,
  mapTextToMandal,
} = require('../services/mandalClassifierService');
const { politicsScopeToState } = require('../config/hindiRegionalScopes');
const {
  cityFromSourceName,
  isStateWideFeedSource,
  isNonGeoFeedSource,
  isHyperlocalFeedSource,
  NON_GEO_FEED_TAILS,
} = require('../utils/feedSourceLocation');

const AP_STATE = 'Andhra Pradesh';
const TG_STATE = 'Telangana';

const SCOPE_TO_STATE = {
  andhra: AP_STATE,
  telangana: TG_STATE,
  up: 'Uttar Pradesh',
  bihar: 'Bihar',
  rajasthan: 'Rajasthan',
  punjab: 'Punjab',
  haryana: 'Haryana',
  delhi: 'Delhi',
};

const CITY_STATE_DISTRICTS = new Set(['Chandigarh', 'Delhi']);

const STATE_NAMES = new Set([
  AP_STATE,
  TG_STATE,
  'Uttar Pradesh',
  'Bihar',
  'Rajasthan',
  'Punjab',
  'Haryana',
  'Delhi',
  'Chandigarh',
]);

function inferGeoFromPost(post) {
  const text = `${post.title || ''} ${post.summary || ''}`;
  const scope = String(post.politicsScope || '').toLowerCase();
  let locationState =
    SCOPE_TO_STATE[scope]
    || politicsScopeToState(scope)
    || null;

  if (isNonGeoFeedSource(post.sourceName)) {
    return {
      locationCity: null,
      locationDistrict: null,
      locationMandal: null,
      locationState,
    };
  }

  let locationCity = isStateWideFeedSource(post.sourceName) ? null : cityFromSourceName(post.sourceName);
  let locationDistrict = mapTextToDistrict(text, locationState);
  let locationMandal = null;

  if (locationCity && CITY_TO_DISTRICT[locationCity]) {
    locationDistrict = CITY_TO_DISTRICT[locationCity];
  } else if (locationCity && !locationDistrict) {
    locationDistrict = mapTextToDistrict(locationCity, locationState);
  }

  const mandalHit = mapTextToMandal(text, {
    districtHint: locationDistrict,
    stateHint: locationState,
  });
  if (mandalHit) {
    locationMandal = mandalHit.mandal;
    locationDistrict = locationDistrict || mandalHit.district;
    locationState = locationState || mandalHit.state;
  }

  if (locationDistrict && STATE_NAMES.has(locationDistrict) && !CITY_STATE_DISTRICTS.has(locationDistrict)) {
    locationDistrict = null;
  }
  if (locationCity && STATE_NAMES.has(locationCity) && !CITY_STATE_DISTRICTS.has(locationCity)) {
    locationCity = null;
  }

  if (!locationState && locationDistrict) {
    if (['Hyderabad', 'Warangal', 'Karimnagar', 'Nizamabad', 'Khammam', 'Nalgonda', 'Mahbubnagar'].includes(locationDistrict)) {
      locationState = TG_STATE;
    } else if (locationDistrict) {
      locationState = AP_STATE;
    }
  }

  if (isStateWideFeedSource(post.sourceName)) {
    return {
      locationCity: null,
      locationDistrict,
      locationMandal,
      locationState,
    };
  }

  return {
    locationCity: locationCity || locationMandal || locationDistrict || null,
    locationDistrict,
    locationMandal,
    locationState,
  };
}

async function repairStateFeedMisTags({ dryRun = false } = {}) {
  const stateFeedPatterns = [
    ' - Andhra Pradesh',
    ' - Telangana',
    ' - Uttar Pradesh',
    ' - Bihar',
    ' - Rajasthan',
    ' - Punjab',
    ' - Haryana',
    ' - States',
    ' - North',
    ...[...NON_GEO_FEED_TAILS].map((t) => ` - ${t}`),
  ];
  let updated = 0;
  for (const pattern of stateFeedPatterns) {
    const posts = await prisma.newsPost.findMany({
      where: {
        status: 'approved',
        sourceName: { contains: pattern, mode: 'insensitive' },
        OR: [
          { locationDistrict: { not: null } },
          { locationCity: { not: null } },
          { locationMandal: { not: null } },
        ],
      },
      select: { id: true },
    });
    for (const post of posts) {
      if (!dryRun) {
        await prisma.newsPost.update({
          where: { id: post.id },
          data: {
            locationCity: null,
            locationDistrict: null,
            locationMandal: null,
          },
        });
      }
      updated += 1;
    }
  }
  return { updated, dryRun };
}

async function backfillPostLocations({ dryRun = false, limit = 5000, batchSize = 200, repair = false } = {}) {
  await loadMandalGazetteer(true);

  const localCat = await prisma.category.findFirst({
    where: { slug: 'local', isActive: true },
    select: { id: true },
  });

  const regionalScopes = [...Object.keys(SCOPE_TO_STATE), 'north'];

  let offset = 0;
  let scanned = 0;
  let updated = 0;
  let skipped = 0;

  while (scanned < limit) {
    const posts = await prisma.newsPost.findMany({
      where: repair
        ? {
          status: 'approved',
          OR: [
            { locationDistrict: { in: [...STATE_NAMES] } },
            { locationCity: { in: [...STATE_NAMES] } },
          ],
        }
        : {
          status: 'approved',
          locationDistrict: null,
          OR: [
            ...(localCat?.id ? [{ categoryId: localCat.id }] : []),
            { politicsScope: { in: regionalScopes } },
            { sourceName: { contains: ' - ', mode: 'insensitive' } },
          ],
        },
      select: {
        id: true,
        title: true,
        summary: true,
        sourceName: true,
        politicsScope: true,
      },
      orderBy: { createdAt: 'desc' },
      skip: offset,
      take: Math.min(batchSize, limit - scanned),
    });

    if (!posts.length) break;
    offset += posts.length;

    for (const post of posts) {
      scanned += 1;

      const geo = inferGeoFromPost(post);
      if (!repair && !geo.locationDistrict && !geo.locationMandal && !geo.locationCity) {
        skipped += 1;
        continue;
      }

      if (!dryRun) {
        await prisma.newsPost.update({
          where: { id: post.id },
          data: {
            locationCity: geo.locationCity,
            locationDistrict: geo.locationDistrict,
            locationMandal: geo.locationMandal,
            locationState: geo.locationState,
          },
        });
      }
      updated += 1;
    }

    if (posts.length < batchSize) break;
  }

  return { scanned, updated, skipped, dryRun };
}

/** Promote approved posts with district tags from city RSS feeds into local category. */
async function reclassifyHyperlocalPosts({ dryRun = false, limit = 10000 } = {}) {
  const localCat = await prisma.category.findFirst({ where: { slug: 'local' } });
  if (!localCat) throw new Error('local category missing');

  const posts = await prisma.newsPost.findMany({
    where: {
      status: 'approved',
      locationDistrict: { not: null },
      categoryId: { not: localCat.id },
      OR: [
        { sourceName: { contains: 'NTV Telugu -', mode: 'insensitive' } },
        { sourceName: { contains: 'TV9 Telugu -', mode: 'insensitive' } },
        { sourceName: { contains: 'Amar Ujala -', mode: 'insensitive' } },
        { sourceName: { contains: 'Hindustan Times -', mode: 'insensitive' } },
      ],
    },
    select: { id: true, sourceName: true },
    take: limit,
  });

  let updated = 0;
  for (const post of posts) {
    if (!isHyperlocalFeedSource(post.sourceName)) continue;
    if (!dryRun) {
      await prisma.newsPost.update({
        where: { id: post.id },
        data: { categoryId: localCat.id },
      });
    }
    updated += 1;
  }

  return { scanned: posts.length, updated, dryRun };
}

/** Tag district/city from headlines on posts missing location (any source). */
async function backfillDistrictMentionsFromTitles({ dryRun = false, limit = 25000 } = {}) {
  const localCat = await prisma.category.findFirst({ where: { slug: 'local' } });
  let offset = 0;
  let scanned = 0;
  let updated = 0;

  while (scanned < limit) {
    const posts = await prisma.newsPost.findMany({
      where: {
        status: 'approved',
        language: { in: ['te', 'hi'] },
        locationDistrict: null,
      },
      select: {
        id: true,
        title: true,
        summary: true,
        sourceName: true,
        politicsScope: true,
        categoryId: true,
      },
      orderBy: { createdAt: 'desc' },
      skip: offset,
      take: Math.min(500, limit - scanned),
    });
    if (!posts.length) break;
    offset += posts.length;

    for (const post of posts) {
      scanned += 1;
      const geo = inferGeoFromPost(post);
      if (!geo.locationDistrict && !geo.locationMandal) continue;

      const data = {
        locationCity: geo.locationCity,
        locationDistrict: geo.locationDistrict,
        locationMandal: geo.locationMandal,
        locationState: geo.locationState,
      };
      if (localCat?.id && post.categoryId !== localCat.id) {
        data.categoryId = localCat.id;
      }
      if (!dryRun) {
        await prisma.newsPost.update({ where: { id: post.id }, data });
      }
      updated += 1;
    }
    if (posts.length < 500) break;
  }

  return { scanned, updated, dryRun };
}

/** Promote approved te/hi posts with real district tags into local category. */
async function promoteDistrictTaggedLocal({ dryRun = false, limit = 15000 } = {}) {
  const localCat = await prisma.category.findFirst({ where: { slug: 'local' } });
  if (!localCat) throw new Error('local category missing');

  const posts = await prisma.newsPost.findMany({
    where: {
      status: 'approved',
      language: { in: ['te', 'hi'] },
      locationDistrict: { not: null },
      categoryId: { not: localCat.id },
      NOT: {
        locationDistrict: { in: [...STATE_NAMES] },
      },
    },
    select: { id: true },
    take: limit,
  });

  if (!dryRun && posts.length) {
    await prisma.newsPost.updateMany({
      where: { id: { in: posts.map((p) => p.id) } },
      data: { categoryId: localCat.id },
    });
  }

  return { scanned: posts.length, updated: posts.length, dryRun };
}

async function main() {
  const dryRun = process.argv.includes('--dry-run');
  const repair = process.argv.includes('--repair');
  const repairStateFeeds = process.argv.includes('--repair-state-feeds');
  const reclassifyLocal = process.argv.includes('--reclassify-local');
  const promoteDistrictLocal = process.argv.includes('--promote-district-local');
  const fillDistrictMentions = process.argv.includes('--fill-district-mentions');
  const limitArg = process.argv.find((a) => a.startsWith('--limit='));
  const limit = limitArg ? parseInt(limitArg.split('=')[1], 10) : 10000;

  if (repairStateFeeds) {
    const result = await repairStateFeedMisTags({ dryRun });
    console.log('[backfill] repair state-feed mis-tags', result);
    return;
  }

  if (reclassifyLocal) {
    const result = await reclassifyHyperlocalPosts({ dryRun, limit });
    console.log('[backfill] reclassify hyperlocal to local category', result);
    return;
  }

  if (promoteDistrictLocal) {
    const result = await promoteDistrictTaggedLocal({ dryRun, limit });
    console.log('[backfill] promote district-tagged posts to local category', result);
    return;
  }

  if (fillDistrictMentions) {
    const result = await backfillDistrictMentionsFromTitles({ dryRun, limit });
    console.log('[backfill] fill district mentions from titles', result);
    return;
  }

  const result = await backfillPostLocations({ dryRun, limit, repair });
  console.log('[backfill] location tags', result);
}

if (require.main === module) {
  main()
    .catch((e) => {
      console.error('[backfill] failed:', e.message);
      process.exitCode = 1;
    })
    .finally(async () => {
      await prisma.$disconnect();
    });
}

module.exports = {
  backfillPostLocations,
  inferGeoFromPost,
  repairStateFeedMisTags,
  reclassifyHyperlocalPosts,
  promoteDistrictTaggedLocal,
  backfillDistrictMentionsFromTitles,
};
