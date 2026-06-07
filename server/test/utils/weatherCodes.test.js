const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { weatherLabel, weatherIcon } = require('../../utils/weatherCodes');
const {
  parseLatitude,
  parseLongitude,
  isWeatherQuestion,
  buildWeatherContext,
  hasValidCoords,
  resolveWeatherLocation,
} = require('../../services/weatherService');

describe('weatherCodes', () => {
  it('maps common WMO codes', () => {
    assert.equal(weatherLabel(0), 'Clear sky');
    assert.equal(weatherLabel(61), 'Slight rain');
    assert.equal(weatherLabel(95), 'Thunderstorm');
    assert.equal(weatherIcon(0), 'clear');
    assert.equal(weatherIcon(95), 'thunderstorm');
  });
});

describe('weatherService helpers', () => {
  it('validates coordinates', () => {
    assert.equal(parseLatitude('17.385'), 17.385);
    assert.equal(parseLongitude('78.4867'), 78.4867);
    assert.throws(() => parseLatitude('120'), /Invalid latitude/);
    assert.throws(() => parseLongitude('200'), /Invalid longitude/);
  });

  it('detects weather questions across languages', () => {
    assert.equal(isWeatherQuestion('What is the weather today?'), true);
    assert.equal(isWeatherQuestion('ఈరోజు వాతావరణం ఎలా ఉంది?'), true);
    assert.equal(isWeatherQuestion('आज मौसम कैसा है?'), true);
    assert.equal(isWeatherQuestion('Who won the election?'), false);
  });

  it('detects valid coordinates', () => {
    assert.equal(hasValidCoords('17.38', '78.48'), true);
    assert.equal(hasValidCoords('', '78.48'), false);
    assert.equal(hasValidCoords(null, null), false);
  });

  it('requires city or coordinates for weather lookup', async () => {
    await assert.rejects(
      () => resolveWeatherLocation({}),
      /Location required/,
    );
  });

  it('builds readable weather context', () => {
    const text = buildWeatherContext({
      location: { city: 'Hyderabad', state: 'Telangana', country: 'India' },
      current: {
        condition: 'Partly cloudy',
        temperatureC: 32,
        apparentTemperatureC: 35,
        humidityPercent: 60,
        windSpeedKmh: 10,
        precipitationMm: 0,
      },
      daily: [{ date: '2026-06-07', condition: 'Rain', tempMinC: 24, tempMaxC: 31 }],
    });
    assert.match(text, /Hyderabad/);
    assert.match(text, /Partly cloudy/);
    assert.match(text, /32°C/);
  });
});
