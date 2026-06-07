/** WMO weather interpretation codes (Open-Meteo). */
const WMO_LABELS = {
  0: 'Clear sky',
  1: 'Mainly clear',
  2: 'Partly cloudy',
  3: 'Overcast',
  45: 'Fog',
  48: 'Depositing rime fog',
  51: 'Light drizzle',
  53: 'Moderate drizzle',
  55: 'Dense drizzle',
  56: 'Light freezing drizzle',
  57: 'Dense freezing drizzle',
  61: 'Slight rain',
  63: 'Moderate rain',
  65: 'Heavy rain',
  66: 'Light freezing rain',
  67: 'Heavy freezing rain',
  71: 'Slight snowfall',
  73: 'Moderate snowfall',
  75: 'Heavy snowfall',
  77: 'Snow grains',
  80: 'Slight rain showers',
  81: 'Moderate rain showers',
  82: 'Violent rain showers',
  85: 'Slight snow showers',
  86: 'Heavy snow showers',
  95: 'Thunderstorm',
  96: 'Thunderstorm with slight hail',
  99: 'Thunderstorm with heavy hail',
};

function weatherLabel(code) {
  const n = Number(code);
  if (Number.isFinite(n) && WMO_LABELS[n]) return WMO_LABELS[n];
  return 'Unknown';
}

function weatherIcon(code) {
  const n = Number(code);
  if (n === 0) return 'clear';
  if (n === 1 || n === 2) return 'partly-cloudy';
  if (n === 3) return 'cloudy';
  if (n === 45 || n === 48) return 'fog';
  if (n >= 51 && n <= 57) return 'drizzle';
  if (n >= 61 && n <= 67) return 'rain';
  if (n >= 71 && n <= 77) return 'snow';
  if (n >= 80 && n <= 82) return 'rain-showers';
  if (n >= 85 && n <= 86) return 'snow-showers';
  if (n >= 95) return 'thunderstorm';
  return 'unknown';
}

module.exports = { weatherLabel, weatherIcon, WMO_LABELS };
