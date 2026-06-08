import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../models/sports_models.dart';
import '../services/sports_api_service.dart';
import '../services/sports_cache.dart';
import '../services/sports_news_feed.dart';

class SportsProvider extends ChangeNotifier {
  List<SportsMatch> _live = [];
  List<SportsMatch> _upcoming = [];
  List<SportsMatch> _ipl = [];
  String _iplSectionTitle = 'IPL';
  List<NewsPost> _posts = [];
  SportsLeaderboardSnapshot _leaderboard = const SportsLeaderboardSnapshot();

  bool _loadingLive = false;
  bool _loadingLeaderboard = false;
  bool _loadingNews = false;
  bool _loadingMoreNews = false;
  String? _liveError;
  String? _newsError;
  String _language = 'all';
  int _newsPage = 1;
  int _newsPages = 1;
  bool _polling = false;
  Timer? _pollTimer;

  List<SportsMatch> get live => _live;
  List<SportsMatch> get upcoming => _upcoming;
  List<SportsMatch> get ipl => _ipl;
  String get iplSectionTitle => _iplSectionTitle;
  List<NewsPost> get posts => _posts;
  SportsLeaderboardSnapshot get leaderboard => _leaderboard;
  bool get loadingLive => _loadingLive;
  bool get loadingLeaderboard => _loadingLeaderboard;
  bool get loadingNews => _loadingNews;
  bool get loadingMoreNews => _loadingMoreNews;
  String? get liveError => _liveError;
  String? get newsError => _newsError;
  bool get hasMoreNews => _newsPage < _newsPages;
  String get language => _language;

  void setLanguage(String code) {
    final next = code.trim().toLowerCase();
    if (next == _language) return;
    _language = next.isEmpty ? 'all' : next;
    refreshNews(reset: true);
  }

  void startLivePolling() {
    if (_polling) return;
    _polling = true;
    refreshLive(silent: _live.isNotEmpty);
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      refreshLive(silent: true);
    });
  }

  void stopLivePolling() {
    _polling = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> bootstrap({String language = 'all'}) async {
    _language = language;
    final cached = await SportsCache.loadLive();
    if (cached != null) {
      _applyLivePayload(cached);
      notifyListeners();
    }
    await Future.wait([
      refreshLive(silent: _live.isNotEmpty),
      refreshLeaderboard(),
      refreshNews(reset: true),
    ]);
  }

  Future<void> refreshAll() async {
    await Future.wait([
      refreshLive(),
      refreshLeaderboard(),
      refreshNews(reset: true),
    ]);
  }

  Future<void> refreshLeaderboard() async {
    _loadingLeaderboard = true;
    notifyListeners();
    final res = await SportsApiService.getLeaderboard();
    if (res['success'] == true) {
      final top = (res['leaderboard'] is List ? res['leaderboard'] as List : [])
          .whereType<Map>()
          .map((e) => SportsLeaderboardEntry.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList();
      SportsLeaderboardEntry? me;
      if (res['currentUser'] is Map) {
        me = SportsLeaderboardEntry.fromJson(
          Map<String, dynamic>.from(res['currentUser'] as Map),
        );
      }
      _leaderboard = SportsLeaderboardSnapshot(top: top, currentUser: me);
    }
    _loadingLeaderboard = false;
    notifyListeners();
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
      final warning = res['warning']?.toString();
      final apiMessage = res['message']?.toString();
      final empty = _live.isEmpty && _upcoming.isEmpty && _ipl.isEmpty;
      if (warning != null && warning.isNotEmpty) {
        _liveError = warning;
      } else if (empty && apiMessage != null && apiMessage.isNotEmpty) {
        _liveError = apiMessage;
      } else {
        _liveError = null;
      }
    } else if (res['code'] == SportsApiService.codeSportsApiMissing) {
      _live = [];
      _upcoming = [];
      _ipl = [];
      _liveError =
          'Live scores need a backend redeploy on Railway (add CRICAPI_KEY in Railway variables, then redeploy).';
    } else {
      _liveError = res['message']?.toString() ?? 'Could not load live scores.';
    }
    _loadingLive = false;
    notifyListeners();
  }

  void _applyLivePayload(Map<String, dynamic> res) {
    _live = _parseMatches(res['live']);
    _upcoming = _parseMatches(res['upcoming']);
    _ipl = _parseMatches(res['ipl']);
    final title = res['iplSectionTitle']?.toString().trim();
    if (title != null && title.isNotEmpty) _iplSectionTitle = title;
  }

  List<SportsMatch> _parseMatches(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => SportsMatch.fromJson(Map<String, dynamic>.from(e)))
        .where((m) => m.id.isNotEmpty)
        .toList();
  }

  Future<void> refreshNews({bool reset = false}) async {
    if (reset) {
      _newsPage = 1;
      _newsPages = 1;
      _posts = [];
    }
    _loadingNews = reset;
    _newsError = null;
    notifyListeners();

    final lang = _language == 'all' ? null : _language;
    final res = await SportsNewsFeed.fetchPostsPage(
      page: _newsPage,
      language: lang,
    );

    if (res['success'] == true && res['posts'] is List) {
      final items = List<NewsPost>.from(res['posts'] as List);
      if (reset) {
        _posts = items;
      } else {
        _posts = [..._posts, ...items];
      }
      _newsPages = int.tryParse('${res['pages']}') ?? 1;
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

    final lang = _language == 'all' ? null : _language;
    final res = await SportsNewsFeed.fetchPostsPage(
      page: _newsPage,
      language: lang,
    );

    if (res['success'] == true && res['posts'] is List) {
      final items = List<NewsPost>.from(res['posts'] as List);
      _posts = [..._posts, ...items];
      _newsPages = int.tryParse('${res['pages']}') ?? _newsPage;
    } else {
      _newsPage -= 1;
    }
    _loadingMoreNews = false;
    notifyListeners();
  }

  Future<({SportsMatch? match, SportsMatchPoll? poll})> fetchMatchDetail(
    String id,
  ) async {
    final res = await SportsApiService.getMatch(id);
    if (res['success'] != true) {
      return (match: null, poll: null);
    }
    SportsMatch? match;
    if (res['match'] is Map) {
      match = SportsMatch.fromJson(
        Map<String, dynamic>.from(res['match'] as Map),
      );
    }
    SportsMatchPoll? poll;
    if (res['poll'] is Map) {
      poll = SportsMatchPoll.fromJson(
        Map<String, dynamic>.from(res['poll'] as Map),
      );
    }
    return (match: match, poll: poll);
  }

  Future<String?> voteMatchPoll(String matchId, String option) async {
    final res = await SportsApiService.voteMatchPoll(matchId, option);
    if (res['success'] == true) return null;
    return res['message']?.toString() ?? 'Could not cast vote.';
  }

  @override
  void dispose() {
    stopLivePolling();
    super.dispose();
  }
}
