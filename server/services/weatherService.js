const cacheService = require('../utils/cacheService');
const { reverseGeocode, forwardGeocode } = require('../utils/geocode');
const { weatherLabel, weatherIcon } = require('../utils/weatherCodes');

const OPEN_METEO_BASE = process.env.OPEN_METEO_BASE_URL?.trim()
  || 'https://api.open-meteo.com/v1/forecast';

function weatherCacheTtlMs() {
  return Math.max(60_000, Number(process.env.WEATHER_CACHE_TTL_MS || 600_000));
}

function roundCoord(value) {
  return Math.round(Number(value) * 100) / 100;
}

function cacheKey(lat, lng) {
  return `weather:${roundCoord(lat)}:${roundCoord(lng)}`;
}

function parseCoord(raw, min, max, name) {
  const n = Number(raw);
  if (!Number.isFinite(n) || n < min || n > max) {
    throw new Error(`Invalid ${name}. Must be between ${min} and ${max}.`);
  }
  return n;
}

function parseLatitude(raw) {
  return parseCoord(raw, -90, 90, 'latitude');
}

function parseLongitude(raw) {
  return parseCoord(raw, -180, 180, 'longitude');
}

function isWeatherQuestion(text) {
  const q = String(text || '').toLowerCase();
  return /weather|rain|temperature|forecast|humidity|cyclone|storm|heat|cold|monsoon|వాతావరణ|మళ్లి|వర్షం|ఉష్ణోగ్రత|मौसम|बारिश|तापमान|बारिश|ठंड|गर्मी/.test(q);
}

function formatCurrent(current = {}) {
  const code = current.weather_code;
  return {
    temperatureC: current.temperature_2m ?? null,
    apparentTemperatureC: current.apparent_temperature ?? null,
    humidityPercent: current.relative_humidity_2m ?? null,
    precipitationMm: current.precipitation ?? null,
    windSpeedKmh: current.wind_speed_10m ?? null,
    windDirectionDeg: current.wind_direction_10m ?? null,
    weatherCode: code ?? null,
    condition: weatherLabel(code),
    icon: weatherIcon(code),
    observedAt: current.time || null,
  };
}

function formatDaily(daily = {}) {
  const times = daily.time || [];
  return times.map((date, idx) => {
    const code = daily.weather_code?.[idx];
    return {
      date,
      tempMaxC: daily.temperature_2m_max?.[idx] ?? null,
      tempMinC: daily.temperature_2m_min?.[idx] ?? null,
      precipitationMm: daily.precipitation_sum?.[idx] ?? null,
      precipitationProbabilityMax: daily.precipitation_probability_max?.[idx] ?? null,
      weatherCode: code ?? null,
      condition: weatherLabel(code),
      icon: weatherIcon(code),
    };
  });
}

function formatHourly(hourly = {}, limit = 24) {
  const times = hourly.time || [];
  const slice = Math.min(limit, times.length);
  const rows = [];
  for (let i = 0; i < slice; i += 1) {
    const code = hourly.weather_code?.[i];
    rows.push({
      time: times[i],
      temperatureC: hourly.temperature_2m?.[i] ?? null,
      precipitationProbability: hourly.precipitation_probability?.[i] ?? null,
      weatherCode: code ?? null,
      condition: weatherLabel(code),
      icon: weatherIcon(code),
    });
  }
  return rows;
}

async function fetchOpenMeteo(latitude, longitude) {
  const params = new URLSearchParams({
    latitude: String(latitude),
    longitude: String(longitude),
    current: [
      'temperature_2m',
      'relative_humidity_2m',
      'apparent_temperature',
      'precipitation',
      'weather_code',
      'wind_speed_10m',
      'wind_direction_10m',
    ].join(','),
    hourly: 'temperature_2m,precipitation_probability,weather_code',
    daily: [
      'weather_code',
      'temperature_2m_max',
      'temperature_2m_min',
      'precipitation_sum',
      'precipitation_probability_max',
    ].join(','),
    forecast_days: String(Math.min(14, Math.max(1, Number(process.env.WEATHER_FORECAST_DAYS || 7)))),
    timezone: 'auto',
  });

  const url = `${OPEN_METEO_BASE}?${params.toString()}`;
  const timeoutMs = Math.max(3000, Number(process.env.WEATHER_TIMEOUT_MS || 12_000));
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, { signal: controller.signal });
    if (!response.ok) {
      throw new Error(`Open-Meteo request failed (${response.status})`);
    }
    return await response.json();
  } finally {
    clearTimeout(timer);
  }
}

