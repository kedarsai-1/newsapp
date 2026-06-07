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

function serializeNewsPost(post, options = {}) {
  if (!post) return post;
  const includePrivateUser = Boolean(options.includePrivateUser);
  return stripUndefined({
    _id: idOf(post.id),
    id: idOf(post.id),
    title: post.title,
    body: post.body,
    summary: post.summary,
    reporter: post.reporter ? serializeUser(post.reporter, { includePrivate: includePrivateUser }) : idOf(post.reporterId),
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
  const reporter = post.reporter
    ? stripUndefined({
      _id: idOf(post.reporter.id),
      id: idOf(post.reporter.id),
      name: post.reporter.name,
      avatar: post.reporter.avatar,
    })
    : idOf(post.reporterId);

  return stripUndefined({
    _id: idOf(post.id),
    id: idOf(post.id),
    title: post.title,
    summary: post.summary,
    reporter,
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
    sourceUrl: post.sourceUrl,
    sourcePublishedAt: post.sourcePublishedAt,
    sourceType: post.sourceType,
    youtube: serializeYoutube(post),
    politicsScope: post.politicsScope,
    constituency: post.constituency,
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
};
