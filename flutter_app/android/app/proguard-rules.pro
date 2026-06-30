# android/app/proguard-rules.pro
# ProGuard rules for News App release builds
# Generated for production hardening of a Flutter + Dart Android app

# =============================================================================
# Flutter / Dart Engine
# =============================================================================

# Keep Flutter-related classes (engine, embedding, Dart VM bridge)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep generated plugin registrant
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Keep all Flutter embedding classes
-keep class androidx.lifecycle.** { *; }

# =============================================================================
# Dart / Isolate / Compiler
# =============================================================================

# Keep Dart isolate classes
-keep class dart.** { *; }

# Keep the Dart VM classes
-keep class dalvik.system.** { *; }

# =============================================================================
# Model / Data Classes (Dart/Flutter data models)
# These classes are serialized/deserialized via code generation or reflection
# and must not be stripped or obfuscated.
# =============================================================================

# News / Feed models
-keep class com.example.news_app.** { *; }

# Keep all data / model classes by common naming conventions
-keep class *NewsPost { *; }
-keep class *NewsArticle { *; }
-keep class *Feed { *; }
-keep class *Category { *; }
-keep class *User { *; }
-keep class *Reporter { *; }
-keep class *Article { *; }
-keep class *VideoPlaylist { *; }
-keep class *VideoItem { *; }
-keep class *WeatherData { *; }
-keep class *BreakingNews { *; }
-keep class *Bookmark { *; }
-keep class *NotificationData { *; }
-keep class *Publisher { *; }
-keep class *Topic { *; }
-keep class *Language { *; }
-keep class *City { *; }
-keep class *LocationData { *; }
-keep class *AuthResult { *; }
-keep class *LoginResult { *; }
-keep class *RegisterResult { *; }
-keep class *AiChatResponse { *; }
-keep class *ChatMessage { *; }

# Keep any classes annotated with @JsonSerializable / @HiveType / @Freezed
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
    @com.google.gson.annotations.Expose <fields>;
    @com.google.gson.annotations.Since <fields>;
    @com.google.gson.annotations.Until <fields>;
}

# =============================================================================
# HTTP / Networking
# =============================================================================

# Keep the http package client classes
-keep class io.github.zenwolfx.requests.** { *; }
-keep class io.http.HttpClient { *; }
-keep class dart.io.** { *; }

# Keep all OkHttp classes (used transitively by Flutter's HttpClient)
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Keep the Interceptor / Authenticator / ConnectionSpec classes
-keep class * implements okhttp3.Interceptor { *; }
-keep class * implements okhttp3.Authenticator { *; }

# =============================================================================
# Provider / State Management
# =============================================================================

-keep class provider.** { *; }
-keep class ChangeNotifier { *; }
-keep class * extends ChangeNotifier { *; }

# =============================================================================
# GoRouter / Navigation
# =============================================================================

-keep class go_router.** { *; }
-keep class * extends go_router.GoRoute { *; }
-keep class * extends go_router.ShellRoute { *; }
-keep class * implements go_router.GoRouter { *; }

# =============================================================================
# Firebase
# =============================================================================

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Firebase Crashlytics — must preserve crash-report classes
-keep class com.google.firebase.crashlytics.** { *; }
-keep class com.crashlytics.** { *; }
-keepattributes *Annotation*

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }

# =============================================================================
# Google Fonts
# =============================================================================

-keep class com.google.android.gms.fonts.** { *; }
-keep class com.google.android.gms.** { *; }

# =============================================================================
# Image Picker / Camera
# =============================================================================

-keep class io.flutter.plugins.imagepicker.** { *; }

# =============================================================================
# WebView
# =============================================================================

-keep class io.flutter.plugins.webviewflutter.** { *; }
-keep class android.webkit.** { *; }

# =============================================================================
# Location
# =============================================================================

-keep class com.baseflow.geolocator.** { *; }
-keep class io.flutter.plugins.geolocator.** { *; }

# =============================================================================
# Socket.IO
# =============================================================================

-keep class io.socket.** { *; }
-keep class io.flutter.plugins.socket_io_client.** { *; }

# =============================================================================
# Notifications
# =============================================================================

-keep class io.flutter.plugins.flutter_local_notifications.** { *; }
-keep class com.dexterous.** { *; }
-keep class androidx.core.app.** { *; }

# =============================================================================
# Video Player
# =============================================================================

-keep class io.flutter.plugins.videoplayer.** { *; }
-keep class com.google.android.exoplayer2.** { *; }

# =============================================================================
# Shared Preferences / Secure Storage
# =============================================================================

-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# =============================================================================
# Cached Network Image
# =============================================================================

-keep class com.bumptech.glide.** { *; }
-keep class io.flutter.plugins.cached_network_image.** { *; }

# =============================================================================
# General ProGuard (R8 default optimizations)
# =============================================================================

# Keep line numbers for stack traces
-keepattributes SourceFile,LineNumberTable

# Keep annotations
-keepattributes *Annotation*

# Keep generic signatures
-keepattributes Signature

# Keep inner classes
-keepattributes InnerClasses

# Don't warn about missing AndroidX / Jetpack classes on older SDKs
-dontwarn androidx.**
-dontwarn com.google.**
-dontwarn okhttp3.**
-dontwarn io.socket.**
-dontwarn com.google.firebase.**

# =============================================================================
# General optimizations for release
# =============================================================================

# Allow obfuscation of Flutter assets (not source code)
-assumenosideeffects class io.flutter.util.** { *; }

# Remove logging calls in release
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}
