function idOf(value) {
  if (!value) return value;
  if (typeof value === 'string') return value;
  if (typeof value === 'object' && value.id) return String(value.id);
  return String(value);
}

function stripUndefined(obj) {
  return Object.fromEntries(Object.entries(obj).filter(([, value]) => value !== undefined));
}

function serializeUser(user, { includePrivate = false } = {}) {
  if (!user) return user;
  const out = stripUndefined({
    _id: idOf(user.id),
    id: idOf(user.id),
    name: user.name,
    email: user.email,
    role: user.role,
    avatar: user.avatar,
    phone: user.phone,
    bio: user.bio,
    isActive: user.isActive,
    isVerified: user.isVerified,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  });
  if (includePrivate) {
    out.fcmToken = user.fcmToken;
  }
  return out;
}

function serializeCategory(category) {
  if (!category) return category;
  return stripUndefined({
    _id: idOf(category.id),
    id: idOf(category.id),
    name: category.name,
    slug: category.slug,
    icon: category.icon,
    color: category.color,
    isActive: category.isActive,
    order: category.order,
    createdAt: category.createdAt,
    updatedAt: category.updatedAt,
  });
}

function serializeMedia(item) {
  if (!item) return item;
  return stripUndefined({
    _id: idOf(item.id),
    id: idOf(item.id),
    type: item.type,
    url: item.url,
    thumbnail: item.thumbnail,
    publicId: item.publicId,
    size: item.size,
    duration: item.duration,
    createdAt: item.createdAt,
  });
}

function serializeLocation(post) {
  if (post.locationLatitude == null || post.locationLongitude == null) return undefined;
  return {
    latitude: post.locationLatitude,
    longitude: post.locationLongitude,
    address: post.locationAddress,
    city: post.locationCity,
    district: post.locationDistrict,
    mandal: post.locationMandal,
    state: post.locationState,
    country: post.locationCountry || 'India',
    capturedAt: post.locationCapturedAt,
  };
}

function serializeYoutube(post) {
  if (!post.youtubeVideoId) return undefined;
  return stripUndefined({
    videoId: post.youtubeVideoId,
    channelId: post.youtubeChannelId,
    channelTitle: post.youtubeChannelTitle,
    embedUrl: post.youtubeEmbedUrl,
    watchUrl: post.youtubeWatchUrl,
    channelUrl: post.youtubeChannelUrl,
    durationSeconds: post.youtubeDurationSeconds,
    isShort: post.youtubeIsShort,
    embeddable: post.youtubeEmbeddable,
    privacyStatus: post.youtubePrivacyStatus,
  });
}

function serializeEntity(entity) {
  if (!entity) return entity;
  return stripUndefined({
    _id: idOf(entity.id),
    id: idOf(entity.id),
    text: entity.text,
    label: entity.label,
  });
}

const SYSTEM_REPORTER_NAME = 'News Ingestion Bot';
const INGEST_SOURCE_PREFIXES = ['RSS · ', 'YouTube · ', 'GNews · ', 'NewsAPI · '];

/** Strip ingestion prefixes for display (RSS · NTV → NTV). */
function cleanIngestSourceLabel(raw) {
  const src = String(raw || '').trim();
  if (!src) return null;
  for (const prefix of INGEST_SOURCE_PREFIXES) {
    if (src.startsWith(prefix)) return src.slice(prefix.length).trim();
  }
  return src;
}

/** Human-readable publisher/outlet for feeds and article detail. */
function publisherNameFromPost(post) {
  const cleaned = cleanIngestSourceLabel(post?.sourceName);
  if (cleaned) return cleaned;
  const ytTitle = post?.youtubeChannelTitle || post?.youtube?.channelTitle;
  if (String(post?.sourceType || '').toLowerCase() === 'youtube' && ytTitle) {
    return String(ytTitle).trim();
  }
  const reporterName = String(post?.reporter?.name || '').trim();
  if (reporterName && reporterName !== SYSTEM_REPORTER_NAME) return reporterName;
  const categoryName = String(post?.category?.name || '').trim();
  if (categoryName) return categoryName;
  return 'News';
}

function serializeReporterForPublic(post, { includePrivate = false, compact = false } = {}) {
  if (!post?.reporter) return idOf(post?.reporterId);
  const displayName = post.reporter.name === SYSTEM_REPORTER_NAME
    ? publisherNameFromPost(post)
    : post.reporter.name;
  if (compact) {
    return stripUndefined({
      _id: idOf(post.reporter.id),
      id: idOf(post.reporter.id),
      name: displayName,
      avatar: post.reporter.avatar,
    });
  }
  const serialized = serializeUser(post.reporter, { includePrivate });
  if (typeof serialized !== 'object' || serialized == null) return serialized;
  if (serialized.name === SYSTEM_REPORTER_NAME) {
    return { ...serialized, name: displayName };
  }
  return serialized;
}

