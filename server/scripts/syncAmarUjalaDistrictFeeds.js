/**
 * Fetch Amar Ujala location list, probe city RSS feeds, write hiDistrictLocations.js.
 * Run: node scripts/syncAmarUjalaDistrictFeeds.js
 */
const fs = require('fs');
const https = require('https');
const path = require('path');

const OUT = path.join(__dirname, '../config/hiDistrictLocations.js');

const STATE_PATH_MAP = {
  'uttar-pradesh': 'Uttar Pradesh',
  bihar: 'Bihar',
  rajasthan: 'Rajasthan',
  punjab: 'Punjab',
  haryana: 'Haryana',
  'delhi-ncr': 'Uttar Pradesh',
  uttarakhand: 'Uttarakhand',
  'himachal-pradesh': 'Himachal Pradesh',
  'madhya-pradesh': 'Madhya Pradesh',
  'jammu-and-kashmir': 'Jammu and Kashmir',
  chhattisgarh: 'Chhattisgarh',
  jharkhand: 'Jharkhand',
};

const SCOPE_BY_STATE = {
  'Uttar Pradesh': 'up',
  Bihar: 'bihar',
  Rajasthan: 'rajasthan',
  Punjab: 'punjab',
  Haryana: 'haryana',
  Delhi: 'delhi',
  Chandigarh: 'punjab',
  Uttarakhand: 'north',
  'Himachal Pradesh': 'north',
  'Madhya Pradesh': 'north',
  'Jammu and Kashmir': 'north',
  Chhattisgarh: 'north',
  Jharkhand: 'north',
};

const TOP_CITY_STATE = {
  lucknow: 'Uttar Pradesh',
  gorakhpur: 'Uttar Pradesh',
  dehradun: 'Uttarakhand',
  shimla: 'Himachal Pradesh',
  jammu: 'Jammu and Kashmir',
  chandigarh: 'Chandigarh',
  delhi: 'Delhi',
};

/** Skip state-level aggregate feeds (not district hyperlocal). */
const SKIP_SLUGS = new Set([
  'uttar-pradesh',
  'bihar',
  'rajasthan',
  'punjab',
  'haryana',
  'uttarakhand',
  'himachal-pradesh',
  'madhya-pradesh',
  'jammu-and-kashmir',
  'chhattisgarh',
  'jharkhand',
  'gujarat',
  'maharashtra',
  'delhi-ncr',
  'chandigarh-haryana',
  'chandigarh-punjab',
  'simhastha-2028',
]);

const CANONICAL_OVERRIDES = {
  allahabad: { district: 'Prayagraj', city: 'Prayagraj' },
  noida: { district: 'Gautam Buddha Nagar', city: 'Noida', state: 'Uttar Pradesh', scope: 'up' },
  ghaziabad: { district: 'Ghaziabad', city: 'Ghaziabad', state: 'Uttar Pradesh', scope: 'up' },
  gurgaon: { district: 'Gurugram', city: 'Gurugram', state: 'Haryana', scope: 'haryana' },
  'lakhimpur-kheri': { district: 'Lakhimpur Kheri', city: 'Lakhimpur' },
  'sant-kabir-nagar': { district: 'Sant Kabir Nagar', city: 'Khalilabad' },
  'sri-ganganagar': { district: 'Sri Ganganagar', city: 'Sri Ganganagar' },
  'jhajjar-bahadurgarh': { district: 'Jhajjar', city: 'Bahadurgarh' },
  'mahendragarh-narnaul': { district: 'Mahendragarh', city: 'Narnaul' },
  'bilaspur-chhattisgarh': { district: 'Bilaspur', city: 'Bilaspur', state: 'Chhattisgarh' },
  'durg-bhilai': { district: 'Durg', city: 'Bhilai', state: 'Chhattisgarh' },
  'balodabazar-bhatapara': { district: 'Baloda Bazar', city: 'Bhatapara', state: 'Chhattisgarh' },
  'gorella-pendra-marwahi': { district: 'Gaurela-Pendra-Marwahi', city: 'Pendra', state: 'Chhattisgarh' },
  'janjgir-champa': { district: 'Janjgir-Champa', city: 'Janjgir', state: 'Chhattisgarh' },
  'hamirpur-hp': { district: 'Hamirpur', city: 'Hamirpur', state: 'Himachal Pradesh' },
  'udham-singh-nagar': { district: 'Udham Singh Nagar', city: 'Haldwani', state: 'Uttarakhand' },
  'rampur-bushahar': { district: 'Shimla', city: 'Rampur Bushahr', state: 'Himachal Pradesh' },
};

