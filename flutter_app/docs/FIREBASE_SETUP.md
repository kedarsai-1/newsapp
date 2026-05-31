# Firebase setup (Flutter push notifications)

The app uses `firebase_core`, `firebase_messaging`, and `flutter_local_notifications`.
Dart code initializes Firebase in `lib/services/firebase_bootstrap.dart` and registers FCM in `lib/services/push_notifications.dart`.

## 1. Create a Firebase project

1. Open [Firebase Console](https://console.firebase.google.com/) and create a project (or reuse an existing one).
2. Enable **Cloud Messaging** (included by default for mobile apps).

## 2. Register Android and iOS apps

| Platform | Identifier in this repo |
|----------|-------------------------|
| Android  | `com.example.news_app` (`android/app/build.gradle.kts`) |
| iOS      | `com.example.newsApp` (`ios/Runner.xcodeproj`) |

Download the platform config files from Firebase Console:

- **Android:** `google-services.json` → `android/app/google-services.json`
- **iOS:** `GoogleService-Info.plist` → `ios/Runner/GoogleService-Info.plist`

Example templates (do not use in production):

- `android/app/google-services.json.example`
- `ios/Runner/GoogleService-Info.plist.example`

## 3. Generate `firebase_options.dart` (recommended)

```bash
cd flutter_app
dart pub global activate flutterfire_cli
flutterfire configure
```

This updates `lib/firebase_options.dart` and links the platform files above.

If you configure manually, replace `REPLACE_ME` values in `lib/firebase_options.dart` with keys from the Firebase Console.

## 4. Android notes

- The Google Services Gradle plugin is applied automatically when `android/app/google-services.json` exists.
- `POST_NOTIFICATIONS` is declared for Android 13+.
- Default FCM channel id: `news_channel` (matches `NotificationService`).

## 5. iOS notes

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select **Runner** → **Signing & Capabilities** → add **Push Notifications**.
3. Add **Background Modes** → enable **Remote notifications** (also set in `Info.plist`).
4. For production builds, set `aps-environment` to `production` in `Runner.entitlements`.

Upload your APNs key (.p8) or certificate in Firebase Console → Project settings → Cloud Messaging.

## 6. Server (FCM from backend)

Set these in `server/.env` (see `server/.env.example`):

```
FIREBASE_PROJECT_ID=
FIREBASE_CLIENT_EMAIL=
FIREBASE_PRIVATE_KEY=
```

Use a Firebase **service account** JSON from Project settings → Service accounts.

Optional: `PUSH_NOTIFY_ON_INGEST=true` sends a topic push to `all` when new feed items are ingested.

## 7. Verify

```bash
cd flutter_app
flutter run
```

After login, the app syncs the device FCM token to the API and subscribes to topics `all` and `breaking`.

Without config files, Firebase init is skipped safely and the rest of the app still runs.
