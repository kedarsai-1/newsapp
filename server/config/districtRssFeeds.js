/**
 * Hyperlocal district/city RSS feeds — AP, TG, Hindi belt.
 * NTV district paths cover all 54 AP+TG districts.
 * Hindi districts use Amar Ujala city RSS (sync via scripts/syncAmarUjalaDistrictFeeds.js).
 */
const AP = 'Andhra Pradesh';
const TG = 'Telangana';
const HI_DISTRICTS = require('./hiDistrictLocations');

/** @type {{ district: string, slug: string, state: string, scope: 'andhra'|'telangana', city: string, tv9Slug?: string }[]} */
const TE_DISTRICTS = [
  { district: 'Srikakulam', slug: 'srikakulam', state: AP, scope: 'andhra', city: 'Srikakulam' },
  { district: 'Vizianagaram', slug: 'vizianagaram', state: AP, scope: 'andhra', city: 'Vizianagaram' },
  { district: 'Parvathipuram Manyam', slug: 'parvathipuram-manyam', state: AP, scope: 'andhra', city: 'Parvathipuram' },
  { district: 'Visakhapatnam', slug: 'visakhapatnam', state: AP, scope: 'andhra', city: 'Visakhapatnam', tv9Slug: 'visakhapatnam' },
  { district: 'Anakapalli', slug: 'anakapalli', state: AP, scope: 'andhra', city: 'Anakapalle' },
  { district: 'Alluri Sitharama Raju', slug: 'alluri-sitharama-raju', state: AP, scope: 'andhra', city: 'Paderu' },
  { district: 'Kakinada', slug: 'kakinada', state: AP, scope: 'andhra', city: 'Kakinada' },
  { district: 'Konaseema', slug: 'konaseema', state: AP, scope: 'andhra', city: 'Amalapuram' },
  { district: 'East Godavari', slug: 'east-godavari', state: AP, scope: 'andhra', city: 'Rajahmundry', tv9Slug: 'east-godavari' },
  { district: 'West Godavari', slug: 'west-godavari', state: AP, scope: 'andhra', city: 'Bhimavaram' },
  { district: 'Eluru', slug: 'eluru', state: AP, scope: 'andhra', city: 'Eluru' },
  { district: 'Krishna', slug: 'krishna', state: AP, scope: 'andhra', city: 'Machilipatnam', tv9Slug: 'krishna' },
  { district: 'NTR', slug: 'vijayawada', state: AP, scope: 'andhra', city: 'Vijayawada' },
  { district: 'Guntur', slug: 'guntur', state: AP, scope: 'andhra', city: 'Guntur', tv9Slug: 'guntur' },
  { district: 'Palnadu', slug: 'palnadu', state: AP, scope: 'andhra', city: 'Narasaraopet' },
  { district: 'Bapatla', slug: 'bapatla', state: AP, scope: 'andhra', city: 'Bapatla' },
  { district: 'Prakasam', slug: 'prakasam', state: AP, scope: 'andhra', city: 'Ongole' },
  { district: 'Nellore', slug: 'nellore', state: AP, scope: 'andhra', city: 'Nellore' },
  { district: 'Kurnool', slug: 'kurnool', state: AP, scope: 'andhra', city: 'Kurnool', tv9Slug: 'kurnool' },
  { district: 'Nandyal', slug: 'nandyal', state: AP, scope: 'andhra', city: 'Nandyal' },
  { district: 'Anantapur', slug: 'anantapur', state: AP, scope: 'andhra', city: 'Anantapur' },
  { district: 'Sri Sathya Sai', slug: 'sri-sathya-sai', state: AP, scope: 'andhra', city: 'Puttaparthi' },
  { district: 'YSR Kadapa', slug: 'kadapa', state: AP, scope: 'andhra', city: 'Kadapa', tv9Slug: 'kadapa' },
  { district: 'Chittoor', slug: 'chittoor', state: AP, scope: 'andhra', city: 'Chittoor' },
  { district: 'Tirupati', slug: 'tirupati', state: AP, scope: 'andhra', city: 'Tirupati', tv9Slug: 'tirupati' },
  { district: 'Annamayya', slug: 'annamayya', state: AP, scope: 'andhra', city: 'Rayachoti' },
  { district: 'Hyderabad', slug: 'hyderabad', state: TG, scope: 'telangana', city: 'Hyderabad', tv9Slug: 'hyderabad' },
  { district: 'Rangareddy', slug: 'rangareddy', state: TG, scope: 'telangana', city: 'Rajendranagar' },
  { district: 'Medchal Malkajgiri', slug: 'medchal-malkajgiri', state: TG, scope: 'telangana', city: 'Malkajgiri' },
  { district: 'Sangareddy', slug: 'sangareddy', state: TG, scope: 'telangana', city: 'Sangareddy' },
  { district: 'Medak', slug: 'medak', state: TG, scope: 'telangana', city: 'Medak' },
  { district: 'Siddipet', slug: 'siddipet', state: TG, scope: 'telangana', city: 'Siddipet' },
  { district: 'Karimnagar', slug: 'karimnagar', state: TG, scope: 'telangana', city: 'Karimnagar' },
  { district: 'Rajanna Sircilla', slug: 'rajanna-sircilla', state: TG, scope: 'telangana', city: 'Sircilla' },
  { district: 'Jagtial', slug: 'jagtial', state: TG, scope: 'telangana', city: 'Jagtial' },
  { district: 'Peddapalli', slug: 'peddapalli', state: TG, scope: 'telangana', city: 'Peddapalli' },
  { district: 'Mancherial', slug: 'mancherial', state: TG, scope: 'telangana', city: 'Mancherial' },
  { district: 'Nirmal', slug: 'nirmal', state: TG, scope: 'telangana', city: 'Nirmal' },
  { district: 'Adilabad', slug: 'adilabad', state: TG, scope: 'telangana', city: 'Adilabad' },
  { district: 'Kumuram Bheem', slug: 'kumuram-bheem', state: TG, scope: 'telangana', city: 'Asifabad' },
  { district: 'Nizamabad', slug: 'nizamabad', state: TG, scope: 'telangana', city: 'Nizamabad' },
  { district: 'Kamareddy', slug: 'kamareddy', state: TG, scope: 'telangana', city: 'Kamareddy' },
  { district: 'Warangal', slug: 'warangal', state: TG, scope: 'telangana', city: 'Warangal', tv9Slug: 'warangal' },
  { district: 'Jangaon', slug: 'jangaon', state: TG, scope: 'telangana', city: 'Jangaon' },
  { district: 'Mahbubabad', slug: 'mahbubabad', state: TG, scope: 'telangana', city: 'Mahbubabad' },
  { district: 'Khammam', slug: 'khammam', state: TG, scope: 'telangana', city: 'Khammam' },
  { district: 'Bhadradri Kothagudem', slug: 'bhadradri-kothagudem', state: TG, scope: 'telangana', city: 'Kothagudem' },
  { district: 'Nalgonda', slug: 'nalgonda', state: TG, scope: 'telangana', city: 'Nalgonda', tv9Slug: 'nalgonda' },
  { district: 'Suryapet', slug: 'suryapet', state: TG, scope: 'telangana', city: 'Suryapet' },
  { district: 'Yadadri Bhuvanagiri', slug: 'yadadri-bhuvanagiri', state: TG, scope: 'telangana', city: 'Bhongir' },
  { district: 'Mahbubnagar', slug: 'mahabubnagar', state: TG, scope: 'telangana', city: 'Mahbubnagar' },
  { district: 'Nagarkurnool', slug: 'nagarkurnool', state: TG, scope: 'telangana', city: 'Nagarkurnool' },
  { district: 'Wanaparthy', slug: 'wanaparthy', state: TG, scope: 'telangana', city: 'Wanaparthy' },
  { district: 'Vikarabad', slug: 'vikarabad', state: TG, scope: 'telangana', city: 'Vikarabad' },
];