function titleCaseSlug(slug) {
  return slug
    .split('-')
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
    .join(' ');
}

function fetchText(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, { timeout: 15000, headers: { 'User-Agent': 'newsapp-sync/1.0' } }, (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          fetchText(res.headers.location).then(resolve).catch(reject);
          return;
        }
        let data = '';
        res.on('data', (c) => {
          data += c;
        });
        res.on('end', () => resolve(data));
      })
      .on('error', reject);
  });
}

function probeRss(slug) {
  return new Promise((resolve) => {
    const url = `https://www.amarujala.com/rss/${slug}.xml`;
    https
      .get(url, { timeout: 12000, headers: { 'User-Agent': 'newsapp-sync/1.0' } }, (res) => {
        let data = '';
        res.on('data', (c) => {
          data += c;
        });
        res.on('end', () => {
          const items = (data.match(/<item>/g) || []).length;
          resolve({ slug, status: res.statusCode, items });
        });
      })
      .on('error', () => resolve({ slug, status: 0, items: 0 }));
  });
}

function parseLocations(html) {
  const urls = [...html.matchAll(/amarujala\.com\/([^)\s"]+)/g)].map((m) => m[1]);
  const seen = new Set();
  const entries = [];
  for (const p of urls) {
    const parts = p.split('/').filter(Boolean);
    if (!parts.length) continue;
    const slug = parts[parts.length - 1];
    if (seen.has(slug)) continue;
    seen.add(slug);
    entries.push({ slug, statePath: parts.length > 1 ? parts[0] : null });
  }
  return entries;
}

function buildRow({ slug, statePath }) {
  if (SKIP_SLUGS.has(slug)) return null;
  const override = CANONICAL_OVERRIDES[slug] || {};
  const state =
    override.state ||
    (statePath ? STATE_PATH_MAP[statePath] : null) ||
    TOP_CITY_STATE[slug] ||
    null;
  if (!state) return null;
  const district = override.district || titleCaseSlug(slug);
  const city = override.city || district;
  const scope = override.scope || SCOPE_BY_STATE[state] || 'north';
  return { city, district, state, scope, rssSlug: slug };
}

async function main() {
  const cachePath = path.join(__dirname, '../data/amarUjalaLocationList.html');
  let html;
  if (fs.existsSync(cachePath)) {
    console.log('Using cached location list HTML…');
    html = fs.readFileSync(cachePath, 'utf8');
  } else {
    console.log('Fetching Amar Ujala location list…');
    html = await fetchText('https://www.amarujala.com/location-list');
  }
  const locations = parseLocations(html);
  console.log(`Parsed ${locations.length} unique location slugs`);

  const rows = [];
  for (const loc of locations) {
    const row = buildRow(loc);
    if (!row) continue;
    const probe = await probeRss(loc.slug);
    if (probe.status === 200 && probe.items >= 3) {
      rows.push(row);
    }
  }

  rows.sort((a, b) => {
    const sc = a.state.localeCompare(b.state);
    return sc !== 0 ? sc : a.district.localeCompare(b.district);
  });

  const byKey = new Map();
  for (const r of rows) {
    byKey.set(`${r.district}|${r.state}`, r);
  }
  const unique = [...byKey.values()];

  const body = `/**
 * Amar Ujala hyperlocal RSS districts — auto-generated by scripts/syncAmarUjalaDistrictFeeds.js
 * Last sync: ${new Date().toISOString().slice(0, 10)}
 * @type {{ city: string, district: string, state: string, scope: string, rssSlug: string }[]}
 */
module.exports = ${JSON.stringify(unique, null, 2)};
`;

  fs.writeFileSync(OUT, body, 'utf8');
  console.log(`Wrote ${unique.length} districts to ${OUT}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
