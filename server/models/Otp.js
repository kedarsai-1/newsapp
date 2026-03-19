const mongoose = require('mongoose');

const otpSchema = new mongoose.Schema({
  // Target — either an email address or a phone number (E.164 format)
  target: {
    type: String,
    required: true,
    lowercase: true,
    trim: true,
  },
  // 'email' or 'phone'
  channel: {
    type: String,
    enum: ['email', 'phone'],
    required: true,
  },
  // 'register' or 'login'
  purpose: {
    type: String,
    enum: ['register', 'login'],
    required: true,
  },
  // 6-digit code (stored as hashed value)
  codeHash: {
    type: String,
    required: true,
  },
  // Expire after 10 minutes
  expiresAt: {
    type: Date,
    required: true,
    index: { expireAfterSeconds: 0 }, // TTL index — MongoDB auto-deletes
  },
  attempts: {
    type: Number,
    default: 0,
  },
  verified: {
    type: Boolean,
    default: false,
  },
}, { timestamps: true });

otpSchema.index({ target: 1, purpose: 1 });

module.exports = mongoose.model('Otp', otpSchema);