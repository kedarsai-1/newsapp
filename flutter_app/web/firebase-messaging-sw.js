/* Firebase Cloud Messaging service worker for Flutter web.
 * Keep apiKey / appId in sync with lib/firebase_options.dart (web).
 * Register a Web app in Firebase Console, then run: flutterfire configure
 */
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBACo3JEZFP-7X_pMyxFEha1TCdDHp5d98',
  authDomain: 'newsapp-5d1cd.firebaseapp.com',
  projectId: 'newsapp-5d1cd',
  storageBucket: 'newsapp-5d1cd.firebasestorage.app',
  messagingSenderId: '169864829025',
  // Replace after `flutterfire configure` adds the Web app (1:169864829025:web:…)
  appId: 'REPLACE_ME',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] background message', payload);

  const notification = payload?.notification || {};
  const data = payload?.data || {};
  const title = notification.title || data.title || 'News update';
  const body = notification.body || data.body || data.message || '';
  const icon = notification.icon || data.icon || '/icons/Icon-192.png';
  const image = notification.image || data.image;
  const tag = data.tag || data.postId || 'news-feed';
  const url = data.url || data.link || data.click_action || '/';

  const options = {
    body,
    icon,
    tag,
    data: { ...data, url },
  };
  if (image) options.image = image;
  if (notification.actions?.length) options.actions = notification.actions;

  return self.registration.showNotification(title, options);
});
