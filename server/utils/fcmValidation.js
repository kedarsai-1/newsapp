const MIN_FCM_TOKEN_LEN = 50;
const MAX_FCM_TOKEN_LEN = 4096;

function validateFcmToken(fcmToken) {
  if (fcmToken === null || fcmToken === undefined) {
    return { ok: false, message: 'FCM token is required.' };
  }
  const token = String(fcmToken).trim();
  if (!token) {
    return { ok: false, message: 'FCM token is required.' };
  }
  if (token.length < MIN_FCM_TOKEN_LEN || token.length > MAX_FCM_TOKEN_LEN) {
    return { ok: false, message: 'Invalid FCM token format.' };
  }
  return { ok: true, value: token };
}

module.exports = {
  MIN_FCM_TOKEN_LEN,
  MAX_FCM_TOKEN_LEN,
  validateFcmToken,
};
