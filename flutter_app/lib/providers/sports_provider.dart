import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/sports_models.dart';
import '../services/sports_api_service.dart';
import '../services/sports_cache.dart';

class SportsProvider extends ChangeNotifier {
  List<SportsMatch> _live = [];
  List<SportsMatch> _upcoming = [];
  List<SportsNewsItem> _news = [];
  List<SportsHighlight> _highlights = [];

  bool _loadingLive = false;
  bool _loadingNews = false;
  bool _loadingMoreNews = false;
  String? _liveError;
  String? _newsError;
  int _newsPage = 1;
  int _newsPages = 1;
  bool _polling = false;
  Timer? _pollTimer;

  List<SportsMatch> get live => _live;
  List<SportsMatch> get upcoming => _upcoming;
  List<SportsNewsItem> get news => _news;
  List<SportsHighlight> get highlights => _highlights;
  bool get loadingLive => _loadingLive;
  bool get loadingNews => _loadingNews;
  bool get loadingMoreNews => _loadingMoreNews;
  String? get liveError => _liveError;
  String? get newsError => _newsError;
  bool get hasMoreNews => _newsPage < _newsPages;

  void startLivePolling() {
    if (_polling) return;
    _polling = true;
    refreshLive(silent: _live.isNotEmpty);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refreshLive(silent: true);
    });
  }

  void stopLivePolling() {
    _polling = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> bootstrap() async {
    final cached = await SportsCache.loadLive();
    if (cached != null) {
      _applyLivePayload(cached);
      notifyListeners();
    }
    await Future.wait([
      refreshLive(silent: _live.isNotEmpty),
      refreshNews(reset: true),
      refreshHighlights(),
    ]);
  }

  Future<void> refreshAll() async {
    await Future.wait([
      refreshLive(),
      refreshNews(reset: true),
      refreshHighlights(),
    ]);
  }

  Future<void> refreshLive({bool silent = false}) async {
    if (!silent) {
      _loadingLive = true;
      _liveError = null;
      notifyListeners();
    }
    final res = await SportsApiService.getLive();
    if (res['success'] == true) {
      _applyLivePayload(res);
      await SportsCache.saveLive(res);
      _liveError = res['message']?.toString();
    } else {
      _liveError = res['message']?.toString() ?? 'Could not load live scores.';
    }
    _loadingLive = false;
    notifyListeners();
  }

  void _applyLivePayload(Map<String, dynamic> res) {
    _live = _parseMatches(res['live']);
    _upcoming = _parseMatches(res['upcoming']);
  }

  List<SportsMatch> _parseMatches(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => SportsMatch.fromJson(Map<String, dynamic>.from(e)))
        .where((m) => m.id.isNotEmpty)
        .toList();
  }

  Future<void> refreshHighlights() async {
    final res = await SportsApiService.getHighlights();
    if (res['success'] == true && res['highlights'] is List) {
      _highlights = (res['highlights'] as List)
          .whereType<Map>()
          .map((e) => SportsHighlight.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
    }
  }

  Future<void> refreshNews({bool reset = false}) async {
    if (reset) {
      _newsPage = 1;
      _newsPages = 1;
      _news = [];
    }
    _loadingNews = reset;
    _newsError = null;
    notifyListeners();

    final res = await SportsApiService.getNews(page: _newsPage);
    if (res['success'] == true && res['news'] is List) {
      final items = (res['news'] as List)
          .whereType<Map>()
          .map((e) => SportsNewsItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (reset) {
        _news = items;
      } else {
        _news = [..._news, ...items];
      }
      _newsPages = int.tryParse('${res['pages']}') ?? 1;
      await SportsCache.saveNewsPage(_newsPage, res);
    } else {
      _newsError = res['message']?.toString() ?? 'Could not load sports news.';
    }
    _loadingNews = false;
    _loadingMoreNews = false;
    notifyListeners();
  }

  Future<void> loadMoreNews() async {
    if (_loadingMoreNews || !hasMoreNews) return;
    _loadingMoreNews = true;
    _newsPage += 1;
    notifyListeners();
    final res = await SportsApiService.getNews(page: _newsPage);
    if (res['success'] == true && res['news'] is List) {
      final items = (res['news'] as List)
          .whereType<Map>()
          .map((e) => SportsNewsItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _news = [..._news, ...items];
      _newsPages = int.tryParse('${res['pages']}') ?? _newsPage;
    } else {
      _newsPage -= 1;
    }
    _loadingMoreNews = false;
    notifyListeners();
  }

  Future<SportsMatch?> fetchMatchDetail(String id) async {
    final res = await SportsApiService.getMatch(id);
    if (res['success'] == true && res['match'] is Map) {
      return SportsMatch.fromJson(
        Map<String, dynamic>.from(res['match'] as Map),
      );
    }
    return null;
  }

  @override
  void dispose() {
    stopLivePolling();
    super.dispose();
  }
}
