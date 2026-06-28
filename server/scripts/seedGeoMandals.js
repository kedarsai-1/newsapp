/**
 * Seed geo_mandals from server/data/geoMandalsSeed.js
 * Run: node scripts/seedGeoMandals.js
 */
const { randomUUID } = require('crypto');
const { prisma } = require('../config/prisma');
const seedGroups = require('../data/geoMandalsSeed');
const hiDistricts = require('../config/hiDistrictLocations');
const { forwardGeocode } = require('../utils/geocode');

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Extra search aliases for mandal picker (spelling variants). */
const MANDAL_EXTRA_ALIASES = {
  Chilakaluripeta: ['chilakaluripet', 'chilakaluripeta', 'chilakaluripeta'],
  Piduguralla: ['piduguralla', 'piduguralla'],
  Narasaraopet: ['narasaraopet', 'narasaraopeta'],
};

function slugify(text) {
  return String(text || '')
    .toLowerCase()
    .replace(/[^\w\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .trim();
}

async function seedGeoMandals() {
  const hiGroups = hiDistricts.map((d) => ({
    state: d.state,
    district: d.district,
    mandals: [d.city],
  }));
  const seen = new Set(seedGroups.map((g) => `${g.state}|${g.district}`));
  const merged = [
    ...seedGroups,
    ...hiGroups.filter((g) => !seen.has(`${g.state}|${g.district}`)),
  ];
  let upserted = 0;
  for (const group of merged) {
    const { state, district, mandals } = group;
    for (const name of mandals) {
      const slug = slugify(name);
      const extra = MANDAL_EXTRA_ALIASES[name] || [];
      const aliases = [...new Set([
        ...extra.map((a) => a.toLowerCase()),
        ...(name.toLowerCase() !== slug ? [name.toLowerCase()] : []),
      ])];

      let latitude = null;
      let longitude = null;
      const existing = await prisma.geoMandal.findUnique({
        where: { slug_district_state: { slug, district, state } },
        select: { latitude: true, longitude: true },
      });
      if (existing?.latitude != null && existing?.longitude != null) {
        latitude = existing.latitude;
        longitude = existing.longitude;
      } else if (process.env.GEO_SEED_GEOCODE === 'true') {
        try {
          const geo = await forwardGeocode(name, { state, country: 'India' });
          if (geo?.latitude != null && geo?.longitude != null) {
            latitude = geo.latitude;
            longitude = geo.longitude;
          }
        } catch {
          // Hub geocode optional — mandal name still searchable by text.
        }
        await sleep(120);
      }

      await prisma.geoMandal.upsert({
        where: {
          slug_district_state: { slug, district, state },
        },
        create: {
          id: randomUUID(),
          name,
          slug,
          district,
          state,
          aliases,
          latitude,
          longitude,
        },
        update: {
          name,
          aliases,
          ...(latitude != null && longitude != null
            ? { latitude, longitude }
            : {}),
        },
      });
      upserted += 1;
    }
  }
  return { upserted, groups: merged.length };
}

async function main() {
  const { upserted, groups } = await seedGeoMandals();
  console.log(`[geo] Seeded ${upserted} mandals across ${groups} district groups.`);
}

module.exports = { seedGeoMandals };

if (require.main === module) {
  main()
  .catch((e) => {
    console.error('[geo] seed failed:', e.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
}
