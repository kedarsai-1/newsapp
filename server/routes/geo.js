const express = require('express');
const {
  getGeoStates,
  getGeoDistricts,
  getGeoMandals,
} = require('../controllers/geoController');

const router = express.Router();

router.get('/states', getGeoStates);
router.get('/districts', getGeoDistricts);
router.get('/mandals', getGeoMandals);

module.exports = router;
