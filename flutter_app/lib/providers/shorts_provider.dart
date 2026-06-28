import 'package:flutter/foundation.dart';

import '../constants.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/shorts_cache.dart';
import '../services/socket_service.dart';
import '../utils/feed_language.dart';

/// YouTube-only vertical video feed (official iframe embeds).
class ShortsProvider extends ChangeNotifier {
  List<NewsPost> _posts = [];
  int _page = 1;
  bool _loading = false;
  bool _refreshing = false;
  bool _hasMore = true;
  String? _error;
  String? _loadedLanguageTag;
  bool _busy = false;
  bool _socketWired = false;

  List<NewsPost> get posts => List.unmodifiable(_posts);
  bool get loading => _loading;
  bool get refreshing => _refreshing;
  bool get hasMore => _hasMore;
  String? get error => _error;

  ShortsProvider() {
    _wireRealtimeRefresh();
  }

  static String _tag(String? language) => language ?? '__all__';

  /// Client-side guard when DB rows lack language tags (legacy English-only ingest).
  static bool postMatchesLanguage(NewsPost post, String? language) {
    if (language == null || language == 'all') return true;
    return postMatchesFeedLanguage(post, language);
  }

  bool languageMatches(String? language) =>
      _loadedLanguageTag == _tag(language);

  bool hasContentFor(String? language) =>
      _posts.isNotEmpty && languageMatches(language);

  bool get hasStaleContent => _posts.isNotEmpty;

  /// Hydrate from disk so Shorts tab opens instantly.
  Future<void> warmFromDisk(String? language) async {
    if (_posts.isNotEmpty && languageMatches(language)) return;
    final cached = await ShortsCache.load(language);
    if (cached == null || cached.isEmpty) return;
    _posts = cached;
    _loadedLanguageTag = _tag(language);
    _error = null;
    notifyListeners();
  }

  /// Load Shorts for [language] when empty or language changed (e.g. feed preference).
  Future<void> ensureForLanguage(String? language, {bool force = false}) async {
    if (_busy) return;
    if (!force && languageMatches(language) && _posts.isNotEmpty) {
      return;
    }
    if (_posts.isEmpty) {
      await warmFromDisk(language);
    }
    await refresh(language: language, background: _posts.isNotEmpty);
  }

  void _wireRealtimeRefresh() {
    if (kIsWeb || _socketWired) return;
    _socketWired = true;
    SocketService.connect();
    SocketService.onFeedUpdated((_) {
      if (_refreshing || _loading || _busy) return;
      final lang = _loadedLanguageTag == '__all__' ? null : _loadedLanguageTag;
      refresh(language: lang, background: _posts.isNotEmpty);
    });
  }

  Future<void> refresh({required String? language, bool background = false}) async {
    if (_busy) return;
    final showOverlay = !background || _posts.isEmpty;
    _busy = true;
    if (showOverlay) {
      _refreshing = true;
      _error = null;
      _page = 1;
      _hasMore = true;
      notifyListeners();
    }
    try {
      await _fetch(reset: true, language: language);
    } finally {
      if (showOverlay) _refreshing = false;
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

  static const int _initialPageSize = 12;

  Future<void> _fetch({required bool reset, required String? language}) async {
    final hadPosts = _posts.isNotEmpty;
    try {
      final pageSize = reset ? _initialPageSize : AppConstants.pageSize;
      final res = await ApiService.getFeed(
        page: reset ? 1 : _page,
        limit: pageSize,
        categoryId: null,
        language: language,
        constituency: null,
        politicsScope: null,
        search: null,
        breaking: false,
        days: 30,
        sourceTypes: const ['youtube'],
        hasVideo: true,
        memoryCacheTtl: const Duration(minutes: 2),
      );
      if (res['success'] == true && res['posts'] is List) {
        final raw = res['posts'] as List;
        final rawMaps = <Map<String, dynamic>>[];
        final fetched = <NewsPost>[];
        for (final p in raw) {
          if (p is! Map) continue;
          final map = Map<String, dynamic>.from(p);
          try {
            final post = NewsPost.fromJson(map);
            if (!post.isYoutube) continue;
            final vid = post.youtube?.videoId ?? '';
            if (vid.isEmpty) continue;
            if (!postMatchesLanguage(post, language)) continue;
            fetched.add(post);
            rawMaps.add(map);
          } catch (_) {
            // Skip malformed API rows.
          }
        }
        fetched.sort((a, b) => b.displayTime.compareTo(a.displayTime));
        if (reset) {
          _posts = fetched;
          _page = 2;
          if (rawMaps.isNotEmpty) {
            await ShortsCache.saveRaw(language, rawMaps);
          }
        } else {
          _posts = [..._posts, ...fetched];
          _page++;
        }
        _hasMore = fetched.length >= pageSize;
        _error = null;
        _loadedLanguageTag = _tag(language);
      } else {
        if (reset && !hadPosts) {
          _posts = [];
          _loadedLanguageTag = null;
        }
        final msg = res['message']?.toString().trim();
        _error = (msg != null && msg.isNotEmpty)
            ? msg
            : 'Could not load YouTube videos.';
      }
    } catch (e) {
      if (reset && !hadPosts) {
        _posts = [];
        _loadedLanguageTag = null;
      }
      _error = e.toString();
    }
  }
}
