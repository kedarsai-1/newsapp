const bcrypt = require('bcryptjs');
const { Prisma, prisma } = require('../config/prisma');
const { sendOtp, verifyOtp } = require('../utils/otpService');
const { generateToken } = require('../middleware/authMiddleware');
const { serializeUser } = require('../utils/serializers');
const { validateOtpRegisterPayload } = require('../utils/authValidation');

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

    const genericLoginMessage =
      'If an account exists for this target, an OTP has been sent.';

    // For login: never reveal whether the account exists (anti-enumeration).
    if (purpose === 'login') {
      const query = channel === 'email'
        ? { email: target.trim().toLowerCase() }
        : { phone: target.trim() };

      const user = await prisma.user.findFirst({ where: query });
      const canSendOtp = Boolean(
        user && user.isActive && user.role !== 'admin',
      );

      if (canSendOtp) {
        await sendOtp(target.trim(), channel, purpose);
      }

      return res.json({
        success: true,
        message: genericLoginMessage,
        channel,
        maskedTarget: channel === 'email'
          ? target.replace(/^(.{2})(.*)(@.*)$/, (_, a, b, c) => a + '*'.repeat(Math.max(1, b.length)) + c)
          : target.replace(/(\d{2})\d+(\d{3})/, (_, a, b) => a + '****' + b),
      });
    }

    // For register: target must NOT already exist
    if (purpose === 'register') {
      const query = channel === 'email'
        ? { email: target.trim().toLowerCase() }
        : { phone: target.trim() };

      const existing = await prisma.user.findFirst({ where: query });
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

    const user = await prisma.user.findFirst({ where: query });
    if (!user) {
      return res.status(401).json({ success: false, message: 'Invalid credentials.' });
    }

    if (!user.isActive) {
      return res.status(403).json({ success: false, message: 'Account suspended.' });
    }

    const token = generateToken(user.id);
    res.json({ success: true, token, user: serializeUser(user) });
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

    const validation = validateOtpRegisterPayload({ name, email, phone, password, role });
    if (!validation.ok) {
      return res.status(400).json({ success: false, message: validation.message });
    }

    const {
      name: validName,
      email: validEmail,
      phone: validPhone,
      password: validPassword,
      role: assignedRole,
    } = validation.data;

    const target = validEmail || validPhone;
    if (!code) {
      return res.status(400).json({ success: false, message: 'OTP code is required.' });
    }

    const result = await verifyOtp(target.trim(), code.trim(), 'register');
    if (!result.valid) {
      return res.status(400).json({ success: false, message: result.error });
    }

    const user = await prisma.user.create({
      data: {
        name: validName,
        email: validEmail || undefined,
        phone: validPhone || undefined,
        password: await bcrypt.hash(validPassword, 10),
        role: assignedRole,
        isVerified: true,
      },
    });

    const token = generateToken(user.id);
    res.status(201).json({ success: true, token, user: serializeUser(user) });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
      return res.status(400).json({ success: false, message: 'An account with this email/phone already exists.' });
    }
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { sendOtpHandler, verifyLoginOtp, verifyRegisterOtp };