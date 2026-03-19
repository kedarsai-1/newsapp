const express = require('express');
const router = express.Router();
const { register, login, getMe, updateFcmToken, updateProfile } = require('../controllers/authController');
const { sendOtpHandler, verifyLoginOtp, verifyRegisterOtp } = require('../controllers/otpController');
const { protect } = require('../middleware/authMiddleware');

// Traditional auth (kept for backward compatibility)
router.post('/register', register);
router.post('/login', login);

// OTP auth
router.post('/otp/send',            sendOtpHandler);
router.post('/otp/verify-login',    verifyLoginOtp);
router.post('/otp/verify-register', verifyRegisterOtp);

// Protected
router.get('/me',           protect, getMe);
router.put('/profile',      protect, updateProfile);
router.put('/fcm-token',    protect, updateFcmToken);

module.exports = router;