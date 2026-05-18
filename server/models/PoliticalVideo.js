const mongoose = require('mongoose');

const politicalVideoSchema = new mongoose.Schema(
  {
    videoId: { type: String, required: true, unique: true, trim: true, index: true },
    title: { type: String, required: true, trim: true, maxlength: 200 },
    thumbnail: { type: String, default: null },
    channelName: { type: String, trim: true, default: null },
    channelId: { type: String, trim: true, default: null },
    language: { type: String, trim: true, lowercase: true, default: 'en', index: true },
    publishedAt: { type: Date, default: null, index: true },
    /** political interview | political debate | press meet */
    category: { type: String, trim: true, lowercase: true, index: true },
    classificationMethod: { type: String, enum: ['keyword', 'ml'], default: 'keyword' },
    classificationScore: { type: Number, min: 0, max: 1, default: null },
    description: { type: String, maxlength: 500, default: null },
    newsPostId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'NewsPost',
      default: null,
      index: true,
    },
  },
  { timestamps: true },
);

politicalVideoSchema.index({ language: 1, publishedAt: -1 });
politicalVideoSchema.index({ category: 1, publishedAt: -1 });

module.exports = mongoose.model('PoliticalVideo', politicalVideoSchema);
