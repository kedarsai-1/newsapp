/**
 * District / city extraction for hyperlocal ingest and local feed filters.
 * Complements constituencyClassifierService (assembly seats) with admin districts.
 */

const {
  mapTextToConstituency,
  classifyArticleConstituency,
} = require('./constituencyClassifierService');
const {
  politicsScopeToState,
} = require('../config/hindiRegionalScopes');
const { classifyArticleMandal } = require('./mandalClassifierService');
const { isNonGeoFeedSource } = require('../utils/feedSourceLocation');
const { TE_DISTRICTS, HI_DISTRICTS } = require('../config/districtRssFeeds');

/** Canonical district → search aliases (lowercase matching). */
const DISTRICT_ALIASES = {
  'Srikakulam': ['srikakulam'],
  'Vizianagaram': ['vizianagaram'],
  'Parvathipuram Manyam': ['parvathipuram manyam', 'parvathipuram'],
  'Visakhapatnam': ['visakhapatnam', 'vizag', 'visakha', 'waltair'],
  'Anakapalli': ['anakapalli', 'anakapalle'],
  'Alluri Sitharama Raju': ['alluri sitharama raju', 'paderu', 'araku valley'],
  'Kakinada': ['kakinada'],
  'Konaseema': ['konaseema', 'dr br ambedkar konaseema'],
  'East Godavari': ['east godavari', 'rajahmundry'],
  'West Godavari': ['west godavari', 'bhimavaram'],
  'Eluru': ['eluru'],
  'Krishna': ['krishna district', 'machilipatnam'],
  'NTR': ['ntr district', 'vijayawada'],
  'Guntur': ['guntur'],
  'Palnadu': ['palnadu'],
  'Bapatla': ['bapatla'],
  'Prakasam': ['prakasam', 'ongole'],
  'Nellore': ['nellore', 'sri potti sriramulu nellore'],
  'Kurnool': ['kurnool'],
  'Nandyal': ['nandyal', 'nandyala', 'నంద్యాల'],
  'Anantapur': ['anantapur', 'anantapuram'],
  'Sri Sathya Sai': ['sri sathya sai', 'puttaparthi'],
  'YSR Kadapa': ['kadapa', 'cuddapah', 'ysr kadapa'],
  'Chittoor': ['chittoor'],
  'Tirupati': ['tirupati'],
  'Annamayya': ['annamayya', 'rayachoti'],
  'Hyderabad': ['hyderabad', 'greater hyderabad', 'secunderabad'],
  'Rangareddy': ['rangareddy', 'ranga reddy'],
  'Medchal Malkajgiri': ['medchal', 'malkajgiri'],
  'Sangareddy': ['sangareddy'],
  'Medak': ['medak'],
  'Siddipet': ['siddipet'],
  'Karimnagar': ['karimnagar'],
  'Rajanna Sircilla': ['rajanna sircilla', 'sircilla'],
  'Jagtial': ['jagtial', 'jagitial'],
  'Peddapalli': ['peddapalli'],
  'Mancherial': ['mancherial'],
  'Nirmal': ['nirmal'],
  'Adilabad': ['adilabad'],
  'Kumuram Bheem': ['kumuram bheem', 'asifabad'],
  'Nizamabad': ['nizamabad'],
  'Kamareddy': ['kamareddy'],
  'Warangal': ['warangal', 'hanamkonda'],
  'Jangaon': ['jangaon'],
  'Mahbubabad': ['mahbubabad'],
  'Khammam': ['khammam'],
  'Bhadradri Kothagudem': ['bhadradri kothagudem', 'kothagudem'],
  'Nalgonda': ['nalgonda'],
  'Suryapet': ['suryapet'],
  'Yadadri Bhuvanagiri': ['yadadri', 'bhuvanagiri'],
  'Mahbubnagar': ['mahbubnagar'],
  'Nagarkurnool': ['nagarkurnool'],
  'Wanaparthy': ['wanaparthy'],
  'Vikarabad': ['vikarabad'],
  'Lucknow': ['lucknow'],
  'Kanpur': ['kanpur'],
  'Varanasi': ['varanasi', 'banaras', 'kashi'],
  'Prayagraj': ['prayagraj', 'allahabad'],
  'Agra': ['agra'],
  'Meerut': ['meerut'],
  'Noida': ['noida'],
  'Ghaziabad': ['ghaziabad'],
  'Gorakhpur': ['gorakhpur'],
  'Patna': ['patna'],
  'Gaya': ['gaya'],
  'Muzaffarpur': ['muzaffarpur'],
  'Jaipur': ['jaipur'],
  'Jodhpur': ['jodhpur'],
  'Udaipur': ['udaipur', 'udaypur', 'उदयपुर'],
  'Kota': ['kota'],
  'Chandigarh': ['chandigarh'],
  'Amritsar': ['amritsar'],
  'Ludhiana': ['ludhiana'],
  'Jalandhar': ['jalandhar'],
  'Gurugram': ['gurugram', 'gurgaon'],
  'Faridabad': ['faridabad'],
  'Panipat': ['panipat', 'पानीपत'],
  'Delhi': ['delhi', 'new delhi'],
};

