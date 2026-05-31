let admin = null;

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

const sendToDevice = async (fcmToken, title, body, data = {}) => {
  const client = initFirebaseAdmin();
  if (!client || !fcmToken) return { success: false, skipped: true };
  try {
    await client.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data: normalizeFcmData(data),
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    return { success: true };
  } catch (error) {
    console.error('FCM send error:', error.message);
    return { success: false, error: error.message };
  }
};

const sendToTopic = async (topic, title, body, data = {}) => {
  const client = initFirebaseAdmin();
  if (!client || !topic) return { success: false, skipped: true };
  try {
    await client.messaging().send({
      topic: String(topic).replace(/[^a-zA-Z0-9_-]/g, '_'),
      notification: { title, body },
      data: normalizeFcmData(data),
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    return { success: true };
  } catch (error) {
    console.error('FCM topic send error:', error.message);
    return { success: false, error: error.message };
  }
};

/**
 * Notify subscribers when the feed ingests new approved stories.
 * Controlled by PUSH_NOTIFY_ON_INGEST (default true when Firebase is configured).
 */
const notifyFeedIngestion = async ({ inserted = 0 } = {}) => {
  if (!inserted || inserted < 1) return;
  if (process.env.PUSH_NOTIFY_ON_INGEST === 'false') return;
  if (!firebaseConfigured()) return;

  const count = Number(inserted);
  const title = count === 1 ? 'New story in your feed' : 'Fresh stories in your feed';
  const body = count === 1
    ? 'Tap to read the latest update.'
    : `${count} new stories were added. Tap to catch up.`;

  await sendToTopic('all', title, body, { type: 'feed_update', inserted: String(count) });
};

const isFirebaseEnabled = () => Boolean(initFirebaseAdmin());

module.exports = {
  sendToDevice,
  sendToTopic,
  notifyFeedIngestion,
  isFirebaseEnabled,
  normalizeFcmData,
};
