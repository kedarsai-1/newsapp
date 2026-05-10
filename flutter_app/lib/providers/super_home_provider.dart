import 'package:flutter/foundation.dart' hide Category;

import '../models/models.dart';
import '../services/api_service.dart';

/// Provider that orchestrates the multi-section "super home" feed
/// (top news, entertainment, local, trending, shorts).
///
/// Each section keeps its own posts list so the home screen can render
/// independent rails without re-fetching the user's main feed.
class SuperHomeProvider extends ChangeNotifier {
  bool _loadedOnce = false;
  bool _refreshing = false;
  String? _error;

  List<NewsPost> _topStories = [];
  List<NewsPost> _entertainment = [];
  List<NewsPost> _shorts = [];
  List<NewsPost> _local = [];
  List<NewsPost> _trending = [];

  bool get loadedOnce => _loadedOnce;
  bool get refreshing => _refreshing;
  String? get error => _error;

  List<NewsPost> get topStories => _topStories;
  List<NewsPost> get entertainment => _entertainment;
  List<NewsPost> get shorts => _shorts;
  List<NewsPost> get local => _local;
  List<NewsPost> get trending => _trending;

  bool get isEmpty =>
      _topStories.isEmpty &&
      _entertainment.isEmpty &&
      _shorts.isEmpty &&
      _local.isEmpty &&
      _trending.isEmpty;

  Future<void> ensureLoaded({
    required String language,
    required List<Category> categories,
    String? city,
  }) async {
    if (_loadedOnce || _refreshing) return;
    await refresh(
      language: language,
      categories: categories,
      city: city,
    );
  }

  Future<void> refresh({
    required String language,
    required List<Category> categories,
    String? city,
  }) async {
    _refreshing = true;
    _error = null;
    notifyListeners();

    try {
      final entertainmentId = _findCategoryId(categories, 'entertainment');
      final localId = _findCategoryId(categories, 'local');

      final results = await Future.wait<Map<String, dynamic>>([
        // Breaking / trending RSS news -> hero + trending strip.
        ApiService.getFeed(
          page: 1,
          language: language,
          breaking: true,
          sourceTypes: const ['rss', 'api', 'manual'],
          days: 14,
        ),
        // Entertainment.
        ApiService.getFeed(
          page: 1,
          language: language,
          categoryId: entertainmentId,
          sourceTypes: const ['rss', 'api', 'manual'],
          days: 30,
        ),
        // Local / city news.
        ApiService.getFeed(
          page: 1,
          language: language,
          categoryId: localId,
          city: (city ?? '').trim().isEmpty ? null : city!.trim(),
          sourceTypes: const ['rss', 'api', 'manual'],
          days: 30,
        ),
        // Image-rich shorts (any category, last 14 days).
        ApiService.getFeed(
          page: 1,
          language: language,
          sourceTypes: const ['rss'],
          days: 14,
        ),
      ]);

      final breakingPosts = _parsePosts(results[0]);
      final entertainmentPosts = _parsePosts(results[1]);
      final localPosts = _parsePosts(results[2]);
      final shortsPosts = _parsePosts(results[3])
          .where((p) => p.media.any((m) => m.isImage && m.url.isNotEmpty))
          .toList();

      _topStories = breakingPosts
          .where((p) => p.media.any((m) => m.isImage && m.url.isNotEmpty))
          .take(6)
          .toList();
      if (_topStories.isEmpty) {
        _topStories = breakingPosts.take(6).toList();
      }

      _trending = breakingPosts.take(8).toList();
      _entertainment = entertainmentPosts.take(10).toList();
      _local = localPosts.take(10).toList();
      _shorts = shortsPosts.take(12).toList();

      if (isEmpty) {
        _error =
            'Could not reach the news server. Pull to refresh or try again shortly.';
      }
    } catch (e) {
      _error =
          'Connection error while loading the home feed. Pull to refresh to retry.';
      if (kDebugMode) debugPrint('[SuperHomeProvider] refresh failed: $e');
    } finally {
      _loadedOnce = true;
      _refreshing = false;
      notifyListeners();
    }
  }

  static String? _findCategoryId(List<Category> categories, String slug) {
    final s = slug.toLowerCase();
    for (final c in categories) {
      if (c.slug.toLowerCase() == s) return c.id;
    }
    return null;
  }

  static List<NewsPost> _parsePosts(Map<String, dynamic> res) {
    if (res['success'] != true) return const [];
    final raw = res['posts'];
    if (raw is! List) return const [];
    final out = <NewsPost>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        out.add(NewsPost.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        // Skip malformed posts.
      }
    }
    out.sort((a, b) => b.displayTime.compareTo(a.displayTime));
    return out;
  }
}
