const cacheService = require('./cacheService');

const NOMINATIM_HEADERS = {
  'User-Agent': process.env.NOMINATIM_USER_AGENT || 'NewsApp/1.0',
};

const GEOCODE_CACHE_TTL_MS = Math.max(
  3600_000,
  Number(process.env.GEOCODE_CACHE_TTL_MS || 86_400_000),
);

function pickCityFromAddress(addr = {}) {
  return (
    addr.city
    || addr.town
    || addr.village
    || addr.municipality
    || addr.district
    || addr.county
    || addr.state_district
    || addr.suburb
    || null
  );
}

// Forward geocoding: city name → coordinates (OpenStreetMap Nominatim, free)
async function forwardGeocode(city, { state, country = 'India' } = {}) {
  const name = String(city || '').trim();
  if (!name) {
    throw new Error('City name is required.');
  }

  const statePart = String(state || '').trim();
  const countryPart = String(country || 'India').trim();
  const cacheKey = `geocode:${name.toLowerCase()}:${statePart.toLowerCase()}:${countryPart.toLowerCase()}`;
  const cached = await cacheService.get(cacheKey);
  if (cached?.latitude != null && cached?.longitude != null) {
    return { ...cached, cached: true };
  }

  const query = [name, statePart, countryPart].filter(Boolean).join(', ');
  const params = new URLSearchParams({
    q: query,
    format: 'json',
    limit: '1',
    addressdetails: '1',
  });
  if (countryPart.toLowerCase() === 'india') {
    params.set('countrycodes', 'in');
  }

  const url = `https://nominatim.openstreetmap.org/search?${params.toString()}`;
  const response = await fetch(url, { headers: NOMINATIM_HEADERS });
  if (!response.ok) {
    throw new Error('City lookup failed. Try a more specific name with state.');
  }

  const results = await response.json();
  if (!Array.isArray(results) || results.length === 0) {
    throw new Error(`Could not find "${name}". Try adding state, e.g. city=Hyderabad&state=Telangana.`);
  }

  const hit = results[0];
  const addr = hit.address || {};
  const result = {
    latitude: parseFloat(hit.lat),
    longitude: parseFloat(hit.lon),
    address: hit.display_name || null,
    city: pickCityFromAddress(addr) || name,
    state: addr.state || addr.region || statePart || null,
    country: addr.country || countryPart || 'India',
    capturedAt: new Date(),
    cached: false,
  };

  await cacheService.set(cacheKey, result, GEOCODE_CACHE_TTL_MS);
  return result;
}

// Reverse geocoding using OpenStreetMap Nominatim (free, no API key needed)
const reverseGeocode = async (latitude, longitude) => {
    try {
      const url = `https://nominatim.openstreetmap.org/reverse?lat=${latitude}&lon=${longitude}&format=json`;
      const response = await fetch(url, { headers: NOMINATIM_HEADERS });
  
      if (!response.ok) throw new Error('Geocoding request failed');
  
      const data = await response.json();
      const addr = data.address || {};
  
      const city = pickCityFromAddress(addr);
      const state = addr.state || addr.region || null;

      return {
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        address: data.display_name || null,
        city,
        state,
        country: addr.country || 'India',
        capturedAt: new Date(),
      };
    } catch (error) {
      console.error('Reverse geocode error:', error.message);
      // Return basic location if geocoding fails
      return {
        latitude: parseFloat(latitude),
        longitude: parseFloat(longitude),
        address: null,
        city: null,
        state: null,
        country: 'India',
        capturedAt: new Date(),
      };
    }
  };
  
module.exports = { reverseGeocode, forwardGeocode };