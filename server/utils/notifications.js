let admin;

try {
  admin = require('firebase-admin');
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      }),
    });
  }
} catch (e) {
  console.warn('Firebase not configured — push notifications disabled.');
}

// Send to a single device
const sendToDevice = async (fcmToken, title, body, data = {}) => {
  if (!admin || !fcmToken) return;
  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data,
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  } catch (error) {
    console.error('FCM send error:', error.message);
  }
};

// Send to a topic (e.g. 'breaking' or 'category_sports')
const sendToTopic = async (topic, title, body, data = {}) => {
  if (!admin) return;
  try {
    await admin.messaging().send({
      topic,
      notification: { title, body },
      data,
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  } catch (error) {
    console.error('FCM topic send error:', error.message);
  }
};

module.exports = { sendToDevice, sendToTopic };