import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../constants.dart';
import '../utils/feed_dedupe.dart';

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
  String get selectedLanguage =>
      (_selectedLanguage as dynamic) == null ? 'all' : _selectedLanguage;
  String get selectedConstituency => (_selectedConstituency as dynamic) == null
      ? 'all'
      : _selectedConstituency;
  String get selectedPoliticsScope =>
      (_selectedPoliticsScope as dynamic) == null
          ? 'all'
          : _selectedPoliticsScope;
  bool get loading => _loading;
  bool get refreshing => _refreshing;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String? get categoriesError => _categoriesError;
  bool get prefsLoaded => _prefsLoaded;
  bool get languageOnboardingCompleted => _languageOnboardingCompleted;

  static const String _languagePrefKey = 'preferred_feed_language';
  static const String _languageOnboardingKey = 'language_onboarding_completed';
  static const String _onboardingUiLangKey = 'onboarding_ui_language';
  static const String _onboardingInterestsKey = 'onboarding_interests';
  static const String _onboardingCityKey = 'onboarding_city';
  static const String _onboardingNotifKey = 'onboarding_notifications_enabled';

  bool _prefsLoaded = false;
  bool _languageOnboardingCompleted = false;

  /// Optional city label from onboarding; applied as feed `city` filter on **Local** category.
  String? _preferredCity;

  /// Public read-only access to the onboarding-selected city (e.g. for the super home feed).
  String? get preferredCity {
    final c = _preferredCity?.trim();
    if (c == null || c.isEmpty) return null;
    return c;
  }

  /// Maps onboarding picks (Tamil/Kannada/Malayalam) to a feed language the API supports.
  static String feedLanguageFromUiChoice(String uiCode) {
    switch (uiCode.toLowerCase()) {
      case 'ta':
      case 'kn':
      case 'ml':
        return 'all';
      default:
        return uiCode.toLowerCase();
    }
  }

  String _formatError(Object e, {String fallback = 'Request failed.'}) {
    final msg = e.toString().replaceFirst('Exception: ', '').trim();
    if (msg.isEmpty) return fallback;
    return msg;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedLanguage = prefs.getString(_languagePrefKey) ?? 'all';
    _preferredCity = prefs.getString(_onboardingCityKey);

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
    // Prime category IDs for Browse / chips before the first full feed refresh.
    loadCategories();
  }

  /// Insert or replace a category from slug lookups so Browse taps work offline-next.
  void mergeCategory(Category c) {
    if (c.id.isEmpty) return;
    final idx = _categories.indexWhere((x) => x.id == c.id);
    if (idx >= 0) {
      _categories[idx] = c;
    } else {
      _categories.add(c);
      _categories.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
    notifyListeners();
  }

  /// Call after user picks a language on the onboarding screen.
  Future<void> completeLanguageOnboarding(String languageCode) async {
    final feedLang = feedLanguageFromUiChoice(languageCode);
    _selectedLanguage = feedLang;
    _languageOnboardingCompleted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePrefKey, feedLang);
    await prefs.setString(_onboardingUiLangKey, languageCode);
    await prefs.setBool(_languageOnboardingKey, true);
    notifyListeners();
    await refresh();
  }

  /// Persists the full Dailyhunt-style onboarding flow and applies feed language, interests, and city.
  Future<void> completeFullOnboarding({
    required String uiLanguageCode,
    required List<String> interestSlugs,
    required String cityLabel,
    bool notificationsEnabled = false,
  }) async {
    final feedLang = feedLanguageFromUiChoice(uiLanguageCode);
    _selectedLanguage = feedLang;
    _languageOnboardingCompleted = true;
    final trimmedCity = cityLabel.trim();
    _preferredCity = trimmedCity.isEmpty ? null : trimmedCity;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePrefKey, feedLang);
    await prefs.setString(_onboardingUiLangKey, uiLanguageCode);
    await prefs.setBool(_languageOnboardingKey, true);
    await prefs.setStringList(_onboardingInterestsKey, interestSlugs);
    if (_preferredCity != null) {
      await prefs.setString(_onboardingCityKey, _preferredCity!);
    } else {
      await prefs.remove(_onboardingCityKey);
    }
    await prefs.setBool(_onboardingNotifKey, notificationsEnabled);

    notifyListeners();
    await loadCategories();
    await _selectFirstMatchingInterest(interestSlugs);
    await refresh();
  }

  Future<void> _selectFirstMatchingInterest(List<String> slugs) async {
    if (slugs.isEmpty) return;
    for (final slug in slugs) {
      final s = slug.toLowerCase().trim();
      if (s.isEmpty) continue;
      for (final c in _categories) {
        if (c.slug.toLowerCase() == s) {
          _selectedCategoryId = c.id;
          _searchQuery = null;
          if (!isTeluguPoliticsMode) _selectedPoliticsScope = 'all';
          if (!isPoliticsMode) _selectedConstituency = 'all';
          notifyListeners();
          return;
        }
      }
    }
  }

  String? _cityForFeedQuery() {
    final city = _preferredCity?.trim();
    if (city == null || city.isEmpty) return null;
    if (_selectedCategoryId == null) return null;
    for (final c in _categories) {
      if (c.id == _selectedCategoryId && c.slug.toLowerCase() == 'local') {
        return city;
      }
    }
    return null;
  }

  Future<void> loadCategories() async {
    try {
      final data = await ApiService.getCategoriesJson();
      if (data['success'] == true && data['categories'] is List) {
        final list = data['categories'] as List;
        final parsed = <Category>[];
        for (final item in list) {
          if (item is! Map) continue;
          try {
            final c = Category.fromJson(
              Map<String, dynamic>.from(item),
            );
            if (c.id.isNotEmpty && c.slug.isNotEmpty) parsed.add(c);
          } catch (_) {
            // Skip malformed category rows from the API.
          }
        }
        parsed.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        _categories = parsed;
        if (_categories.isEmpty) {
          _categoriesError =
              'No categories returned. On the server run: npm run seed (or check MongoDB).';
        } else {
          _categoriesError = null;
        }
      } else {
        _categories = [];
        final code = data['statusCode'];
        final msg = data['message']?.toString().trim();
        if (code != null &&
            code is int &&
            code >= 500 &&
            (msg == null || msg.isEmpty)) {
          _categoriesError =
              'News server is unavailable ($code). Pull to refresh or try again shortly.';
        } else {
          _categoriesError = (msg != null && msg.isNotEmpty)
              ? msg
              : 'Could not load categories.';
        }
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
    _selectedConstituency =
        constituency.trim().isEmpty ? 'all' : constituency.trim();
    await refresh();
  }

  Future<void> selectPoliticsScope(String scope) async {
    final s = scope.trim().toLowerCase();
    _selectedPoliticsScope =
        ['andhra', 'telangana', 'india', 'international'].contains(s)
            ? s
            : 'all';
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
      if (c.id == _selectedCategoryId)
        return c.slug.toLowerCase() == 'politics';
    }
    return false;
  }

  bool get shouldShowPoliticalScopeDropdown {
    if (!isPoliticsMode) return false;
    return selectedLanguage == 'te' ||
        selectedLanguage == 'hi' ||
        selectedLanguage == 'en';
  }

  List<String> get availablePoliticalConstituencies {
    final set = <String>{};
    for (final p in _posts) {
      final c = (p.constituency ?? '').trim();
      if (c.isEmpty || c.toLowerCase() == 'unknown') continue;
      set.add(c);
    }
    final out = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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
        constituency:
            shouldShowAndhraConstituencyFilter ? selectedConstituency : 'all',
        politicsScope: selectedPoliticsScope,
        city: _cityForFeedQuery(),
        search: _searchQuery,
        // Keep the feed fresh by default (Way2News behavior).
        // Only limit *ingested* news; manual reporter posts remain visible (backend handles this).
        // RSS items in your DB are ~15 days old, so 7 days hides everything.
        // Once NewsAPI ingestion is confirmed working, you can tighten back to 7.
        days: isPoliticsMode ? 7 : 30,
        // Show reporter/manual + NewsAPI. Temporarily also allow RSS since your DB currently contains RSS
        // and NewsAPI is returning apiKeyInvalid (so api feed would be empty otherwise).
        sourceTypes: const ['api', 'manual', 'rss'],
      );
      if (res['success'] == true) {
        final fetched = (res['posts'] as List)
            .map((p) => NewsPost.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList();
        fetched.sort((a, b) => b.displayTime.compareTo(a.displayTime));
        if (reset) {
          _posts = dedupeNewsPosts(fetched);
          _page = 2;
        } else {
          _posts = mergeDedupedPosts(_posts, fetched);
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