const CITY_TO_DISTRICT = {
  Vijayawada: 'NTR',
  Visakhapatnam: 'Visakhapatnam',
  Vizag: 'Visakhapatnam',
  Guntur: 'Guntur',
  Chilakaluripeta: 'Palnadu',
  Narasaraopet: 'Palnadu',
  Tirupati: 'Tirupati',
  Nellore: 'Nellore',
  Kurnool: 'Kurnool',
  Kadapa: 'YSR Kadapa',
  Anantapur: 'Anantapur',
  Rajahmundry: 'East Godavari',
  Kakinada: 'Kakinada',
  Warangal: 'Warangal',
  Karimnagar: 'Karimnagar',
  Nizamabad: 'Nizamabad',
  Khammam: 'Khammam',
  Nalgonda: 'Nalgonda',
  Mahbubnagar: 'Mahbubnagar',
  Hyderabad: 'Hyderabad',
  Secunderabad: 'Hyderabad',
  Lucknow: 'Lucknow',
  Kanpur: 'Kanpur',
  Varanasi: 'Varanasi',
  Prayagraj: 'Prayagraj',
  Agra: 'Agra',
  Meerut: 'Meerut',
  Noida: 'Noida',
  Ghaziabad: 'Ghaziabad',
  Gorakhpur: 'Gorakhpur',
  Patna: 'Patna',
  Gaya: 'Gaya',
  Muzaffarpur: 'Muzaffarpur',
  Jaipur: 'Jaipur',
  Jodhpur: 'Jodhpur',
  Udaipur: 'Udaipur',
  Kota: 'Kota',
  Chandigarh: 'Chandigarh',
  Amritsar: 'Amritsar',
  Ludhiana: 'Ludhiana',
  Jalandhar: 'Jalandhar',
  Gurugram: 'Gurugram',
  Gurgaon: 'Gurugram',
  Faridabad: 'Faridabad',
  Panipat: 'Panipat',
  Delhi: 'Delhi',
};

const AP_STATE = 'Andhra Pradesh';
const TG_STATE = 'Telangana';

const STATE_LEVEL_DISTRICT_NAMES = new Set([
  AP_STATE,
  TG_STATE,
  'Uttar Pradesh',
  'Bihar',
  'Rajasthan',
  'Punjab',
  'Haryana',
  'Delhi',
  'Uttarakhand',
  'Himachal Pradesh',
  'Madhya Pradesh',
  'Jammu and Kashmir',
  'Chhattisgarh',
  'Jharkhand',
  'Chandigarh',
]);

function sanitizeDistrictName(district) {
  if (!district) return null;
  const d = String(district).trim();
  if (!d || STATE_LEVEL_DISTRICT_NAMES.has(d)) return null;
  return d;
}

const HI_DISTRICT_STATES = {
  Lucknow: 'Uttar Pradesh',
  Kanpur: 'Uttar Pradesh',
  Varanasi: 'Uttar Pradesh',
  Prayagraj: 'Uttar Pradesh',
  Agra: 'Uttar Pradesh',
  Meerut: 'Uttar Pradesh',
  Noida: 'Uttar Pradesh',
  Ghaziabad: 'Uttar Pradesh',
  Gorakhpur: 'Uttar Pradesh',
  Patna: 'Bihar',
  Gaya: 'Bihar',
  Muzaffarpur: 'Bihar',
  Jaipur: 'Rajasthan',
  Jodhpur: 'Rajasthan',
  Udaipur: 'Rajasthan',
  Kota: 'Rajasthan',
  Chandigarh: 'Chandigarh',
  Amritsar: 'Punjab',
  Ludhiana: 'Punjab',
  Jalandhar: 'Punjab',
  Gurugram: 'Haryana',
  Faridabad: 'Haryana',
  Panipat: 'Haryana',
  Delhi: 'Delhi',
};

