import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Initializes Firebase when platform config files are present.
class FirebaseBootstrap {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<bool> init() async {
    if (_initialized) return true;
    if (!DefaultFirebaseOptions.isConfigured) {
      if (kDebugMode) {
        debugPrint(
          '[Firebase] Not configured. Add google-services.json / '
          'GoogleService-Info.plist and run flutterfire configure. '
          'See docs/FIREBASE_SETUP.md',
        );
      }
      return false;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      _initialized = true;
      return true;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Firebase] init skipped or failed: $e\n$st');
      }
      return false;
    }
  }
}
