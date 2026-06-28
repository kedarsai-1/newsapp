import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Offline-first cache for the Shorts list (per language).
class ShortsCache {
  static const _prefix = 'shorts_cache_v2_';
  static const _maxAge = Duration(hours: 6);

  static String _key(String? language) {
    final tag = (language == null || language.isEmpty || language == 'all')
        ? 'all'
        : language.trim().toLowerCase();
    return '$_prefix$tag';
  }

  static Future<void> saveRaw(String? language, List<Map<String, dynamic>> rawPosts) async {
    if (rawPosts.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'savedAt': DateTime.now().toIso8601String(),
      'posts': rawPosts,
    };
    await prefs.setString(_key(language), jsonEncode(payload));
  }

  static Future<List<NewsPost>?> load(String? language) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(language));
    if (raw == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final savedAt = DateTime.tryParse(map['savedAt']?.toString() ?? '');
      if (savedAt == null ||
          DateTime.now().difference(savedAt) > _maxAge) {
        return null;
      }
      final rows = map['posts'];
      if (rows is! List || rows.isEmpty) return null;
      final posts = <NewsPost>[];
      for (final row in rows) {
        if (row is! Map) continue;
        try {
          final post = NewsPost.fromJson(Map<String, dynamic>.from(row));
          if (!post.isYoutube) continue;
          final vid = post.youtube?.videoId ?? '';
          if (vid.isEmpty) continue;
          posts.add(post);
        } catch (_) {}
      }
      return posts.isEmpty ? null : posts;
    } catch (_) {
      return null;
    }
  }
}
