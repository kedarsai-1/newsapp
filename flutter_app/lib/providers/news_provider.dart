import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../constants.dart';

class NewsProvider extends ChangeNotifier {
  List<NewsPost> _posts = [];
  List<Category> _categories = [];
  String? _selectedCategoryId;
  String _selectedLanguage = 'all';
  String _selectedConstituency = 'all';
  String _selectedPoliticsScope = 'all';
  String? _searchQuery;
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  bool _refreshing = false;
  String? _error;
  String? _categoriesError;

  List<NewsPost> get posts => _posts;
  List<Category> get categories => _categories;
  String? get selectedCategoryId => _selectedCategoryId;
  String get selectedLanguage => (_selectedLanguage as dynamic) == null ? 'all' : _selectedLanguage;
  String get selectedConstituency => (_selectedConstituency as dynamic) == null ? 'all' : _selectedConstituency;
  String get selectedPoliticsScope => (_selectedPoliticsScope as dynamic) == null ? 'all' : _selectedPoliticsScope;
  bool get loading => _loading;
  bool get refreshing => _refreshing;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String? get categoriesError => _categoriesError;
  bool get prefsLoaded => _prefsLoaded;
  bool get languageOnboardingCompleted => _languageOnboardingCompleted;

  static const String _languagePrefKey = 'preferred_feed_language';
  static const String _languageOnboardingKey = 'language_onboarding_completed';

  bool _prefsLoaded = false;
  bool _languageOnboardingCompleted = false;

  String _formatError(Object e, {String fallback = 'Request failed.'}) {
    final msg = e.toString().replaceFirst('Exception: ', '').trim();
    if (msg.isEmpty) return fallback;
    return msg;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedLanguage = prefs.getString(_languagePrefKey) ?? 'all';

    final done = prefs.getBool(_languageOnboardingKey);
    if (done != null) {
      _languageOnboardingCompleted = done;
    } else {
      // Existing installs already chose a language via the old feed chips.
      _languageOnboardingCompleted = prefs.containsKey(_languagePrefKey);
      if (_languageOnboardingCompleted) {
        await prefs.setBool(_languageOnboardingKey, true);
      }
    }

    _prefsLoaded = true;
    notifyListeners();
  }

