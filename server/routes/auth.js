const express = require('express');
const router = express.Router();
const { register, login, getMe, updateFcmToken, updateProfile } = require('../controllers/authController');
const { sendOtpHandler, verifyLoginOtp, verifyRegisterOtp } = require('../controllers/otpController');
const otpRateLimit = require('../middleware/otpRateLimit');
const { protect } = require('../middleware/authMiddleware');
const fcmRateLimit = require('../middleware/fcmRateLimit');
const {
  getSavedLocations,
  upsertSavedLocation,
  deleteSavedLocation,
} = require('../controllers/userLocationsController');

// Traditional auth (kept for backward compatibility)
router.post('/register', register);
router.post('/login', login);

// OTP auth
router.post('/otp/send', otpRateLimit, sendOtpHandler);
router.post('/otp/verify-login',    verifyLoginOtp);
router.post('/otp/verify-register', verifyRegisterOtp);

// Protected
router.get('/me',           protect, getMe);
router.put('/profile',      protect, updateProfile);
router.put('/fcm-token',    protect, fcmRateLimit, updateFcmToken);
router.get('/locations',    protect, getSavedLocations);
router.put('/locations/:slot', protect, upsertSavedLocation);
router.delete('/locations/:slot', protect, deleteSavedLocation);

module.exports = router;