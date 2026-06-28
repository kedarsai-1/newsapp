import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Offline cache for individual articles (for reading without internet).
/// Articles are cached when opened and saved for up to 48 hours.
class ArticleCache {
  static const _prefix = 'article_cache_v1_';
  static const _maxAge = Duration(hours: 48);
  static const _maxEntries = 50;

  /// Cache key for a specific post
  static String _key(String postId) {
    return '$_prefix$postId';
  }

  /// Save a single article for offline reading
  static Future<void> save(NewsPost post) async {
    if (post.id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'savedAt': DateTime.now().toIso8601String(),
      'post': post.toJsonMap(),
    };
    await prefs.setString(_key(post.id), jsonEncode(payload));

    // Cleanup old entries if we have too many
    await _cleanupIfNeeded(prefs);
  }

  /// Load a cached article
  static Future<NewsPost?> load(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(postId));
    if (raw == null) return null;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final savedAt = DateTime.tryParse(map['savedAt']?.toString() ?? '');
      if (savedAt == null ||
          DateTime.now().difference(savedAt) > _maxAge) {
        // Expired, remove it
        await prefs.remove(_key(postId));
        return null;
      }
      final postData = map['post'];
      if (postData is! Map) return null;
      return NewsPost.fromJson(Map<String, dynamic>.from(postData));
    } catch (_) {
      return null;
    }
  }

  /// Check if an article is cached
  static Future<bool> isCached(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(postId));
    if (raw == null) return false;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final savedAt = DateTime.tryParse(map['savedAt']?.toString() ?? '');
      if (savedAt == null ||
          DateTime.now().difference(savedAt) > _maxAge) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get all cached article IDs
  static Future<List<String>> getCachedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final articleIds = <String>[];
    final now = DateTime.now();

    for (final key in keys) {
      if (!key.startsWith(_prefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final savedAt = DateTime.tryParse(map['savedAt']?.toString() ?? '');
        if (savedAt != null && now.difference(savedAt) <= _maxAge) {
          articleIds.add(key.substring(_prefix.length));
        }
      } catch (_) {}
    }
    return articleIds;
  }

  /// Clear all cached articles
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_prefix)) {
        await prefs.remove(key);
      }
    }
  }

  /// Remove a specific cached article
  static Future<void> remove(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(postId));
  }

  /// Cleanup old entries if we exceed max entries
  static Future<void> _cleanupIfNeeded(SharedPreferences prefs) async {
    final keys = prefs.getKeys();
    final articleKeys = <String>[];
    final entries = <Map<String, dynamic>>[];

    for (final key in keys) {
      if (!key.startsWith(_prefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final savedAt = DateTime.tryParse(map['savedAt']?.toString() ?? '');
        if (savedAt != null) {
          entries.add({'key': key, 'savedAt': savedAt});
        }
      } catch (_) {}
    }

    if (entries.length <= _maxEntries) return;

    // Sort by savedAt (oldest first) and remove excess
    entries.sort((a, b) =>
        (a['savedAt'] as DateTime).compareTo(b['savedAt'] as DateTime));

    final toRemove = entries.length - _maxEntries;
    for (int i = 0; i < toRemove; i++) {
      await prefs.remove(entries[i]['key'] as String);
    }
  }

  /// Get cache statistics
  static Future<Map<String, int>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    int count = 0;
    int totalSize = 0;
    final now = DateTime.now();

    for (final key in keys) {
      if (!key.startsWith(_prefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final savedAt = DateTime.tryParse(map['savedAt']?.toString() ?? '');
        if (savedAt != null && now.difference(savedAt) <= _maxAge) {
          count++;
          totalSize += raw.length;
        }
      } catch (_) {}
    }

    return {'count': count, 'bytes': totalSize};
  }
}
