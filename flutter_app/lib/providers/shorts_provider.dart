import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../models/models.dart';
import '../services/api_service.dart';

/// RSS-only vertical shorts feed (independent from the main mixed feed).
class ShortsProvider extends ChangeNotifier {
  List<NewsPost> _posts = [];
  int _page = 1;
  bool _loading = false;
  bool _refreshing = false;
  bool _hasMore = true;
  String? _error;
  String? _loadedLanguageTag;
  bool _busy = false;

  List<NewsPost> get posts => List.unmodifiable(_posts);
  bool get loading => _loading;
  bool get refreshing => _refreshing;
  bool get hasMore => _hasMore;
  String? get error => _error;

  static String _tag(String? language) => language ?? '__all__';

  bool languageMatches(String? language) =>
      _loadedLanguageTag == _tag(language);

  /// True when we already have posts for this language filter.
  bool hasContentFor(String? language) =>
      _posts.isNotEmpty && languageMatches(language);

  Future<void> refresh({required String? language}) async {
    if (_busy) return;
    _busy = true;
    _refreshing = true;
    _error = null;
    _page = 1;
    _hasMore = true;
    notifyListeners();
    try {
      await _fetch(reset: true, language: language);
    } finally {
      _refreshing = false;
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> loadMore({required String? language}) async {
    if (_busy || _loading || !_hasMore) return;
    if (!languageMatches(language)) return;
    _loading = true;
    notifyListeners();
    try {
      await _fetch(reset: false, language: language);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _fetch({required bool reset, required String? language}) async {
    try {
      final res = await ApiService.getFeed(
        page: reset ? 1 : _page,
        categoryId: null,
        language: language,
        constituency: null,
        politicsScope: null,
        search: null,
        breaking: false,
        days: 30,
        sourceTypes: const ['rss'],
        hasVideo: true,
      );
      if (res['success'] == true && res['posts'] is List) {
        final raw = res['posts'] as List;
        final fetched = <NewsPost>[];
        for (final p in raw) {
          if (p is! Map) continue;
          try {
            fetched.add(
              NewsPost.fromJson(Map<String, dynamic>.from(p)),
            );
          } catch (_) {
            // Skip malformed API rows.
          }
        }
        if (reset) {
          _posts = fetched;
          _page = 2;
        } else {
          _posts = [..._posts, ...fetched];
          _page++;
        }
        _hasMore = fetched.length == AppConstants.pageSize;
        _error = null;
        _loadedLanguageTag = _tag(language);
      } else {
        if (reset) {
          _posts = [];
          _loadedLanguageTag = null;
        }
        final msg = res['message']?.toString().trim();
        _error = (msg != null && msg.isNotEmpty)
            ? msg
            : 'Could not load RSS shorts.';
      }
    } catch (e) {
      if (reset) {
        _posts = [];
        _loadedLanguageTag = null;
      }
      _error = e.toString();
    }
  }
}