function registerDistrictGeo({ district, city, state, rssSlug, slug }) {
  if (!district) return;
  const aliases = new Set(
    [district, city, rssSlug, slug]
      .filter(Boolean)
      .map((s) => String(s).toLowerCase().trim())
      .filter(Boolean),
  );
  const existing = DISTRICT_ALIASES[district] || [];
  DISTRICT_ALIASES[district] = [...new Set([...existing, ...aliases])];
  if (city) CITY_TO_DISTRICT[city] = district;
  if (state) HI_DISTRICT_STATES[district] = state;
}

for (const d of TE_DISTRICTS) {
  registerDistrictGeo({ district: d.district, city: d.city, state: d.state, slug: d.slug });
}
for (const d of HI_DISTRICTS) {
  registerDistrictGeo(d);
}
registerDistrictGeo({ district: 'Prayagraj', city: 'Prayagraj', state: 'Uttar Pradesh', rssSlug: 'allahabad' });
registerDistrictGeo({ district: 'Gurugram', city: 'Gurugram', state: 'Haryana', rssSlug: 'gurgaon' });
CITY_TO_DISTRICT.Noida = 'Gautam Buddha Nagar';
DISTRICT_ALIASES['Gautam Buddha Nagar'] = [
  ...(DISTRICT_ALIASES['Gautam Buddha Nagar'] || []),
  'gautam buddha nagar',
  'noida',
  'greater noida',
];

const SORTED_DISTRICT_ENTRIES = Object.entries(DISTRICT_ALIASES)
  .flatMap(([canonical, aliases]) => aliases.map((a) => ({ canonical, alias: a })))
  .sort((a, b) => b.alias.length - a.alias.length);

