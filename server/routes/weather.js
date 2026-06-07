const express = require('express');
const { getWeather } = require('../controllers/weatherController');
const { optionalProtect } = require('../middleware/authMiddleware');

const router = express.Router();

router.get('/', optionalProtect, getWeather);

module.exports = router;
