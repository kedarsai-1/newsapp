import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/publisher_key.dart';

class PublisherFollowResult {
  final bool? following;
  final String? errorMessage;

  const PublisherFollowResult({this.following, this.errorMessage});

  bool get ok => errorMessage == null && following != null;
}

/// Follow publishers — server sync when logged in, local prefs for guests.
abstract final class PublisherFollowService {
  static const _guestKey = 'guest_publisher_follows';
  static Set<String>? _cachedKeys;
  static DateTime? _cacheAt;

  static String publisherKeyForPost(NewsPost post) => publisherKeyFromName(
        post.displaySourceName,
      );

  static Future<Map<String, String>> loadGuestFollows() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_guestKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final follows = <String, String>{};
      for (final e in jsonDecode(raw) as List) {
        if (e is List && e.length >= 2) {
          follows[e[0].toString()] = e[1].toString();
        }
      }
      return follows;
    } catch (_) {
      return {};
    }
  }

  static Future<Set<String>> loadGuestKeys() async {
    final follows = await loadGuestFollows();
    return follows.keys.toSet();
  }

  static Future<void> _saveGuest(Map<String, String> follows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_guestKey, jsonEncode(follows.entries.toList()));
    _cachedKeys = follows.keys.toSet();
    _cacheAt = DateTime.now();
  }

  static Future<Set<String>> _followingKeysLoggedIn({bool force = false}) async {
    if (!force &&
        _cachedKeys != null &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < const Duration(minutes: 2)) {
      return _cachedKeys!;
    }
    final res = await ApiService.getFollowingPublishers();
    if (res['success'] != true) return {};
    final list = res['following'] as List? ?? [];
    final keys = list
        .map((f) => (f as Map)['publisherKey']?.toString() ?? '')
        .where((k) => k.isNotEmpty)
        .toSet();
    _cachedKeys = keys;
    _cacheAt = DateTime.now();
    return keys;
  }

  static void invalidateCache() {
    _cachedKeys = null;
    _cacheAt = null;
  }

  static Future<bool> isFollowing(NewsPost post, {bool loggedIn = false}) async {
    final key = publisherKeyForPost(post);
    if (key.isEmpty) return false;
    if (loggedIn && ApiService.isAuthenticated) {
      final keys = await _followingKeysLoggedIn();
      return keys.contains(key);
    }
    final keys = await loadGuestKeys();
    return keys.contains(key);
  }

  static Future<PublisherFollowResult> toggle(
    NewsPost post, {
    required bool loggedIn,
  }) async {
    final key = publisherKeyForPost(post);
    final name = post.displaySourceName.trim();
    if (key.isEmpty || name.isEmpty) {
      return const PublisherFollowResult(
        errorMessage: 'This publisher cannot be followed.',
      );
    }

    final useServer = loggedIn && ApiService.isAuthenticated;
    if (useServer) {
      final res = await ApiService.togglePublisherFollow(
        publisherKey: key,
        publisherName: name,
      );
      invalidateCache();
      if (res['success'] == true) {
        return PublisherFollowResult(following: res['following'] == true);
      }
      final msg = res['message']?.toString().trim();
      return PublisherFollowResult(
        errorMessage: msg?.isNotEmpty == true
            ? msg
            : 'Could not update follow. Try again.',
      );
    }

    final follows = await loadGuestFollows();
    if (follows.containsKey(key)) {
      follows.remove(key);
    } else {
      follows[key] = name;
    }
    await _saveGuest(follows);
    return PublisherFollowResult(following: follows.containsKey(key));
  }

  /// Merge guest follows into the server account after login/register.
  static Future<void> migrateGuestFollowsToServer() async {
    if (!ApiService.isAuthenticated) return;
    final guest = await loadGuestFollows();
    if (guest.isEmpty) return;
    final existing = await _followingKeysLoggedIn(force: true);
    for (final entry in guest.entries) {
      if (existing.contains(entry.key)) continue;
      try {
        await ApiService.togglePublisherFollow(
          publisherKey: entry.key,
          publisherName: entry.value,
        );
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestKey);
    invalidateCache();
  }
}
