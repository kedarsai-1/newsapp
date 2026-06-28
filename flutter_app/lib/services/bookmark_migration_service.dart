import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../constants.dart';

/// Migrate guest bookmarks to server after login.
abstract final class BookmarkMigrationService {
  static const _guestKey = 'guest_bookmarks';

  /// Load guest bookmarks from local storage.
  static Future<Map<String, Map<String, dynamic>>> _loadGuestBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.guestBookmarksKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((key, value) =>
          MapEntry(key, value is Map<String, dynamic>
              ? value
              : <String, dynamic>{}));
    } catch (_) {
      return {};
    }
  }

  /// Get existing server bookmarks to avoid duplicates.
  static Future<Set<String>> _getServerBookmarkIds() async {
    try {
      final res = await ApiService.getBookmarks();
      if (res['success'] != true) return {};
      final list = res['bookmarks'] as List? ?? [];
      return list
          .map((b) => (b as Map)['_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  /// Merge guest bookmarks into the server account after login/register.
  static Future<void> migrateGuestBookmarksToServer() async {
    if (!ApiService.isAuthenticated) return;
    final guest = await _loadGuestBookmarks();
    if (guest.isEmpty) return;

    // Get existing server bookmarks to avoid duplicates
    final existing = await _getServerBookmarkIds();

    // Migrate each guest bookmark that's not already on server
    for (final entry in guest.entries) {
      final postId = entry.key;
      if (existing.contains(postId)) continue;

      try {
        // Parse the stored post data
        final postData = entry.value;
        if (postData == null || postData.isEmpty) continue;

        // Call the bookmark API
        await ApiService.toggleBookmark(postId);
      } catch (e) {
        // Continue with next bookmark if one fails
        continue;
      }
    }

    // Clear local guest bookmarks after successful migration
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.guestBookmarksKey);
  }
}
