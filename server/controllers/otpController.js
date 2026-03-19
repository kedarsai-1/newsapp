const User = require('../models/User');
const { sendOtp, verifyOtp } = require('../utils/otpService');
const { generateToken } = require('../middleware/authMiddleware');

// ─── Helpers ──────────────────────────────────────────────────────────────────

const isEmail = (v) => /^[\w.+\-]+@[a-zA-Z\d\-]+(\.[a-zA-Z\d\-]+)*\.[a-zA-Z]{2,}$/.test(v);
const isPhone = (v) => /^\+?[\d\s\-\(\)]{7,15}$/.test(v);

const detectChannel = (target) => {
  if (isEmail(target)) return 'email';
  if (isPhone(target)) return 'phone';
  return null;
};

// ─── POST /api/auth/otp/send ──────────────────────────────────────────────────
// Body: { target, purpose }
// target = email address OR phone number
// purpose = 'login' | 'register'

const sendOtpHandler = async (req, res) => {
  try {
    const { target, purpose } = req.body;

    if (!target || !purpose) {
      return res.status(400).json({ success: false, message: 'target and purpose are required.' });
    }

    if (!['login', 'register'].includes(purpose)) {
      return res.status(400).json({ success: false, message: 'purpose must be login or register.' });
    }

    const channel = detectChannel(target.trim());
    if (!channel) {
      return res.status(400).json({ success: false, message: 'target must be a valid email or phone number.' });
    }

    // For login: target must exist in the database
    if (purpose === 'login') {
      const query = channel === 'email'
        ? { email: target.trim().toLowerCase() }
        : { phone: target.trim() };

      const user = await User.findOne(query);
      if (!user) {
        return res.status(404).json({
          success: false,
          message: channel === 'email'
            ? 'No account found with this email.'
            : 'No account found with this phone number.',
        });
      }
      if (!user.isActive) {
        return res.status(403).json({ success: false, message: 'Account is suspended.' });
      }
      // Admins must use password login — OTP not allowed
      if (user.role === 'admin') {
        return res.status(403).json({
          success: false,
          message: 'Admin accounts must use password login.',
        });
      }
    }

    // For register: target must NOT already exist
    if (purpose === 'register') {
      const query = channel === 'email'
        ? { email: target.trim().toLowerCase() }
        : { phone: target.trim() };

      const existing = await User.findOne(query);
      if (existing) {
        return res.status(400).json({
          success: false,
          message: channel === 'email'
            ? 'An account with this email already exists.'
            : 'An account with this phone number already exists.',
        });
      }
    }

    await sendOtp(target.trim(), channel, purpose);

    res.json({
      success: true,
      message: `OTP sent to ${channel === 'email' ? 'your email' : 'your phone'}.`,
      channel,
      // Mask the target for the response
      maskedTarget: channel === 'email'
        ? target.replace(/^(.{2})(.*)(@.*)$/, (_, a, b, c) => a + '*'.repeat(Math.max(1, b.length)) + c)
        : target.replace(/(\d{2})\d+(\d{3})/, (_, a, b) => a + '****' + b),
    });
  } catch (error) {
    console.error('OTP send error:', error.message);
    res.status(500).json({ success: false, message: 'Failed to send OTP. Please try again.' });
  }
};

// ─── POST /api/auth/otp/verify-login ─────────────────────────────────────────
// Body: { target, code }
// Verifies OTP and returns a JWT if valid

const verifyLoginOtp = async (req, res) => {
  try {
    const { target, code } = req.body;

    if (!target || !code) {
      return res.status(400).json({ success: false, message: 'target and code are required.' });
    }

    const result = await verifyOtp(target.trim(), code.trim(), 'login');
    if (!result.valid) {
      return res.status(400).json({ success: false, message: result.error });
    }

    const channel = detectChannel(target.trim());
    const query = channel === 'email'
      ? { email: target.trim().toLowerCase() }
      : { phone: target.trim() };

    const user = await User.findOne(query);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    const token = generateToken(user._id);
    res.json({ success: true, token, user: user.toJSON() });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ─── POST /api/auth/otp/verify-register ──────────────────────────────────────
// Body: { name, email?, phone?, password, role, code }
// Verifies OTP then creates the account

const verifyRegisterOtp = async (req, res) => {
  try {
    const { name, email, phone, password, role, code } = req.body;

    // Determine what target was used to request the OTP
    const target = email || phone;
    if (!target) {
      return res.status(400).json({ success: false, message: 'email or phone is required.' });
    }

    if (!code) {
      return res.status(400).json({ success: false, message: 'OTP code is required.' });
    }

    const result = await verifyOtp(target.trim(), code.trim(), 'register');
    if (!result.valid) {
      return res.status(400).json({ success: false, message: result.error });
    }

    // Prevent self-assigning admin
    const assignedRole = role === 'admin' ? 'user' : (role || 'user');

    // Create the user
    const user = await User.create({
      name: name.trim(),
      email: email ? email.trim().toLowerCase() : undefined,
      phone: phone ? phone.trim() : undefined,
      password,
      role: assignedRole,
      isVerified: true, // OTP verified → mark account as verified
    });

    const token = generateToken(user._id);
    res.status(201).json({ success: true, token, user: user.toJSON() });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({ success: false, message: 'An account with this email/phone already exists.' });
    }
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { sendOtpHandler, verifyLoginOtp, verifyRegisterOtp };