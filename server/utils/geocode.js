// Reverse geocoding using OpenStreetMap Nominatim (free, no API key needed)
const reverseGeocode = async (latitude, longitude) => {
    try {
      const url = `https://nominatim.openstreetmap.org/reverse?lat=${latitude}&lon=${longitude}&format=json`;
      const response = await fetch(url, {
        headers: {
          'User-Agent': process.env.NOMINATIM_USER_AGENT || 'NewsApp/1.0',
        },
      });
  
      if (!response.ok) throw new Error('Geocoding request failed');
  
      const data = await response.json();
      const addr = data.address || {};
  
      const city =
        addr.city ||
        addr.town ||
        addr.village ||
        addr.municipality ||
        addr.district ||
        addr.county ||
        addr.state_district ||
        addr.suburb ||
        null;
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
  
  module.exports = { reverseGeocode };