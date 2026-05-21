const bcrypt = require('bcryptjs');
const { Prisma, prisma } = require('../config/prisma');
const { generateToken } = require('../middleware/authMiddleware');
const { serializeUser } = require('../utils/serializers');

// POST /api/auth/register
const register = async (req, res) => {
  try {
    const { name, email, password, role, phone } = req.body;

    // Prevent self-assigning admin role
    const assignedRole = role === 'admin' ? 'user' : (role || 'user');

    const normalizedEmail = String(email || '').trim().toLowerCase();
    const existingUser = await prisma.user.findUnique({ where: { email: normalizedEmail } });
    if (existingUser) {
      return res.status(400).json({ success: false, message: 'Email already registered.' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
      data: {
        name,
        email: normalizedEmail,
        password: hashedPassword,
        role: assignedRole,
        phone: phone || null,
      },
    });
    const token = generateToken(user.id);

    res.status(201).json({
      success: true,
      message: 'Registration successful.',
      token,
      user: serializeUser(user),
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// POST /api/auth/login  (password-based — all roles)
const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Email and password required.' });
    }

    const user = await prisma.user.findUnique({
      where: { email: String(email || '').trim().toLowerCase() },
    });
    if (!user || !(await bcrypt.compare(password, user.password))) {
      return res.status(401).json({ success: false, message: 'Invalid email or password.' });
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

// GET /api/auth/me
const getMe = async (req, res) => {
  res.json({ success: true, user: req.user });
};

// PUT /api/auth/update-fcm
const updateFcmToken = async (req, res) => {
  try {
    const { fcmToken } = req.body;
    await prisma.user.update({ where: { id: req.user._id }, data: { fcmToken } });
    res.json({ success: true, message: 'FCM token updated.' });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// PUT /api/auth/profile
const updateProfile = async (req, res) => {
  try {
    const { name, phone, bio } = req.body;
    const updated = await prisma.user.update({
      where: { id: req.user._id },
      data: { name, phone, bio },
    });
    res.json({ success: true, user: serializeUser(updated) });
  } catch (error) {
    if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
      return res.status(400).json({ success: false, message: 'Email or phone already registered.' });
    }
    res.status(500).json({ success: false, message: error.message });
  }
};

module.exports = { register, login, getMe, updateFcmToken, updateProfile };