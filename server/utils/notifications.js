const {
  buildIngestNotification,
  breakingTopicEnabled,
  getPushIngestCooldownMs,
  getPushMinInserted,
  isInvalidFcmTokenError,
  normalizeIngestSource,
  parsePushIngestSources,
  pruneInvalidTokensEnabled,
  sanitizeFcmTopic,
  shouldNotifyFeedIngest,
  truncatePushText,
  NOTIFICATION_BODY_MAX,
  NOTIFICATION_TITLE_MAX,
} = require('./pushPolicy');

let admin = null;
let lastIngestPushAt = 0;

const firebaseConfigured = () => Boolean(
  process.env.FIREBASE_PROJECT_ID?.trim()
  && process.env.FIREBASE_CLIENT_EMAIL?.trim()
  && process.env.FIREBASE_PRIVATE_KEY?.trim(),
);

function initFirebaseAdmin() {
  if (admin || !firebaseConfigured()) return admin;
  try {
    const firebaseAdmin = require('firebase-admin');
    if (!firebaseAdmin.apps.length) {
      firebaseAdmin.initializeApp({
        credential: firebaseAdmin.credential.cert({
          projectId: process.env.FIREBASE_PROJECT_ID.trim(),
          privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
          clientEmail: process.env.FIREBASE_CLIENT_EMAIL.trim(),
        }),
      });
    }
    admin = firebaseAdmin;
    console.log('[firebase] push notifications enabled');
  } catch (e) {
    console.warn('Firebase not configured — push notifications disabled.', e.message);
    admin = null;
  }
  return admin;
}

initFirebaseAdmin();

/** FCM data payload values must be strings. */
function normalizeFcmData(data = {}) {
  const out = {};
  for (const [key, value] of Object.entries(data)) {
    if (value === undefined || value === null) continue;
    out[String(key)] = typeof value === 'string' ? value : String(value);
  }
  return out;
}

async function pruneInvalidFcmToken(fcmToken, userId) {
  if (!pruneInvalidTokensEnabled() || !fcmToken) return;
  try {
    const { prisma } = require('../config/prisma');
    if (userId) {
      await prisma.user.updateMany({
        where: { id: userId, fcmToken },
        data: { fcmToken: null },
      });
      return;
    }
    await prisma.user.updateMany({
      where: { fcmToken },
      data: { fcmToken: null },
    });
  } catch (err) {
    console.warn('[push] failed to prune invalid FCM token:', err?.message || err);
  }
}

const sendToDevice = async (fcmToken, title, body, data = {}, options = {}) => {
  const client = initFirebaseAdmin();
  if (!client || !fcmToken) return { success: false, skipped: true };
  const safeTitle = truncatePushText(title, NOTIFICATION_TITLE_MAX);
  const safeBody = truncatePushText(body, NOTIFICATION_BODY_MAX);
  try {
    const messageId = await client.messaging().send({
      token: fcmToken,
      notification: { title: safeTitle, body: safeBody },
      data: normalizeFcmData(data),
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    return { success: true, messageId };
  } catch (error) {
    console.error('FCM send error:', error.message);
    if (isInvalidFcmTokenError(error)) {
      await pruneInvalidFcmToken(fcmToken, options.userId);
    }
    return { success: false, error: error.message, code: error?.code };
  }
};

const sendToTopic = async (topic, title, body, data = {}, options = {}) => {
  const client = initFirebaseAdmin();
  const safeTopic = sanitizeFcmTopic(topic);
  if (!client || !safeTopic) return { success: false, skipped: true };
  const safeTitle = truncatePushText(title, NOTIFICATION_TITLE_MAX);
  const safeBody = truncatePushText(body, NOTIFICATION_BODY_MAX);
  const android = { priority: 'high' };
  if (options.collapseKey) {
    android.collapseKey = String(options.collapseKey);
  }
  try {
    const messageId = await client.messaging().send({
      topic: safeTopic,
      notification: { title: safeTitle, body: safeBody },
      data: normalizeFcmData(data),
      android,
      apns: { payload: { aps: { sound: 'default' } } },
    });
    return { success: true, messageId };
  } catch (error) {
    console.error('FCM topic send error:', error.message);
    return { success: false, error: error.message, code: error?.code };
  }
};

/**
 * Notify subscribers when the feed ingests new approved stories.
 * Controlled by PUSH_NOTIFY_ON_INGEST and pushPolicy thresholds.
 */
const notifyFeedIngestion = async ({ inserted = 0, source = 'news' } = {}) => {
  const decision = shouldNotifyFeedIngest({
    inserted,
    source: normalizeIngestSource(source),
    now: Date.now(),
    lastPushAt: lastIngestPushAt,
    notifyEnabled: process.env.PUSH_NOTIFY_ON_INGEST !== 'false' && firebaseConfigured(),
    minInserted: getPushMinInserted(),
    cooldownMs: getPushIngestCooldownMs(),
    allowedSources: parsePushIngestSources(),
  });
  if (!decision.ok) {
    if (decision.reason !== 'disabled' && Number(inserted) > 0) {
      console.log(`[push] ingest notify skipped: ${decision.reason}`, {
        inserted,
        source: normalizeIngestSource(source),
        minInserted: getPushMinInserted(),
      });
    }
    return decision;
  }

  const { title, body } = buildIngestNotification(decision.count);
  const result = await sendToTopic(
    'all',
    title,
    body,
    { type: 'feed_update', inserted: String(decision.count), source: decision.source },
    { collapseKey: 'feed_update' },
  );
  if (result.success) {
    lastIngestPushAt = Date.now();
  }
  return { ...decision, sent: result.success, result };
};

async function notifyPublishedPost(post) {
  if (!post?.id || !post?.category?.slug) return { skipped: true, reason: 'invalid_post' };
  const body = truncatePushText(post.title, NOTIFICATION_BODY_MAX);
  const categoryTopic = `category_${post.category.slug}`;
  const data = { postId: post.id, type: 'news' };

  const categoryResult = await sendToTopic(
    categoryTopic,
    post.isBreaking ? '🔴 Breaking News' : post.category.name,
    body,
    data,
  );

  let breakingResult = null;
  if (post.isBreaking && breakingTopicEnabled()) {
    breakingResult = await sendToTopic(
      'breaking',
      '🔴 Breaking News',
      body,
      data,
    );
  }

  return { categoryResult, breakingResult };
}

function getPushHealth() {
  return {
    configured: firebaseConfigured(),
    enabled: isFirebaseEnabled(),
    notifyOnIngest: process.env.PUSH_NOTIFY_ON_INGEST !== 'false',
    minInserted: getPushMinInserted(),
    ingestCooldownMs: getPushIngestCooldownMs(),
    ingestSources: [...parsePushIngestSources()],
    breakingTopic: breakingTopicEnabled(),
    pruneInvalidTokens: pruneInvalidTokensEnabled(),
  };
}

const isFirebaseEnabled = () => Boolean(initFirebaseAdmin());

function resetIngestPushCooldownForTests() {
  lastIngestPushAt = 0;
}

module.exports = {
  sendToDevice,
  sendToTopic,
  notifyFeedIngestion,
  notifyPublishedPost,
  isFirebaseEnabled,
  getPushHealth,
  normalizeFcmData,
  resetIngestPushCooldownForTests,
};