  /// Call after user picks a language on the onboarding screen.
  Future<void> completeLanguageOnboarding(String languageCode) async {
    _selectedLanguage = languageCode;
    _languageOnboardingCompleted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePrefKey, languageCode);
    await prefs.setBool(_languageOnboardingKey, true);
    notifyListeners();
    await refresh();
  }

  Future<void> loadCategories() async {
    try {
      final data = await ApiService.getCategoriesJson();
      if (data['success'] == true && data['categories'] is List) {
        final list = data['categories'] as List;
        final all = list
            .map((c) => Category.fromJson(Map<String, dynamic>.from(c as Map)))
            .toList();
        // Keep only categories we can reliably populate/display right now.
        const allowed = {
          'general',
          'politics',
          'sports',
          'technology',
          'entertainment',
          'business',
          'health',
          'local',
        };
        _categories = all.where((c) => allowed.contains(c.slug.toLowerCase())).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        if (_categories.isEmpty) {
          _categoriesError =
              'No categories in database. On the server run: npm run seed (or redeploy API so defaults are created).';
        } else {
          _categoriesError = null;
        }
      } else {
        _categories = [];
        _categoriesError = data['message']?.toString() ?? 'Could not load categories.';
      }
    } catch (e) {
      _categories = [];
      _categoriesError = _formatError(
        e,
        fallback: 'Could not load categories. Please try again.',
      );
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    _refreshing = true;
    _error = null;
    _page = 1;
    _hasMore = true;
    notifyListeners();
    await loadCategories();
    await _fetchPosts(reset: true);
    _refreshing = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;
    notifyListeners();
    await _fetchPosts(reset: false);
    _loading = false;
    notifyListeners();
  }

  Future<void> selectCategory(String? categoryId) async {
    _selectedCategoryId = categoryId;
    _searchQuery = null;
    if (!isTeluguPoliticsMode) _selectedPoliticsScope = 'all';
    if (!isPoliticsMode) _selectedConstituency = 'all';
    await refresh();
  }

  Future<void> search(String query) async {
    _searchQuery = query.isEmpty ? null : query;
    _selectedCategoryId = null;
    await refresh();
  }

  Future<void> selectLanguage(String languageCode) async {
    _selectedLanguage = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePrefKey, languageCode);
    if (!isTeluguPoliticsMode) _selectedPoliticsScope = 'all';
    if (!isPoliticsMode) _selectedConstituency = 'all';
    await refresh();
  }

  Future<void> selectConstituency(String constituency) async {
    _selectedConstituency = constituency.trim().isEmpty ? 'all' : constituency.trim();
    await refresh();
  }

  Future<void> selectPoliticsScope(String scope) async {
    final s = scope.trim().toLowerCase();
    _selectedPoliticsScope = ['andhra', 'telangana', 'india', 'international'].contains(s) ? s : 'all';
    if (!shouldShowAndhraConstituencyFilter) _selectedConstituency = 'all';
    await refresh();
  }

  bool get isTeluguPoliticsMode {
    if (selectedLanguage != 'te') return false;
    if (_selectedCategoryId == null) return false;
    Category? cat;
    for (final c in _categories) {
      if (c.id == _selectedCategoryId) {
        cat = c;
        break;
      }
    }
    return (cat?.slug.toLowerCase() ?? '') == 'politics';
  }

  bool get isPoliticsMode {
    if (_selectedCategoryId == null) return false;
    for (final c in _categories) {
      if (c.id == _selectedCategoryId) return c.slug.toLowerCase() == 'politics';
    }
    return false;
  }

  bool get shouldShowPoliticalScopeDropdown {
    if (!isPoliticsMode) return false;
    return selectedLanguage == 'te' || selectedLanguage == 'hi' || selectedLanguage == 'en';
  }

  List<String> get availablePoliticalConstituencies {
    final set = <String>{};
    for (final p in _posts) {
      final c = (p.constituency ?? '').trim();
      if (c.isEmpty || c.toLowerCase() == 'unknown') continue;
      set.add(c);
    }
    final out = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  bool get shouldShowAndhraConstituencyFilter {
    return isTeluguPoliticsMode && selectedPoliticsScope == 'andhra';
  }

  Future<void> _fetchPosts({required bool reset}) async {
    try {
      final res = await ApiService.getFeed(
        page: reset ? 1 : _page,
        categoryId: _selectedCategoryId,
        language: selectedLanguage,
        constituency: shouldShowAndhraConstituencyFilter ? selectedConstituency : 'all',
        politicsScope: selectedPoliticsScope,
        search: _searchQuery,
        // Keep the feed fresh by default (Way2News behavior).
        // Only limit *ingested* news; manual reporter posts remain visible (backend handles this).
        // RSS items in your DB are ~15 days old, so 7 days hides everything.
        // Once NewsAPI ingestion is confirmed working, you can tighten back to 7.
        days: 30,
        // Show reporter/manual + NewsAPI. Temporarily also allow RSS since your DB currently contains RSS
        // and NewsAPI is returning apiKeyInvalid (so api feed would be empty otherwise).
        sourceTypes: const ['api', 'manual', 'rss'],
      );
      if (res['success'] == true) {
        final fetched = (res['posts'] as List)
            .map((p) => NewsPost.fromJson(p))
            .toList();
        if (reset) {
          _posts = fetched;
          _page = 2;
        } else {
          _posts.addAll(fetched);
          _page++;
        }
        _hasMore = fetched.length == AppConstants.pageSize;
        _error = null;
      } else {
        _error = (res['message']?.toString().trim().isNotEmpty == true)
            ? res['message'].toString().trim()
            : 'Failed to load news from API.';
      }
    } catch (e) {
      _error = _formatError(
        e,
        fallback: 'Failed to load news. Check your connection.',
      );
    }
  }

  // Update a single post in the list (e.g. after like/bookmark)
  void updatePost(String postId, {int? likes, bool? liked}) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    // Posts are immutable — rebuild with updated values via fromJson
    notifyListeners();
  }
}