// Firebase options for project newsapp-5d1cd.
// Platform files: android/app/google-services.json, ios/Runner/GoogleService-Info.plist

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for [Firebase.initializeApp].
class DefaultFirebaseOptions {
  static const String _placeholder = 'REPLACE_ME';

  /// True when real Firebase project values are present (not template placeholders).
  static bool get isConfigured =>
      android.apiKey != _placeholder && ios.apiKey != _placeholder;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'Firebase is not configured for $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: '169864829025',
    projectId: 'newsapp-5d1cd',
    authDomain: 'newsapp-5d1cd.firebaseapp.com',
    storageBucket: 'newsapp-5d1cd.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBACo3JEZFP-7X_pMyxFEha1TCdDHp5d98',
    appId: '1:169864829025:android:312f65345017cdd92fb220',
    messagingSenderId: '169864829025',
    projectId: 'newsapp-5d1cd',
    storageBucket: 'newsapp-5d1cd.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD_eth9hWbAVN6GcZ-YTPAEuThy9PP7lbw',
    appId: '1:169864829025:ios:7f05446758d1c8102fb220',
    messagingSenderId: '169864829025',
    projectId: 'newsapp-5d1cd',
    storageBucket: 'newsapp-5d1cd.firebasestorage.app',
    iosBundleId: 'com.example.newsApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD_eth9hWbAVN6GcZ-YTPAEuThy9PP7lbw',
    appId: '1:169864829025:ios:7f05446758d1c8102fb220',
    messagingSenderId: '169864829025',
    projectId: 'newsapp-5d1cd',
    storageBucket: 'newsapp-5d1cd.firebasestorage.app',
    iosBundleId: 'com.example.newsApp',
  );
}
