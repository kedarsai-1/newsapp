const bcrypt = require('bcryptjs');
const { Prisma, prisma } = require('../config/prisma');
const { generateToken } = require('../middleware/authMiddleware');
const { serializeUser } = require('../utils/serializers');
const { validateRegisterPayload } = require('../utils/authValidation');
const { validateFcmToken } = require('../utils/fcmValidation');

// POST /api/auth/register
const register = async (req, res) => {
  try {
    const validation = validateRegisterPayload(req.body);
    if (!validation.ok) {
      return res.status(400).json({ success: false, message: validation.message });
    }

    const { name, email, password, role: assignedRole, phone } = validation.data;

    if (email) {
      const existingUser = await prisma.user.findUnique({ where: { email } });
      if (existingUser) {
        return res.status(400).json({ success: false, message: 'Email already registered.' });
      }
    }

    if (phone) {
      const existingPhone = await prisma.user.findFirst({ where: { phone } });
      if (existingPhone) {
        return res.status(400).json({ success: false, message: 'Phone number already registered.' });
      }
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
      data: {
        name,
        email,
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

// PUT /api/auth/fcm-token
const updateFcmToken = async (req, res) => {
  try {
    const validation = validateFcmToken(req.body?.fcmToken);
    if (!validation.ok) {
      return res.status(400).json({ success: false, message: validation.message });
    }

    const userId = req.user._id;
    const token = validation.value;

    await prisma.$transaction([
      prisma.user.updateMany({
        where: { fcmToken: token, id: { not: userId } },
        data: { fcmToken: null },
      }),
      prisma.user.update({
        where: { id: userId },
        data: { fcmToken: token },
      }),
    ]);

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