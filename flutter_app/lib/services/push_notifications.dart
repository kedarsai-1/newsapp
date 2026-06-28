import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'firebase_bootstrap.dart';
import 'notification_service.dart';

/// Registers device FCM token + topic subscriptions for news alerts.
class PushNotifications {
  static const _topicsKey = 'push_subscribed_topics';
  static const _languagePrefKey = 'preferred_feed_language';

  /// Core topics — digest is added per feed language only.
  static const coreTopics = ['all', 'breaking'];

  static List<String> topicsForLanguage(
    String languageCode, {
    bool dailyDigest = true,
    bool breakingAlerts = true,
  }) {
    final topics = <String>['all'];
    if (breakingAlerts) topics.add('breaking');
    if (dailyDigest) {
      final lang = languageCode.toLowerCase();
      if (lang == 'en' || lang == 'hi' || lang == 'te') {
        topics.add('digest_$lang');
      } else {
        topics.add('digest_en');
      }
    }
    return topics;
  }

  static Future<String> _readFeedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languagePrefKey) ?? 'all';
  }

  static Future<void> bootstrap() async {
    final ok = await FirebaseBootstrap.init();
    if (!ok) return;
    await NotificationService.init();
    NotificationService.onOpenArticle = _routeOpen;
    FirebaseMessaging.instance.onTokenRefresh.listen(_syncToken);
    final token = await NotificationService.getToken();
    await _syncToken(token);
  }

  static String? _pendingArticleId;

  /// Call after [MaterialApp.router] is mounted.
  static void handlePendingNavigation(void Function(String postId) navigate) {
    final id = _pendingArticleId;
    if (id == null || id.isEmpty) return;
    _pendingArticleId = null;
    navigate(id);
  }

  static void _routeOpen(String? postId) {
    if (postId == null || postId.isEmpty) return;
    _pendingArticleId = postId;
  }

  static Future<void> enableForGuest({String? languageCode}) async {
    final ok = await FirebaseBootstrap.init();
    if (!ok) return;
    await NotificationService.init();
    final lang = languageCode ?? await _readFeedLanguage();
    await applyTopics(topicsForLanguage(lang));
  }

  static Future<void> syncAfterLogin({String? languageCode}) async {
    if (!FirebaseBootstrap.isInitialized) return;
    final token = await NotificationService.getToken();
    await _syncToken(token);
    final lang = languageCode ?? await _readFeedLanguage();
    await applyTopics(topicsForLanguage(lang));
  }

  static Future<void> clearOnLogout() async {
    if (!FirebaseBootstrap.isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final topics = prefs.getStringList(_topicsKey) ?? [];
      for (final t in topics) {
        await NotificationService.unsubscribeFromTopic(t);
      }
      await prefs.remove(_topicsKey);
    } catch (e) {
      if (kDebugMode) debugPrint('[Push] clearOnLogout: $e');
    }
  }

  /// Subscribe interest slugs as `category_<slug>` plus language-aware defaults.
  static Future<void> syncInterestTopics(
    List<String> interestSlugs, {
    String? languageCode,
    bool dailyDigest = true,
  }) async {
    final lang = languageCode ?? await _readFeedLanguage();
    final topics = <String>{
      ...topicsForLanguage(lang, dailyDigest: dailyDigest),
      for (final s in interestSlugs)
        if (s.trim().isNotEmpty) 'category_${s.trim().toLowerCase()}',
    };
    await applyTopics(topics.toList());
  }

  static Future<void> applyTopics(List<String> topics) async {
    if (!FirebaseBootstrap.isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    final previous = Set<String>.from(prefs.getStringList(_topicsKey) ?? []);
    final next = topics.map((t) => t.trim()).where((t) => t.isNotEmpty).toSet();

    for (final t in previous.difference(next)) {
      await NotificationService.unsubscribeFromTopic(t);
    }
    for (final t in next.difference(previous)) {
      await NotificationService.subscribeToTopic(t);
    }
    await prefs.setStringList(_topicsKey, next.toList());
  }

  static Future<void> _syncToken(String? token) async {
    if (token == null || token.isEmpty || !ApiService.isAuthenticated) return;
    try {
      await ApiService.updateFcmToken(token);
    } catch (e) {
      if (kDebugMode) debugPrint('[Push] FCM token sync failed: $e');
    }
  }
}
