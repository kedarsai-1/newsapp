const mongoose = require('mongoose');

const mediaSchema = new mongoose.Schema({
  type: {
    type: String,
    enum: ['image', 'video'],
    required: true,
  },
  url: { type: String, required: true },
  thumbnail: { type: String, default: null },
  publicId: { type: String }, // Cloudinary public_id for deletion
  size: { type: Number, default: 0 },
  duration: { type: Number, default: null }, // seconds, for videos
}, { _id: true });

const locationSchema = new mongoose.Schema({
  latitude: { type: Number, required: true },
  longitude: { type: Number, required: true },
  address: { type: String, default: null },
  city: { type: String, default: null },
  state: { type: String, default: null },
  country: { type: String, default: 'India' },
  capturedAt: { type: Date, default: Date.now },
}, { _id: false });

const newsPostSchema = new mongoose.Schema({
  title: {
    type: String,
    required: [true, 'Title is required'],
    trim: true,
    maxlength: 200,
  },
  body: {
    type: String,
    required: [true, 'Story body is required'],
    maxlength: 10000,
  },
  summary: {
    type: String,
    maxlength: 300,
    default: null,
  },
  reporter: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  category: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Category',
    required: true,
  },
  media: [mediaSchema],
  location: locationSchema,
  status: {
    type: String,
    enum: ['pending', 'approved', 'rejected', 'draft'],
    default: 'pending',
  },
  rejectionReason: {
    type: String,
    default: null,
  },
  approvedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null,
  },
  approvedAt: {
    type: Date,
    default: null,
  },
  views: { type: Number, default: 0 },
  likes: { type: Number, default: 0 },
  likedBy: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  isFeatured: { type: Boolean, default: false },
  isBreaking: { type: Boolean, default: false },
  tags: [{ type: String, trim: true, lowercase: true }],
}, {
  timestamps: true,
});

// Index for fast feed queries
newsPostSchema.index({ status: 1, createdAt: -1 });
newsPostSchema.index({ category: 1, status: 1, createdAt: -1 });
newsPostSchema.index({ reporter: 1, createdAt: -1 });
newsPostSchema.index({ 'location.city': 1, status: 1 });

// Virtual: has video
newsPostSchema.virtual('hasVideo').get(function () {
  return this.media.some(m => m.type === 'video');
});

module.exports = mongoose.model('NewsPost', newsPostSchema);