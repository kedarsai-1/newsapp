import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../utils/feed_language.dart';

/// Political interview / debate / press-meet reels (YouTube embed only).
class PoliticalVideosProvider extends ChangeNotifier {
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

  PoliticalVideosProvider() {
    if (!kIsWeb) {
      SocketService.connect();
      SocketService.onFeedUpdated((_) {
        if (_refreshing || _loading || _busy) return;
        final lang = _loadedLanguageTag == '__all__' ? null : _loadedLanguageTag;
        refresh(language: lang);
      });
    }
  }

  static String _tag(String? language) => language ?? '__all__';

  bool languageMatches(String? language) =>
      _loadedLanguageTag == _tag(language);

  Future<void> ensureForLanguage(String? language, {bool force = false}) async {
    if (_busy) return;
    if (!force && languageMatches(language) && _posts.isNotEmpty) return;
    await refresh(language: language);
  }

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
      final res = await ApiService.getPoliticalVideoFeed(
        page: reset ? 1 : _page,
        language: language,
      );
      if (res['success'] == true && res['posts'] is List) {
        final fetched = <NewsPost>[];
        for (final p in res['posts'] as List) {
          if (p is! Map) continue;
          try {
            final post = NewsPost.fromJson(Map<String, dynamic>.from(p));
            if (!post.isYoutube) continue;
            if (post.youtube?.videoId.isEmpty != false) continue;
            if (language != null &&
                language != 'all' &&
                !postMatchesFeedLanguage(post, language)) {
              continue;
            }
            fetched.add(post);
          } catch (_) {}
        }
        fetched.sort((a, b) => b.displayTime.compareTo(a.displayTime));
        if (reset) {
          _posts = fetched;
          _page = 2;
        } else {
          _posts = [..._posts, ...fetched];
          _page++;
        }
        _hasMore = fetched.length >= AppConstants.pageSize;
        _error = null;
        _loadedLanguageTag = _tag(language);
      } else {
        if (reset) {
          _posts = [];
          _loadedLanguageTag = null;
        }
        _error = res['message']?.toString() ?? 'Could not load political videos.';
      }
    } catch (_) {
      if (reset) {
        _posts = [];
        _loadedLanguageTag = null;
      }
      _error = 'Could not load political videos. Check your connection and try again.';
    }
  }
}
