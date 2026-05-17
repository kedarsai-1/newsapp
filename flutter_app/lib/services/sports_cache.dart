import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight local cache for sports API payloads (offline-first UX).
class SportsCache {
  static const _liveKey = 'sports_cache_live_v1';
  static const _newsKey = 'sports_cache_news_v1';

  static Future<void> saveLive(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _liveKey,
      jsonEncode({...payload, 'savedAt': DateTime.now().toIso8601String()}),
    );
  }

  static Future<Map<String, dynamic>?> loadLive() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_liveKey);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveNewsPage(int page, Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_newsKey}_$page', jsonEncode(payload));
  }

  static Future<Map<String, dynamic>?> loadNewsPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_newsKey}_$page');
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }
}
