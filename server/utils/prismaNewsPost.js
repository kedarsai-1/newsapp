const { prisma } = require('../config/prisma');
const { idOf } = require('./serializers');

const newsPostInclude = {
  reporter: true,
  category: true,
  approvedBy: true,
  media: { orderBy: { order: 'asc' } },
  entities: true,
};

function nullIfBlank(value) {
  if (value == null) return null;
  const s = String(value).trim();
  return s ? s : null;
}

function flattenLocation(location) {
  if (!location) return {};
  return {
    locationLatitude: location.latitude != null ? Number(location.latitude) : null,
    locationLongitude: location.longitude != null ? Number(location.longitude) : null,
    locationAddress: location.address ?? null,
    locationCity: location.city ?? null,
    locationState: location.state ?? null,
    locationCountry: location.country ?? 'India',
    locationCapturedAt: location.capturedAt ? new Date(location.capturedAt) : new Date(),
  };
}

function flattenYoutube(youtube) {
  if (!youtube?.videoId) return {};
  return {
    youtubeVideoId: nullIfBlank(youtube.videoId),
    youtubeChannelId: nullIfBlank(youtube.channelId),
    youtubeChannelTitle: nullIfBlank(youtube.channelTitle),
    youtubeEmbedUrl: nullIfBlank(youtube.embedUrl),
    youtubeWatchUrl: nullIfBlank(youtube.watchUrl),
    youtubeChannelUrl: nullIfBlank(youtube.channelUrl),
    youtubeDurationSeconds: youtube.durationSeconds == null ? null : Number(youtube.durationSeconds),
    youtubeIsShort: youtube.isShort == null ? null : Boolean(youtube.isShort),
    youtubeEmbeddable: youtube.embeddable == null ? null : Boolean(youtube.embeddable),
    youtubePrivacyStatus: nullIfBlank(youtube.privacyStatus),
  };
}

function mediaCreate(media = []) {
  return media.map((m, order) => ({
    type: m.type || 'image',
    url: m.url,
    thumbnail: m.thumbnail ?? null,
    publicId: m.publicId ?? null,
    size: Number(m.size || 0),
    duration: m.duration == null ? null : Number(m.duration),
    order,
  })).filter((m) => m.url);
}

function entitiesCreate(entities = []) {
  return entities.map((e) => ({
    text: e.text ?? null,
    label: e.label ? String(e.label).toUpperCase() : null,
  }));
}

function newsPostDataFromDoc(doc) {
  const data = {
    title: String(doc.title || '').slice(0, 200),
    body: doc.body || doc.title || '',
    summary: doc.summary ? String(doc.summary).slice(0, 300) : null,
    reporterId: idOf(doc.reporter ?? doc.reporterId),
    categoryId: idOf(doc.category ?? doc.categoryId),
    status: doc.status || 'pending',
    rejectionReason: doc.rejectionReason ?? null,
    approvedById: doc.approvedBy ? idOf(doc.approvedBy) : doc.approvedById ? idOf(doc.approvedById) : null,
    approvedAt: doc.approvedAt ? new Date(doc.approvedAt) : null,
    views: Number(doc.views || 0),
    likes: Number(doc.likes || 0),
    isFeatured: Boolean(doc.isFeatured),
    isBreaking: Boolean(doc.isBreaking),
    tags: Array.isArray(doc.tags) ? doc.tags.map((t) => String(t).toLowerCase()) : [],
    language: String(doc.language || 'en').toLowerCase(),
    originalLanguage: doc.originalLanguage ? String(doc.originalLanguage).slice(0, 12) : null,
    sourceName: doc.sourceName ?? null,
    sourceUrl: nullIfBlank(doc.sourceUrl),
    sourceUrlHash: nullIfBlank(doc.sourceUrlHash),
    titleNormalized: nullIfBlank(doc.titleNormalized),
    titleFingerprint: nullIfBlank(doc.titleFingerprint),
    summaryFingerprint: nullIfBlank(doc.summaryFingerprint),
    sourcePublishedAt: doc.sourcePublishedAt ? new Date(doc.sourcePublishedAt) : null,
    sourceType: doc.sourceType || 'manual',
    politicsScope: doc.politicsScope ?? null,
    constituency: doc.constituency ?? 'Unknown',
    scrapedAt: doc.scrapedAt ? new Date(doc.scrapedAt) : null,
    scrapeConfidence: doc.scrapeConfidence == null ? null : Number(doc.scrapeConfidence),
    videoCategory: doc.videoCategory ?? null,
    videoClassificationMethod: doc.videoClassificationMethod ?? null,
    videoClassificationScore: doc.videoClassificationScore == null ? null : Number(doc.videoClassificationScore),
    ...flattenLocation(doc.location),
    ...flattenYoutube(doc.youtube),
  };
  if (Array.isArray(doc.media) && doc.media.length) {
    data.media = { create: mediaCreate(doc.media) };
  }
  if (Array.isArray(doc.entities) && doc.entities.length) {
    data.entities = { create: entitiesCreate(doc.entities) };
  }
  return data;
}

async function createNewsPost(doc, args = {}) {
  return prisma.newsPost.create({
    ...args,
    data: newsPostDataFromDoc(doc),
  });
}

module.exports = {
  newsPostInclude,
  newsPostDataFromDoc,
  mediaCreate,
  entitiesCreate,
  createNewsPost,
  flattenLocation,
  flattenYoutube,
};