function serializeNewsPost(post, options = {}) {
  if (!post) return post;
  const includePrivateUser = Boolean(options.includePrivateUser);
  const publisherName = publisherNameFromPost(post);
  return stripUndefined({
    _id: idOf(post.id),
    id: idOf(post.id),
    title: post.title,
    body: post.body,
    summary: post.summary,
    reporter: serializeReporterForPublic(post, { includePrivate: includePrivateUser }),
    category: post.category ? serializeCategory(post.category) : idOf(post.categoryId),
    media: Array.isArray(post.media) ? post.media.map(serializeMedia) : [],
    location: serializeLocation(post),
    status: post.status,
    rejectionReason: post.rejectionReason,
    approvedBy: post.approvedBy ? serializeUser(post.approvedBy) : idOf(post.approvedById),
    approvedAt: post.approvedAt,
    views: post.views,
    likes: post.likes,
    isFeatured: post.isFeatured,
    isBreaking: post.isBreaking,
    tags: post.tags || [],
    language: post.language,
    originalLanguage: post.originalLanguage,
    sourceName: post.sourceName,
    publisherName,
    sourceUrl: post.sourceUrl,
    sourceUrlHash: post.sourceUrlHash,
    titleNormalized: post.titleNormalized,
    titleFingerprint: post.titleFingerprint,
    summaryFingerprint: post.summaryFingerprint,
    sourcePublishedAt: post.sourcePublishedAt,
    sourceType: post.sourceType,
    youtube: serializeYoutube(post),
    politicsScope: post.politicsScope,
    constituency: post.constituency,
    locationDistrict: post.locationDistrict,
    locationMandal: post.locationMandal,
    entities: Array.isArray(post.entities) ? post.entities.map(serializeEntity) : [],
    scrapedAt: post.scrapedAt,
    scrapeConfidence: post.scrapeConfidence,
    videoCategory: post.videoCategory,
    videoClassificationMethod: post.videoClassificationMethod,
    videoClassificationScore: post.videoClassificationScore,
    createdAt: post.createdAt,
    updatedAt: post.updatedAt,
  });
}

/** Compact feed-list payload — omits full body and admin/dedupe metadata. */
function serializeFeedPost(post, options = {}) {
  if (!post) return post;
  const publisherName = publisherNameFromPost(post);

  return stripUndefined({
    _id: idOf(post.id),
    id: idOf(post.id),
    title: post.title,
    summary: post.summary,
    reporter: serializeReporterForPublic(post, { compact: true }),
    category: post.category ? serializeCategory(post.category) : idOf(post.categoryId),
    media: Array.isArray(post.media) ? post.media.map(serializeMedia) : [],
    location: serializeLocation(post),
    status: post.status,
    views: post.views,
    likes: post.likes,
    isFeatured: post.isFeatured,
    isBreaking: post.isBreaking,
    tags: post.tags || [],
    language: post.language,
    originalLanguage: post.originalLanguage,
    sourceName: post.sourceName,
    publisherName,
    sourceUrl: post.sourceUrl,
    sourcePublishedAt: post.sourcePublishedAt,
    sourceType: post.sourceType,
    youtube: serializeYoutube(post),
    politicsScope: post.politicsScope,
    constituency: post.constituency,
    locationDistrict: post.locationDistrict,
    locationMandal: post.locationMandal,
    videoCategory: post.videoCategory,
    videoClassificationMethod: post.videoClassificationMethod,
    videoClassificationScore: post.videoClassificationScore,
    createdAt: post.createdAt,
    updatedAt: post.updatedAt,
    seen: options.seen,
  });
}

function serializeComment(comment) {
  if (!comment) return comment;
  return stripUndefined({
    _id: idOf(comment.id),
    id: idOf(comment.id),
    post: idOf(comment.postId),
    user: comment.user ? serializeUser(comment.user) : idOf(comment.userId),
    text: comment.text,
    likes: comment.likes,
    isDeleted: comment.isDeleted,
    createdAt: comment.createdAt,
    updatedAt: comment.updatedAt,
  });
}

module.exports = {
  idOf,
  serializeUser,
  serializeCategory,
  serializeMedia,
  serializeNewsPost,
  serializeFeedPost,
  serializeComment,
  publisherNameFromPost,
  cleanIngestSourceLabel,
};
