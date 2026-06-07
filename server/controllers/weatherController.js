const { getWeatherByLocation } = require('../services/weatherService');

/**
 * GET /api/weather
 * By GPS: ?lat=17.38&lng=78.48
 * By city: ?city=Hyderabad&state=Telangana  (state optional but helps disambiguation)
 */
async function getWeather(req, res) {
  try {
    const {
      lat, latitude, lng, longitude, city, state, country,
    } = req.query;
    const weather = await getWeatherByLocation(
      {
        lat,
        latitude,
        lng,
        longitude,
        city,
        state,
        country,
      },
      { skipCache: req.query.refresh === '1' || req.query.refresh === 'true' },
    );
    return res.json(weather);
  } catch (error) {
    const isClientError = /invalid (latitude|longitude)|location required|city name is required|could not find/i.test(error.message);
    return res.status(isClientError ? 400 : 502).json({
      success: false,
      message: error.message || 'Failed to fetch weather.',
    });
  }
}

module.exports = { getWeather };
