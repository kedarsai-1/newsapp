const {
  searchMandals,
  listDistricts,
  listStates,
} = require('../services/mandalClassifierService');

async function getGeoStates(req, res) {
  try {
    const states = await listStates();
    return res.json({ success: true, states });
  } catch (e) {
    return res.status(500).json({ success: false, message: e.message });
  }
}

async function getGeoDistricts(req, res) {
  try {
    const { state } = req.query;
    const districts = await listDistricts(state);
    return res.json({ success: true, districts });
  } catch (e) {
    return res.status(500).json({ success: false, message: e.message });
  }
}

async function getGeoMandals(req, res) {
  try {
    const { q, district, state, limit } = req.query;
    const mandals = await searchMandals({ q, district, state, limit });
    return res.json({ success: true, mandals });
  } catch (e) {
    return res.status(500).json({ success: false, message: e.message });
  }
}

module.exports = {
  getGeoStates,
  getGeoDistricts,
  getGeoMandals,
};