function hasValidCoords(latitude, longitude) {
  if (latitude == null || longitude == null) return false;
  if (String(latitude).trim() === '' || String(longitude).trim() === '') return false;
  return true;
}

/** Resolve GPS or city name to coordinates. */
async function resolveWeatherLocation({ latitude, longitude, lat, lng, city, state, country }) {
  const rawLat = latitude ?? lat;
  const rawLng = longitude ?? lng;

  if (hasValidCoords(rawLat, rawLng)) {
    return {
      latitude: parseLatitude(rawLat),
      longitude: parseLongitude(rawLng),
      source: 'coordinates',
      placeLabel: null,
    };
  }

  const cityName = String(city || '').trim();
  if (!cityName) {
    throw new Error(
      'Location required. Send lat & lng (GPS) or city name (e.g. city=Hyderabad&state=Telangana).',
    );
  }

  const geocoded = await forwardGeocode(cityName, { state, country });
  return {
    latitude: geocoded.latitude,
    longitude: geocoded.longitude,
    source: 'city',
    placeLabel: [geocoded.city, geocoded.state, geocoded.country].filter(Boolean).join(', '),
    geocoded,
  };
}

async function getWeatherByCoordinates(latitude, longitude, { skipCache = false, locationMeta } = {}) {
  const lat = parseLatitude(latitude);
  const lng = parseLongitude(longitude);
  const key = cacheKey(lat, lng);

  if (!skipCache) {
    const cached = await cacheService.get(key);
    if (cached?.body) {
      return { ...cached.body, cached: true };
    }
  }

  const [payload, reverseLocation] = await Promise.all([
    fetchOpenMeteo(lat, lng),
    locationMeta?.source === 'city' && locationMeta.geocoded
      ? Promise.resolve(locationMeta.geocoded)
      : reverseGeocode(lat, lng),
  ]);

  const body = {
    success: true,
    location: {
      latitude: lat,
      longitude: lng,
      city: reverseLocation.city,
      state: reverseLocation.state,
      country: reverseLocation.country,
      address: reverseLocation.address,
      source: locationMeta?.source || 'coordinates',
      query: locationMeta?.placeLabel || null,
    },
    timezone: payload.timezone || null,
    current: formatCurrent(payload.current),
    hourly: formatHourly(payload.hourly, Number(process.env.WEATHER_HOURLY_LIMIT || 24)),
    daily: formatDaily(payload.daily),
    provider: 'open-meteo',
    fetchedAt: new Date().toISOString(),
    cached: false,
  };

  await cacheService.set(key, { body }, weatherCacheTtlMs());
  return body;
}

/** Weather by GPS coordinates OR city name. */
async function getWeatherByLocation(input = {}, options = {}) {
  const resolved = await resolveWeatherLocation(input);
  return getWeatherByCoordinates(resolved.latitude, resolved.longitude, {
    ...options,
    locationMeta: resolved,
  });
}

function buildWeatherContext(weather) {
  if (!weather?.current) return '';
  const loc = weather.location || {};
  const place = [loc.city, loc.state, loc.country].filter(Boolean).join(', ') || 'your location';
  const c = weather.current;
  const lines = [
    `[Live weather for ${place}]`,
    `Condition: ${c.condition}`,
    `Temperature: ${c.temperatureC ?? 'n/a'}°C (feels like ${c.apparentTemperatureC ?? 'n/a'}°C)`,
    `Humidity: ${c.humidityPercent ?? 'n/a'}%`,
    `Wind: ${c.windSpeedKmh ?? 'n/a'} km/h`,
    `Precipitation: ${c.precipitationMm ?? 0} mm`,
  ];
  const nextDays = (weather.daily || []).slice(0, 3);
  if (nextDays.length) {
    lines.push('Next days:');
    for (const day of nextDays) {
      lines.push(
        `- ${day.date}: ${day.condition}, ${day.tempMinC ?? 'n/a'}°C to ${day.tempMaxC ?? 'n/a'}°C`,
      );
    }
  }
  return lines.join('\n');
}

module.exports = {
  getWeatherByCoordinates,
  getWeatherByLocation,
  resolveWeatherLocation,
  buildWeatherContext,
  isWeatherQuestion,
  parseLatitude,
  parseLongitude,
  hasValidCoords,
  weatherCacheTtlMs,
};
