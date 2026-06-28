import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Offline playlist for saved video stories
class VideoPlaylistService {
  static const _storageKey = 'video_playlist_v1_all';
  static const _maxEntries = 100;

  /// Get all playlist entries
  static Future<List<NewsPost>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => NewsPost.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.isYoutube)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Add a video to the playlist
  static Future<void> add(NewsPost post) async {
    if (!post.isYoutube) return;
    final current = await getAll();
    // Check if already exists
    if (current.any((p) => p.id == post.id)) return;

    final prefs = await SharedPreferences.getInstance();
    final updated = [post, ...current].take(_maxEntries).toList();
    await prefs.setString(
      _storageKey,
      jsonEncode(updated.map((p) => p.toJsonMap()).toList()),
    );
  }

  /// Remove a video from the playlist
  static Future<void> remove(String postId) async {
    final current = await getAll();
    final updated = current.where((p) => p.id != postId).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(updated.map((p) => p.toJsonMap()).toList()),
    );
  }

  /// Check if a video is in the playlist
  static Future<bool> contains(String postId) async {
    final current = await getAll();
    return current.any((p) => p.id == postId);
  }

  /// Clear all playlist entries
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Get playlist count
  static Future<int> count() async {
    final current = await getAll();
    return current.length;
  }
}
