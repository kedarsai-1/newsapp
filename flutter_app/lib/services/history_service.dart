import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Service for tracking and retrieving article reading history.
///
/// Thread-safe: uses `ChangeNotifier` so the UI can `watch()` it.
class HistoryService extends ChangeNotifier {
  static const String _seenPostsKey = 'seen_post_ids_v1';
  static const String _seenPostCacheKey = 'seen_post_cache_v1';
  static const int _maxCacheSize = 200;

  final Set<String> _seenPostIds = {};
  final Map<String, NewsPost> _seenPostCache = {};
  bool _loaded = false;

  bool get loaded => _loaded;
  Set<String> get seenPostIds => Set.unmodifiable(_seenPostIds);
  int get count => _seenPostIds.length;

  /// Posts sorted by most recently seen first.
  List<NewsPost> get allPosts {
    return _seenPostCache.values.toList().reversed.toList();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _seenPostIds
      ..clear()
      ..addAll(prefs.getStringList(_seenPostsKey) ?? const []);

    final cached = prefs.getString(_seenPostCacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        final list = jsonDecode(cached) as List;
        for (final item in list) {
          if (item is Map && item['id'] is String) {
            _seenPostCache[item['id'] as String] = NewsPost.fromJson(
              Map<String, dynamic>.from(item),
            );
          }
        }
      } catch (_) {
        // Corrupted cache — silently ignore.
      }
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> markAsSeen(String postId) async {
    if (postId.isEmpty || _seenPostIds.contains(postId)) return;
    _seenPostIds.add(postId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_seenPostsKey, _seenPostIds.toList());
    notifyListeners();
  }

  /// Optionally enrich the cache with article metadata.
  Future<void> enrichPost(NewsPost post) async {
    if (post.id.isEmpty) return;
    final added = !_seenPostCache.containsKey(post.id);
    _seenPostCache[post.id] = post;
    if (added && _seenPostCache.length > _maxCacheSize) {
      // Evict the oldest entry
      _seenPostCache.remove(_seenPostCache.keys.first);
    }
    await _persistCache();
    if (added) notifyListeners();
  }

  Future<void> _persistCache() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(
      _seenPostCache.values.map((p) => p.toJsonMap()).toList(),
    );
    await prefs.setString(_seenPostCacheKey, json);
  }

  bool isSeen(String postId) => _seenPostIds.contains(postId);

  /// Clears all history. Use with caution.
  Future<void> clearHistory() async {
    _seenPostIds.clear();
    _seenPostCache.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seenPostsKey);
    await prefs.remove(_seenPostCacheKey);
    notifyListeners();
  }
}
