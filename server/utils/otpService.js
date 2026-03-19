const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const nodemailer = require('nodemailer');
const Otp = require('../models/Otp');

const OTP_LENGTH    = 6;
const OTP_EXPIRES_M = 10; // minutes
const MAX_ATTEMPTS  = 5;

// ── Generate a random numeric OTP ────────────────────────────────────────────

const generateCode = () => {
  return String(Math.floor(100000 + Math.random() * 900000)); // always 6 digits
};

// ── Email transporter (Nodemailer) ────────────────────────────────────────────

let _mailer;
const getMailer = () => {
  if (_mailer) return _mailer;
  _mailer = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.SMTP_PORT || '587'),
    secure: process.env.SMTP_SECURE === 'true',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });
  return _mailer;
};

// ── SMS via Twilio ─────────────────────────────────────────────────────────────

let _twilioClient;
const getTwilio = () => {
  if (_twilioClient) return _twilioClient;
  if (!process.env.TWILIO_ACCOUNT_SID || !process.env.TWILIO_AUTH_TOKEN) return null;
  const twilio = require('twilio');
  _twilioClient = twilio(process.env.TWILIO_ACCOUNT_SID, process.env.TWILIO_AUTH_TOKEN);
  return _twilioClient;
};

// ── Send OTP email ─────────────────────────────────────────────────────────────

const sendEmailOtp = async (email, code, purpose) => {
  const subject = purpose === 'register'
    ? `${code} is your NewsNow registration code`
    : `${code} is your NewsNow login code`;

  const html = `
    <div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;background:#0f0c29;padding:32px;border-radius:16px;border:1px solid rgba(255,255,255,0.1)">
      <div style="text-align:center;margin-bottom:24px">
        <div style="display:inline-block;background:linear-gradient(135deg,#1D9E75,#0F6E56);padding:12px 16px;border-radius:12px;font-size:24px">📰</div>
        <h2 style="color:#ffffff;margin:12px 0 4px;font-size:20px">NewsNow</h2>
        <p style="color:rgba(255,255,255,0.5);margin:0;font-size:13px">
          ${purpose === 'register' ? 'Verify your email to complete registration' : 'Your one-time login code'}
        </p>
      </div>
      <div style="background:rgba(255,255,255,0.07);border:1px solid rgba(255,255,255,0.15);border-radius:12px;padding:24px;text-align:center;margin-bottom:20px">
        <p style="color:rgba(255,255,255,0.5);font-size:13px;margin:0 0 10px">Your verification code</p>
        <div style="letter-spacing:12px;font-size:36px;font-weight:800;color:#5DCAA5;font-family:monospace">${code}</div>
        <p style="color:rgba(255,255,255,0.35);font-size:12px;margin:12px 0 0">
          Expires in ${OTP_EXPIRES_M} minutes &nbsp;·&nbsp; Do not share this code
        </p>
      </div>
      <p style="color:rgba(255,255,255,0.3);font-size:11px;text-align:center;margin:0">
        If you didn't request this code, ignore this email.
      </p>
    </div>
  `;

  await getMailer().sendMail({
    from: `"NewsNow" <${process.env.SMTP_USER}>`,
    to: email,
    subject,
    html,
  });
};

// ── Send OTP SMS via Twilio ────────────────────────────────────────────────────

const sendSmsOtp = async (phone, code, purpose) => {
  const client = getTwilio();
  if (!client) throw new Error('SMS service not configured');
  const body = purpose === 'register'
    ? `Your NewsNow registration code is ${code}. Valid for ${OTP_EXPIRES_M} minutes.`
    : `Your NewsNow login code is ${code}. Valid for ${OTP_EXPIRES_M} minutes.`;
  await client.messages.create({
    body,
    from: process.env.TWILIO_PHONE_NUMBER,
    to: phone,
  });
};

// ── Core: generate, hash, and store OTP ───────────────────────────────────────

const createOtp = async (target, channel, purpose) => {
  // Delete any existing unexpired OTP for this target + purpose
  await Otp.deleteMany({ target: target.toLowerCase(), purpose });

  const code = generateCode();
  const salt = await bcrypt.genSalt(10);
  const codeHash = await bcrypt.hash(code, salt);

  await Otp.create({
    target: target.toLowerCase(),
    channel,
    purpose,
    codeHash,
    expiresAt: new Date(Date.now() + OTP_EXPIRES_M * 60 * 1000),
  });

  return code; // return plain code to be sent via email/SMS
};

// ── Public: send OTP ──────────────────────────────────────────────────────────

const sendOtp = async (target, channel, purpose) => {
  const code = await createOtp(target, channel, purpose);

  if (channel === 'email') {
    await sendEmailOtp(target, code, purpose);
  } else {
    await sendSmsOtp(target, code, purpose);
  }

  // In development: also log the code to console so you can test without real credentials
  if (process.env.NODE_ENV === 'development') {
    console.log(`\n🔐 OTP for ${target} (${purpose}): ${code}\n`);
  }

  return true;
};

// ── Public: verify OTP ────────────────────────────────────────────────────────

const verifyOtp = async (target, code, purpose) => {
  const record = await Otp.findOne({
    target: target.toLowerCase(),
    purpose,
    verified: false,
    expiresAt: { $gt: new Date() },
  });

  if (!record) {
    return { valid: false, error: 'OTP not found or expired. Please request a new one.' };
  }

  if (record.attempts >= MAX_ATTEMPTS) {
    await Otp.deleteOne({ _id: record._id });
    return { valid: false, error: 'Too many failed attempts. Please request a new OTP.' };
  }

  const isMatch = await bcrypt.compare(code, record.codeHash);

  if (!isMatch) {
    record.attempts += 1;
    await record.save();
    const remaining = MAX_ATTEMPTS - record.attempts;
    return {
      valid: false,
      error: remaining > 0
        ? `Incorrect code. ${remaining} attempt${remaining === 1 ? '' : 's'} remaining.`
        : 'Too many failed attempts. Please request a new OTP.',
    };
  }

  // Mark as verified and delete
  await Otp.deleteOne({ _id: record._id });
  return { valid: true };
};

module.exports = { sendOtp, verifyOtp, OTP_EXPIRES_M };