function normalizeText(text) {
  return String(text || '')
    .toLowerCase()
    // Keep Latin, Devanagari (hi), and Telugu script letters for place-name matching.
    .replace(/[^\w\u0900-\u097F\u0C00-\u0C7F\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function mapTextToDistrict(text, stateHint = null) {
  const hay = normalizeText(text);
  if (!hay) return null;
  for (const { canonical, alias } of SORTED_DISTRICT_ENTRIES) {
    if (hay.includes(alias)) return canonical;
  }
  return null;
}

/** True when headline/body mentions a district feed's place (district, hub city, or aliases). */
function articleMentionsDistrict(text, { district, city, state } = {}) {
  const hay = normalizeText(text);
  if (!hay) return false;
  const districtName = String(district || '').trim();
  const cityName = String(city || '').trim();
  if (districtName && hay.includes(normalizeText(districtName))) return true;
  if (cityName && hay.includes(normalizeText(cityName))) return true;
  if (districtName) {
    const aliases = DISTRICT_ALIASES[districtName] || [];
    if (aliases.some((a) => hay.includes(a))) return true;
  }
  if (cityName && CITY_TO_DISTRICT[cityName]) {
    const cityAliases = DISTRICT_ALIASES[CITY_TO_DISTRICT[cityName]] || [];
    if (cityAliases.some((a) => hay.includes(a))) return true;
  }
  const inferred = mapTextToDistrict(text, state);
  return inferred != null && districtName && inferred === districtName;
}

function districtToState(district) {
  if (!district) return null;
  const ap = [
    'Srikakulam', 'Vizianagaram', 'Parvathipuram Manyam', 'Visakhapatnam', 'Anakapalli',
    'Alluri Sitharama Raju', 'Kakinada', 'Konaseema', 'East Godavari', 'West Godavari',
    'Eluru', 'Krishna', 'NTR', 'Guntur', 'Palnadu', 'Bapatla', 'Prakasam', 'Nellore',
    'Kurnool', 'Nandyal', 'Anantapur', 'Sri Sathya Sai', 'YSR Kadapa', 'Chittoor',
    'Tirupati', 'Annamayya',
  ];
  const tg = [
    'Hyderabad', 'Rangareddy', 'Medchal Malkajgiri', 'Sangareddy', 'Medak', 'Siddipet',
    'Karimnagar', 'Rajanna Sircilla', 'Jagtial', 'Peddapalli', 'Mancherial', 'Nirmal',
    'Adilabad', 'Kumuram Bheem', 'Nizamabad', 'Kamareddy', 'Warangal', 'Jangaon',
    'Mahbubabad', 'Khammam', 'Bhadradri Kothagudem', 'Nalgonda', 'Suryapet',
    'Yadadri Bhuvanagiri', 'Mahbubnagar', 'Nagarkurnool', 'Wanaparthy', 'Vikarabad',
  ];
  if (ap.includes(district)) return AP_STATE;
  if (tg.includes(district)) return TG_STATE;
  if (HI_DISTRICT_STATES[district]) return HI_DISTRICT_STATES[district];
  return stateHint || null;
}

function resolveFeedLocation(feed = {}) {
  const city = String(feed.locationCity || '').trim() || null;
  const district = String(feed.locationDistrict || '').trim()
    || (city ? (CITY_TO_DISTRICT[city] || null) : null);
  const state = String(feed.locationState || '').trim()
    || districtToState(district)
    || (feed.politicsScope === 'andhra' ? AP_STATE : null)
    || (feed.politicsScope === 'telangana' ? TG_STATE : null)
    || politicsScopeToState(feed.politicsScope)
    || null;
  return { locationCity: city, locationDistrict: district, locationState: state };
}

async function classifyArticleLocalGeo(article, feedMeta = {}, options = {}) {
  const feedLoc = resolveFeedLocation(feedMeta);
  const cat = String(options.categorySlug || feedMeta.categorySlug || '').toLowerCase();
  const feedName = feedMeta.name || feedMeta.sourceName || '';
  const feedHasExplicitLoc = !!(feedLoc.locationCity || feedLoc.locationDistrict);
  const skipHeadlineGeo = (cat === 'politics' && !feedHasExplicitLoc)
    || isNonGeoFeedSource(feedName);

  const text = `${article?.title || ''} ${article?.contentSnippet || ''} ${article?.content || ''}`;
  const fromText = skipHeadlineGeo ? null : mapTextToDistrict(text, feedLoc.locationState);

  let locationDistrict = sanitizeDistrictName(feedLoc.locationDistrict || fromText);
  let locationCity = feedLoc.locationCity;
  if (!locationDistrict && locationCity) {
    locationDistrict = sanitizeDistrictName(CITY_TO_DISTRICT[locationCity] || null);
  }
  if (!locationCity && fromText) {
    locationCity = fromText;
  }

  let locationState = feedLoc.locationState || districtToState(locationDistrict);
  if (!locationState) {
    if (feedMeta.politicsScope === 'andhra') locationState = AP_STATE;
    if (feedMeta.politicsScope === 'telangana') locationState = TG_STATE;
    const fromScope = politicsScopeToState(feedMeta.politicsScope);
    if (fromScope) locationState = fromScope;
  }

  locationDistrict = sanitizeDistrictName(locationDistrict);

  let locationMandal = String(feedMeta.locationMandal || '').trim() || null;
  try {
    const mandalResult = await classifyArticleMandal(article, feedMeta, {
      locationDistrict,
      locationState,
    });
    if (mandalResult.locationMandal) locationMandal = mandalResult.locationMandal;
    if (!locationDistrict && mandalResult.locationDistrict) {
      locationDistrict = mandalResult.locationDistrict;
    }
    if (!locationState && mandalResult.locationState) {
      locationState = mandalResult.locationState;
    }
  } catch {
    // Gazetteer optional until seed runs.
  }

  let constituency = 'Unknown';
  let entities = [];
  const lang = String(options.language || feedMeta.language || '').toLowerCase();
  if (lang === 'te' && (cat === 'local' || (cat === 'politics' && feedHasExplicitLoc))) {
    const cResult = await classifyArticleConstituency(article);
    constituency = cResult.constituency || 'Unknown';
    entities = Array.isArray(cResult.entities) ? cResult.entities : [];
    if (constituency !== 'Unknown' && !locationDistrict) {
      locationDistrict = mapTextToDistrict(constituency, locationState);
    }
  } else if (cat === 'local' || (cat === 'politics' && feedHasExplicitLoc)) {
    constituency = mapTextToConstituency(text);
  }

  return {
    locationCity,
    locationDistrict,
    locationMandal,
    locationState,
    constituency,
    entities,
  };
}

module.exports = {
  DISTRICT_ALIASES,
  CITY_TO_DISTRICT,
  mapTextToDistrict,
  articleMentionsDistrict,
  districtToState,
  resolveFeedLocation,
  classifyArticleLocalGeo,
};