function ntvDistrictFeed({ district, slug, state, scope, city }) {
  const statePath = state === AP ? 'andhra-pradesh' : 'telangana';
  return {
    name: `NTV Telugu - ${district}`,
    url: `https://ntvtelugu.com/${statePath}/${slug}/feed`,
    categorySlug: 'local',
    language: 'te',
    ogImageFallback: true,
    politicsScope: scope,
    locationCity: city,
    locationDistrict: district,
    locationState: state,
  };
}

function tv9DistrictFeed({ district, tv9Slug, state, scope, city }) {
  return {
    name: `TV9 Telugu - ${district}`,
    url: `https://www.tv9telugu.com/category/${tv9Slug}/feed`,
    categorySlug: 'local',
    language: 'te',
    ogImageFallback: true,
    politicsScope: scope,
    locationCity: city,
    locationDistrict: district,
    locationState: state,
  };
}

function amarUjalaCityFeed({ city, district, state, scope, rssSlug }) {
  return {
    name: `Amar Ujala - ${district}`,
    url: `https://www.amarujala.com/rss/${rssSlug}.xml`,
    categorySlug: 'local',
    language: 'hi',
    ogImageFallback: true,
    politicsScope: scope,
    locationCity: city,
    locationDistrict: district,
    locationState: state,
  };
}

const teDistrictFeeds = TE_DISTRICTS.flatMap((d) => {
  const feeds = [ntvDistrictFeed(d)];
  if (d.tv9Slug) feeds.push(tv9DistrictFeed(d));
  return feeds;
});

const hiDistrictFeeds = HI_DISTRICTS.map(amarUjalaCityFeed);

const districtRssFeeds = [...teDistrictFeeds, ...hiDistrictFeeds];

module.exports = {
  TE_DISTRICTS,
  HI_DISTRICTS,
  /** @deprecated use HI_DISTRICTS */
  HI_CITIES: HI_DISTRICTS,
  districtRssFeeds,
};
