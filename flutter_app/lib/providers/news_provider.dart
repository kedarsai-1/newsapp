import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../models/saved_local_place.dart';
import '../services/api_service.dart';
import '../services/publisher_follow_service.dart';
import '../services/socket_service.dart';
import '../services/push_notifications.dart';
import '../constants.dart';
import '../utils/feed_dedupe.dart';
import '../utils/feed_language.dart';
import '../utils/api_memory_cache.dart';

enum AppLayoutMode {
  dualDeck,
  carouselWheel,
  sidebarPanel,
}

/// Hindi Local/Politics regional scopes — keep in sync with server `hindiRegionalScopes.js`.
const _hindiRegionalScopes = <String>[
  'up',
  'bihar',
  'rajasthan',
  'punjab',
  'haryana',
  'delhi',
];

const _hindiPoliticsScopeAllowlist = <String>{
  'all',
  'india',
  'international',
  'north',
  ..._hindiRegionalScopes,
};

const _hindiLocalScopeAllowlist = <String>{
  'all',
  ..._hindiRegionalScopes,
};

class NewsProvider extends ChangeNotifier {
  List<NewsPost> _posts = [];
  List<NewsPost> _breakingPosts = [];
  List<NewsPost> _breakingHighlightPosts = [];
  List<NewsPost> _trendingPosts = [];
  List<Category> _categories = [];
  String? _selectedCategoryId;
  bool _followingFeedOnly = false;
  String _selectedLanguage = 'all';
  String _selectedConstituency = 'all';
  String _selectedPoliticsScope = 'all';
  String _selectedLocalScope = 'all';
  String? _searchQuery;
  List<NewsPost> _searchResults = [];
  bool _searchLoading = false;
  String? _searchError;
  int _searchRequestId = 0;
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;
  bool _breakingLoading = false;
  bool _refreshing = false;
  String? _error;
  String? _breakingError;
  String? _categoriesError;

  AppLayoutMode _layoutMode = AppLayoutMode.sidebarPanel;
  AppLayoutMode get layoutMode => _layoutMode;
  static const String _layoutModePrefKey = 'app_layout_mode_v1';

  List<NewsPost> get posts => _posts;
  List<NewsPost> get breakingPosts => _breakingPosts;
  List<NewsPost> get breakingHighlightPosts => _breakingHighlightPosts;
  List<NewsPost> get trendingPosts => _trendingPosts;
  List<NewsPost> get searchResults => _searchResults;
  bool get searchLoading => _searchLoading;
  String? get searchError => _searchError;
  List<Category> get categories => _categories;
  String? get selectedCategoryId => _selectedCategoryId;
  bool get followingFeedOnly => _followingFeedOnly;

  /// Slug for the selected tab (`null` = Top News / all categories).
  String? get selectedCategorySlug {
    if (_selectedCategoryId == null) return null;
    for (final c in _categories) {
      if (c.id == _selectedCategoryId) return c.slug.toLowerCase();
    }
    return null;
  }
  String get selectedLanguage =>
      (_selectedLanguage as dynamic) == null ? 'all' : _selectedLanguage;

  /// API `language` for Shorts — feed chip, or onboarding default before any feed language was saved.
  String? get shortsFeedLanguage {
    if (!_prefsLoaded) return null;
    final sel = selectedLanguage;
    if (sel != 'all') return sel;
    if (_hasStoredFeedLanguagePreference) return null;
    final ui = _onboardingUiLanguage?.trim().toLowerCase();
    if (ui == null || ui.isEmpty) return null;
    final mapped = feedLanguageFromUiChoice(ui);
    return mapped == 'all' ? null : mapped;
  }

  /// Shorts language chips: explicit feed filter, else onboarding default, else All.
  String get shortsLanguageBarCode => shortsFeedLanguage ?? 'all';
  String get selectedConstituency => (_selectedConstituency as dynamic) == null
      ? 'all'
      : _selectedConstituency;
  String get selectedPoliticsScope =>
      (_selectedPoliticsScope as dynamic) == null
          ? 'all'
          : _selectedPoliticsScope;

  String get selectedLocalScope =>
      (_selectedLocalScope as dynamic) == null ? 'all' : _selectedLocalScope;
  bool get loading => _loadingMore;
  bool get breakingLoading => _breakingLoading;
  bool get refreshing => _refreshing;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String? get breakingError => _breakingError;
  String? get categoriesError => _categoriesError;
  bool get prefsLoaded => _prefsLoaded;
  bool get languageOnboardingCompleted => _languageOnboardingCompleted;

  static const String _languagePrefKey = 'preferred_feed_language';
  static const String _languageOnboardingKey = 'language_onboarding_completed';
  static const String _onboardingUiLangKey = 'onboarding_ui_language';
  static const String _onboardingInterestsKey = 'onboarding_interests';
  static const String _onboardingCityKey = 'onboarding_city';
  static const String _onboardingLatKey = 'onboarding_lat';
  static const String _onboardingLngKey = 'onboarding_lng';
  static const String _onboardingNotifKey = 'onboarding_notifications_enabled';
  static const String _savedLocation0Key = 'saved_location_0_json';
  static const String _savedLocation1Key = 'saved_location_1_json';
  static const String _activeLocationSlotKey = 'active_location_slot';
  static const String _seenPostsKey = 'seen_post_ids_v1';

  bool _prefsLoaded = false;
  bool _languageOnboardingCompleted = false;
  bool _hasStoredFeedLanguagePreference = false;
  final Set<String> _seenPostIds = {};

  /// Raw onboarding pick (en/te/hi/ta/…) — used when feed filter is "all".
  String? _onboardingUiLanguage;

  /// Optional city label from onboarding; applied as feed `city` filter on **Local** category.
  String? _preferredCity;

  double? _preferredLat;
  double? _preferredLng;
  String? _preferredDistrict;
  String? _preferredMandal;
  String? _preferredState;

  SavedLocalPlace? _savedLocation0;
  SavedLocalPlace? _savedLocation1;
  int _activeLocationSlot = 0;

  static const int maxSavedLocations = 2;

  /// Public read-only access to the onboarding-selected city (e.g. for the super home feed).
  String? get preferredCity {
    final c = _preferredCity?.trim();
    if (c == null || c.isEmpty) return null;
    return c;
  }

  double? get preferredLat => _preferredLat;
  double? get preferredLng => _preferredLng;
  String? get preferredDistrict => _preferredDistrict;
  String? get preferredMandal => _preferredMandal;
  int get activeLocationSlot => _activeLocationSlot;

  SavedLocalPlace? savedLocationAt(int slot) =>
      slot == 0 ? _savedLocation0 : slot == 1 ? _savedLocation1 : null;

  List<SavedLocalPlace?> get savedLocations => [_savedLocation0, _savedLocation1];

  SavedLocalPlace? get activeSavedLocation => savedLocationAt(_activeLocationSlot);

  /// Maps onboarding picks (Tamil/Kannada/Malayalam/Bengali) to a feed language the API supports.
  static String feedLanguageFromUiChoice(String uiCode) {
    final normalized = uiCode.trim().toLowerCase();
    if (normalized.isEmpty) return 'all';
    return normalized;
  }

  void _applyActiveSavedLocation({bool notify = true}) {
    final active = activeSavedLocation;
    if (active != null && !active.isEmpty) {
      _preferredCity = active.city?.trim().isNotEmpty == true ? active.city!.trim() : _preferredCity;
      _preferredDistrict = active.district?.trim().isNotEmpty == true ? active.district!.trim() : null;
      _preferredMandal = active.mandal?.trim().isNotEmpty == true ? active.mandal!.trim() : null;
      _preferredState = active.state?.trim().isNotEmpty == true ? active.state!.trim() : null;
      if (active.latitude != null && active.longitude != null) {
        _preferredLat = active.latitude;
        _preferredLng = active.longitude;
      }
    } else {
      _clearActiveLocationFilters();
    }
    if (notify) notifyListeners();
  }

  void _clearActiveLocationFilters() {
    final sibling = _activeLocationSlot == 0 ? _savedLocation1 : _savedLocation0;
    if (sibling != null && !sibling.isEmpty) {
      _preferredCity = sibling.city?.trim().isNotEmpty == true ? sibling.city!.trim() : null;
      _preferredDistrict = sibling.district?.trim().isNotEmpty == true ? sibling.district!.trim() : null;
      _preferredMandal = sibling.mandal?.trim().isNotEmpty == true ? sibling.mandal!.trim() : null;
      _preferredState = sibling.state?.trim().isNotEmpty == true ? sibling.state!.trim() : null;
      _preferredLat = sibling.latitude;
      _preferredLng = sibling.longitude;
      return;
    }
    _preferredDistrict = null;
    _preferredMandal = null;
    _preferredState = null;
    _preferredLat = null;
    _preferredLng = null;
  }

  Future<void> selectActiveLocationSlot(int slot) async {
    if (slot < 0 || slot >= maxSavedLocations) return;
    final place = savedLocationAt(slot);
    if (place == null || place.isEmpty) {
      return;
    }
    if (_activeLocationSlot == slot) return;
    _activeLocationSlot = slot;
    _applyActiveSavedLocation(notify: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_activeLocationSlotKey, slot);
    notifyListeners();
    if (isLocalMode) await refresh();
  }

  Future<void> saveLocationSlot(int slot, SavedLocalPlace place) async {
    if (slot < 0 || slot >= maxSavedLocations) return;
    if (slot == 0) {
      _savedLocation0 = place;
    } else {
      _savedLocation1 = place;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      slot == 0 ? _savedLocation0Key : _savedLocation1Key,
      SavedLocalPlace.encode(place),
    );
    if (slot == _activeLocationSlot) {
      _applyActiveSavedLocation(notify: false);
    }
    notifyListeners();
    try {
      await ApiService.upsertSavedLocation(slot: slot, place: place);
    } catch (_) {
      // Guest / offline — local prefs are enough.
    }
    if (isLocalMode && slot == _activeLocationSlot) await refresh();
  }

  Future<void> clearLocationSlot(int slot) async {
    if (slot < 0 || slot >= maxSavedLocations) return;
    if (slot == 0) {
      _savedLocation0 = null;
    } else {
      _savedLocation1 = null;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(slot == 0 ? _savedLocation0Key : _savedLocation1Key);
    if (_activeLocationSlot == slot) {
      _applyActiveSavedLocation(notify: false);
    }
    notifyListeners();
    try {
      await ApiService.deleteSavedLocation(slot: slot);
    } catch (_) {
      // Guest / offline — local prefs are enough.
    }
    if (isLocalMode && _activeLocationSlot == slot) await refresh();
  }

  String? _mandalForLocalQuery() {
    final mandal = _preferredMandal?.trim();
    if (mandal == null || mandal.isEmpty) return null;
    return mandal;
  }

  String? _stateForLocalQuery() {
    final state = _preferredState?.trim();
    if (state == null || state.isEmpty) return null;
    return state;
  }

  String _formatError(Object e, {String fallback = 'Request failed.'}) {
    final msg = e.toString().replaceFirst('Exception: ', '').trim();
    if (msg.isEmpty) return fallback;
    return msg;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _hasStoredFeedLanguagePreference = prefs.containsKey(_languagePrefKey);
    _selectedLanguage = prefs.getString(_languagePrefKey) ?? 'all';
    _onboardingUiLanguage = prefs.getString(_onboardingUiLangKey);
    _preferredCity = prefs.getString(_onboardingCityKey);
    _preferredLat = prefs.containsKey(_onboardingLatKey)
        ? prefs.getDouble(_onboardingLatKey)
        : null;
    _preferredLng = prefs.containsKey(_onboardingLngKey)
        ? prefs.getDouble(_onboardingLngKey)
        : null;
    _savedLocation0 = SavedLocalPlace.decode(prefs.getString(_savedLocation0Key));
    _savedLocation1 = SavedLocalPlace.decode(prefs.getString(_savedLocation1Key));
    _activeLocationSlot = prefs.getInt(_activeLocationSlotKey) ?? 0;
    if (_activeLocationSlot < 0 || _activeLocationSlot >= maxSavedLocations) {
      _activeLocationSlot = 0;
    }
    _applyActiveSavedLocation(notify: false);

    // Sync saved locations from server if logged in
    if (ApiService.isAuthenticated) {
      _syncLocationsFromServer();
    }
    _seenPostIds
      ..clear()
      ..addAll(prefs.getStringList(_seenPostsKey) ?? const []);

    final layoutStr = prefs.getString(_layoutModePrefKey);
    if (layoutStr != null) {
      _layoutMode = AppLayoutMode.values.firstWhere(
        (e) => e.name == layoutStr,
        orElse: () => AppLayoutMode.sidebarPanel,
      );
    }
    if (_layoutMode == AppLayoutMode.dualDeck) {
      _layoutMode = AppLayoutMode.carouselWheel;
      await prefs.setString(_layoutModePrefKey, _layoutMode.name);
    }

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
    _wireRealtimeFeedRefresh();
  }

  Future<void> setLayoutMode(AppLayoutMode mode) async {
    _layoutMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_layoutModePrefKey, mode.name);
    notifyListeners();
  }

  /// Mobile: refresh when server cron inserts stories. Web polls on FeedScreen timer.
  void _wireRealtimeFeedRefresh() {
    if (kIsWeb) return;
    SocketService.connect();
    SocketService.onFeedUpdated((_) {
      ApiMemoryCache.invalidatePrefix('/news/feed');
      ApiMemoryCache.invalidatePrefix('/categories');
      if (_refreshing || _loadingMore) return;
      refresh();
    });
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
    _onboardingUiLanguage = languageCode;
    _hasStoredFeedLanguagePreference = true;
    _languageOnboardingCompleted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePrefKey, feedLang);
    await prefs.setString(_onboardingUiLangKey, languageCode);
    await prefs.setBool(_languageOnboardingKey, true);
    notifyListeners();
    await refresh();
  }

  /// Clears onboarding completion so the Dailyhunt flow can run again.
  Future<void> resetOnboarding() async {
    _languageOnboardingCompleted = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_languageOnboardingKey, false);
    notifyListeners();
  }

  /// Persists the full Dailyhunt-style onboarding flow and applies feed language, interests, and city.
  Future<void> completeFullOnboarding({
    required String uiLanguageCode,
    required List<String> interestSlugs,
    required String cityLabel,
    double? latitude,
    double? longitude,
    bool notificationsEnabled = false,
  }) async {
    final feedLang = feedLanguageFromUiChoice(uiLanguageCode);
    _selectedLanguage = feedLang;
    _onboardingUiLanguage = uiLanguageCode;
    _hasStoredFeedLanguagePreference = true;
    _languageOnboardingCompleted = true;
    final trimmedCity = cityLabel.trim();
    _preferredCity = trimmedCity.isEmpty ? null : trimmedCity;
    _preferredLat = latitude;
    _preferredLng = longitude;

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
    if (_preferredLat != null && _preferredLng != null) {
      await prefs.setDouble(_onboardingLatKey, _preferredLat!);
      await prefs.setDouble(_onboardingLngKey, _preferredLng!);
    } else if (_preferredCity != null) {
      try {
        final geo = await ApiService.forwardGeocode(city: _preferredCity!);
        if (geo['success'] == true && geo['location'] is Map) {
          final loc = Map<String, dynamic>.from(geo['location'] as Map);
          final lat = (loc['latitude'] as num?)?.toDouble();
          final lng = (loc['longitude'] as num?)?.toDouble();
          if (lat != null && lng != null) {
            _preferredLat = lat;
            _preferredLng = lng;
            await prefs.setDouble(_onboardingLatKey, lat);
            await prefs.setDouble(_onboardingLngKey, lng);
          }
        }
      } catch (_) {
        // City-only local filter still works without coordinates.
      }
    } else {
      await prefs.remove(_onboardingLatKey);
      await prefs.remove(_onboardingLngKey);
    }

    if (trimmedCity.isNotEmpty) {
      await saveLocationSlot(
        0,
        SavedLocalPlace(
          label: 'Home',
          city: trimmedCity,
          latitude: _preferredLat,
          longitude: _preferredLng,
        ),
      );
      _activeLocationSlot = 0;
      await prefs.setInt(_activeLocationSlotKey, 0);
    }

    await prefs.setBool(_onboardingNotifKey, notificationsEnabled);
    if (notificationsEnabled) {
      await PushNotifications.syncInterestTopics(interestSlugs);
    }

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
          if (!isPoliticsMode) _selectedPoliticsScope = 'all';
          if (!isLocalMode) _selectedLocalScope = 'all';
          if (!shouldShowAndhraConstituencyFilter) _selectedConstituency = 'all';
          notifyListeners();
          return;
        }
      }
    }
  }

  String? _cityForFeedQuery() {
    if (!isLocalMode) return null;
    final city = _preferredCity?.trim();
    if (city == null || city.isEmpty) return null;
    return city;
  }

  String? _districtForLocalQuery() {
    final fromSaved = _preferredDistrict?.trim();
    if (fromSaved != null && fromSaved.isNotEmpty) return fromSaved;
    final city = _preferredCity?.trim();
    if (city == null || city.isEmpty) return null;
    const cityToDistrict = {
      'Hyderabad': 'Hyderabad',
      'Secunderabad': 'Hyderabad',
      'Visakhapatnam': 'Visakhapatnam',
      'Vizag': 'Visakhapatnam',
      'Vijayawada': 'NTR',
      'Guntur': 'Guntur',
      'Chilakaluripeta': 'Palnadu',
      'Narasaraopet': 'Palnadu',
      'Tirupati': 'Tirupati',
      'Nellore': 'Nellore',
      'Kurnool': 'Kurnool',
      'Kadapa': 'YSR Kadapa',
      'Anantapur': 'Anantapur',
      'Rajahmundry': 'East Godavari',
      'Kakinada': 'Kakinada',
      'Warangal': 'Warangal',
      'Karimnagar': 'Karimnagar',
      'Nizamabad': 'Nizamabad',
      'Khammam': 'Khammam',
      'Nalgonda': 'Nalgonda',
      'Mahbubnagar': 'Mahbubnagar',
      'Lucknow': 'Lucknow',
      'Patna': 'Patna',
      'Jaipur': 'Jaipur',
      'Chandigarh': 'Chandigarh',
      'Delhi': 'Delhi',
      'Kanpur': 'Kanpur',
      'Varanasi': 'Varanasi',
      'Prayagraj': 'Prayagraj',
      'Agra': 'Agra',
      'Meerut': 'Meerut',
      'Noida': 'Noida',
      'Ghaziabad': 'Ghaziabad',
      'Gorakhpur': 'Gorakhpur',
      'Gaya': 'Gaya',
      'Muzaffarpur': 'Muzaffarpur',
      'Jodhpur': 'Jodhpur',
      'Udaipur': 'Udaipur',
      'Kota': 'Kota',
      'Amritsar': 'Amritsar',
      'Ludhiana': 'Ludhiana',
      'Jalandhar': 'Jalandhar',
      'Gurugram': 'Gurugram',
      'Gurgaon': 'Gurugram',
      'Faridabad': 'Faridabad',
      'Panipat': 'Panipat',
    };
    return cityToDistrict[city] ?? city;
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
    await loadFeedHighlights();
    _refreshing = false;
    notifyListeners();
  }

  /// Background poll — skips category refetch when list is already loaded (DEF-005).
  Future<void> refreshPostsOnly() async {
    _refreshing = true;
    _error = null;
    _page = 1;
    _hasMore = true;
    notifyListeners();
    await _fetchPosts(reset: true);
    await loadFeedHighlights();
    _refreshing = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_loadingMore || _refreshing || !_hasMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      await _fetchPosts(reset: false);
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  void _resetPoliticsScopeForLanguage(String languageCode) {
    final lang = languageCode.toLowerCase();
    if (lang == 'te') {
      if (!['andhra', 'telangana', 'india', 'international', 'all']
          .contains(_selectedPoliticsScope)) {
        _selectedPoliticsScope = 'all';
      }
    } else if (lang == 'hi') {
      if (!_hindiPoliticsScopeAllowlist.contains(_selectedPoliticsScope)) {
        _selectedPoliticsScope = 'all';
      }
    } else if (lang == 'en') {
      if (!['india', 'international', 'all'].contains(_selectedPoliticsScope)) {
        _selectedPoliticsScope = 'all';
      }
    } else {
      _selectedPoliticsScope = 'all';
    }
    if (lang == 'te') {
      if (!['andhra', 'telangana', 'all'].contains(_selectedLocalScope)) {
        _selectedLocalScope = 'all';
      }
    } else if (lang == 'hi') {
      if (!_hindiLocalScopeAllowlist.contains(_selectedLocalScope)) {
        _selectedLocalScope = 'all';
      }
    } else {
      _selectedLocalScope = 'all';
    }
  }

  void _clearSearchState() {
    _searchRequestId += 1;
    _searchQuery = null;
    _searchResults = [];
    _searchLoading = false;
    _searchError = null;
  }

  /// Clears search overlay results without reloading the main feed.
  void endSearch() {
    if (_searchQuery == null &&
        _searchResults.isEmpty &&
        !_searchLoading &&
        _searchError == null) {
      return;
    }
    _clearSearchState();
    notifyListeners();
  }

  /// Sync saved locations from server when logged in.
  Future<void> _syncLocationsFromServer() async {
    try {
      final res = await ApiService.getSavedLocations();
      if (res['success'] != true) return;

      final locations = res['locations'] as List? ?? [];
      final prefs = await SharedPreferences.getInstance();

      // Merge server locations with local ones
      for (final loc in locations) {
        if (loc is! Map) continue;
        final slot = loc['slot'] as int?;
        if (slot == null || slot < 0 || slot >= maxSavedLocations) continue;

        final placeData = loc['place'];
        if (placeData is! Map) continue;

        try {
          final place = SavedLocalPlace.fromJson(Map<String, dynamic>.from(placeData));
          if (slot == 0) {
            _savedLocation0 = place;
            await prefs.setString(_savedLocation0Key, SavedLocalPlace.encode(place));
          } else {
            _savedLocation1 = place;
            await prefs.setString(_savedLocation1Key, SavedLocalPlace.encode(place));
          }
        } catch (_) {
          // Skip invalid location data
        }
      }

      _applyActiveSavedLocation(notify: false);
      notifyListeners();
    } catch (_) {
      // Silently fail - local locations are still available
    }
  }

  Future<void> selectCategory(String? categoryId) async {
    _selectedCategoryId = categoryId;
    _followingFeedOnly = false;
    _clearSearchState();
    _selectedPoliticsScope = 'all';
    _selectedLocalScope = 'all';
    if (isPoliticsMode || isLocalMode) {
      _resetPoliticsScopeForLanguage(selectedLanguage);
    }
    if (!shouldShowAndhraConstituencyFilter) _selectedConstituency = 'all';
    _posts = [];
    _refreshing = true;
    _error = null;
    notifyListeners();
    await refresh();
  }

  Future<void> selectFollowingFeed() async {
    _selectedCategoryId = null;
    _followingFeedOnly = true;
    _clearSearchState();
    _selectedPoliticsScope = 'all';
    _selectedLocalScope = 'all';
    _posts = [];
    _refreshing = true;
    _error = null;
    notifyListeners();
    await refresh();
  }

  Future<void> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      endSearch();
      return;
    }
    _searchQuery = q;
    final requestId = ++_searchRequestId;
    _searchLoading = true;
    _searchError = null;
    notifyListeners();
    try {
      final res = await ApiService.getFeed(
        page: 1,
        categoryId: _selectedCategoryId,
        language: selectedLanguage,
        constituency:
            shouldShowAndhraConstituencyFilter ? selectedConstituency : 'all',
        politicsScope: regionScopeForApi,
        city: _cityForFeedQuery(),
        search: q,
        days: 30,
        sourceTypes: const ['api', 'manual', 'rss', 'html', 'youtube'],
      );
      if (requestId != _searchRequestId) return;
      if (res['success'] == true) {
        var fetched = (res['posts'] as List)
            .map((p) => NewsPost.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList();
        if (selectedLanguage != 'all') {
          fetched = fetched
              .where((p) => postMatchesFeedLanguage(p, selectedLanguage))
              .toList();
        }
        fetched.sort((a, b) => b.displayTime.compareTo(a.displayTime));
        _searchResults = dedupeNewsPosts(fetched);
        _searchError = null;
      } else {
        _searchResults = [];
        _searchError = (res['message']?.toString().trim().isNotEmpty == true)
            ? res['message'].toString().trim()
            : 'Search failed.';
      }
    } catch (e) {
      if (requestId != _searchRequestId) return;
      _searchResults = [];
      _searchError = _formatError(
        e,
        fallback: 'Search failed. Check your connection.',
      );
    }
    if (requestId != _searchRequestId) return;
    _searchLoading = false;
    notifyListeners();
  }

  Future<void> selectLanguage(String languageCode) async {
    _selectedLanguage = languageCode;
    _hasStoredFeedLanguagePreference = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePrefKey, languageCode);
    if (['en', 'te', 'hi', 'ta', 'kn', 'bn', 'ml'].contains(languageCode)) {
      _onboardingUiLanguage = languageCode;
      await prefs.setString(_onboardingUiLangKey, languageCode);
    }
    _resetPoliticsScopeForLanguage(languageCode);
    if (!isPoliticsMode) _selectedConstituency = 'all';
    notifyListeners();
    await refresh();
  }

  Future<void> selectConstituency(String constituency) async {
    _selectedConstituency =
        constituency.trim().isEmpty ? 'all' : constituency.trim();
    await refresh();
  }

  Future<void> selectPoliticsScope(String scope) async {
    final s = scope.trim().toLowerCase();
    final allowed = selectedLanguage == 'te'
        ? ['andhra', 'telangana', 'india', 'international', 'all']
        : selectedLanguage == 'hi'
            ? _hindiPoliticsScopeAllowlist.toList()
            : ['india', 'international', 'all'];
    _selectedPoliticsScope = allowed.contains(s) ? s : 'all';
    _posts = [];
    _refreshing = true;
    _error = null;
    notifyListeners();
    await refresh();
  }

  Future<void> selectLocalScope(String scope) async {
    final s = scope.trim().toLowerCase();
    final allowed = selectedLanguage == 'hi'
        ? _hindiLocalScopeAllowlist.toList()
        : ['andhra', 'telangana', 'all'];
    _selectedLocalScope = allowed.contains(s) ? s : 'all';
    if (!shouldShowAndhraConstituencyFilter) _selectedConstituency = 'all';
    _posts = [];
    _refreshing = true;
    _error = null;
    notifyListeners();
    await refresh();
  }

  bool get isLocalMode {
    if (_selectedCategoryId == null) return false;
    for (final c in _categories) {
      if (c.id == _selectedCategoryId) {
        return c.slug.toLowerCase() == 'local';
      }
    }
    return false;
  }

  bool get isTeluguLocalMode => selectedLanguage == 'te' && isLocalMode;

  bool get isHindiLocalMode => selectedLanguage == 'hi' && isLocalMode;

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
    return ['en', 'hi', 'te', 'ta', 'kn', 'bn', 'ml'].contains(selectedLanguage);
  }

  bool get shouldShowLocalScopeDropdown {
    if (!isLocalMode) return false;
    return ['en', 'hi', 'te', 'ta', 'kn', 'bn', 'ml'].contains(selectedLanguage);
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
    return isTeluguLocalMode && _selectedLocalScope == 'andhra';
  }

  /// National + world + AP/TG politics (Politics tab).
  List<(String label, String scope)> get politicsScopeOptions {
    if (selectedLanguage == 'te') {
      return const [
        ('All', 'all'),
        ('Andhra', 'andhra'),
        ('Telangana', 'telangana'),
        ('India', 'india'),
        ('International', 'international'),
      ];
    }
    if (selectedLanguage == 'hi') {
      return const [
        ('All', 'all'),
        ('UP', 'up'),
        ('Bihar', 'bihar'),
        ('Rajasthan', 'rajasthan'),
        ('Punjab', 'punjab'),
        ('Haryana', 'haryana'),
        ('Delhi', 'delhi'),
        ('India', 'india'),
        ('International', 'international'),
      ];
    }
    return const [
      ('All', 'all'),
      ('India', 'india'),
      ('International', 'international'),
    ];
  }

  /// State / regional news (Local tab).
  List<(String label, String scope)> get localScopeOptions {
    if (selectedLanguage == 'hi') {
      return const [
        ('All', 'all'),
        ('UP', 'up'),
        ('Bihar', 'bihar'),
        ('Rajasthan', 'rajasthan'),
        ('Punjab', 'punjab'),
        ('Haryana', 'haryana'),
        ('Delhi', 'delhi'),
      ];
    }
    return const [
      ('All', 'all'),
      ('Andhra', 'andhra'),
      ('Telangana', 'telangana'),
    ];
  }

  String get politicsScopeForApi {
    if (!isPoliticsMode || selectedPoliticsScope == 'all') return 'all';
    final allowed = selectedLanguage == 'hi'
        ? _hindiPoliticsScopeAllowlist
        : selectedLanguage == 'te'
            ? {'india', 'international', 'andhra', 'telangana'}
            : {'india', 'international'};
    if (allowed.contains(selectedPoliticsScope)) {
      return selectedPoliticsScope;
    }
    return 'all';
  }

  String get localScopeForApi {
    if (!isLocalMode || _selectedLocalScope == 'all') return 'all';
    final allowed = selectedLanguage == 'hi'
        ? _hindiLocalScopeAllowlist
        : selectedLanguage == 'te'
            ? {'andhra', 'telangana'}
            : <String>{};
    if (allowed.contains(_selectedLocalScope)) {
      return _selectedLocalScope;
    }
    return 'all';
  }

  String get regionScopeForApi {
    if (isPoliticsMode) return politicsScopeForApi;
    if (isLocalMode) return localScopeForApi;
    return 'all';
  }

  /// Simple exponential back-off retry wrapper: 1s, 2s, 4s delays, up to 3 tries.
  Future<Map<String, dynamic>> _retryWithBackoff(
    Future<Map<String, dynamic>> Function() attempt, {
    int maxRetries = 3,
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final result = await attempt();
        if (result['success'] != false) return result;
      } catch (_) {}
      if (i < maxRetries - 1) {
        await Future.delayed(Duration(seconds: 1 << i)); // 1, 2, 4 seconds
      }
    }
    return {'success': false, 'message': 'Failed after $maxRetries attempts. Please try again.'};
  }

  Future<void> _fetchPosts({required bool reset}) async {
    if (isLocalMode) {
      await _fetchLocalPosts(reset: reset);
      return;
    }
    try {
      Map<String, dynamic> res;
      if (_followingFeedOnly && ApiService.isAuthenticated) {
        res = await _retryWithBackoff(() => ApiService.getFeed(
          page: reset ? 1 : _page,
          language: selectedLanguage,
          following: true,
          days: 30,
          sourceTypes: const ['api', 'manual', 'rss', 'html', 'youtube'],
        ));
      } else if (_followingFeedOnly) {
        final guestFollows = await PublisherFollowService.loadGuestFollows();
        if (guestFollows.isEmpty) {
          if (reset) {
            _posts = [];
            _page = 1;
            _hasMore = false;
          }
          _error = null;
          return;
        }
        res = await _retryWithBackoff(() => ApiService.getFeed(
          page: reset ? 1 : _page,
          language: selectedLanguage,
          publishers: guestFollows.values.toList(),
          days: 30,
          sourceTypes: const ['api', 'manual', 'rss', 'html', 'youtube'],
        ));
      } else {
        res = await _retryWithBackoff(() => ApiService.getFeed(
          page: reset ? 1 : _page,
          categoryId: _selectedCategoryId,
          language: selectedLanguage,
          constituency:
              shouldShowAndhraConstituencyFilter ? selectedConstituency : 'all',
          politicsScope: regionScopeForApi,
          city: _cityForFeedQuery(),
          district: null,
          search: null,
          days: 30,
          sourceTypes: const ['api', 'manual', 'rss', 'html', 'youtube'],
        ));
      }
      if (res['success'] == true) {
        final rawPosts = (res['posts'] as List)
            .map((p) => NewsPost.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList();
        final apiPage = int.tryParse('${res['page']}') ?? (reset ? 1 : _page - 1);
        final apiPages = int.tryParse('${res['pages']}') ?? 1;

        var fetched = rawPosts;
        if (selectedLanguage != 'all') {
          fetched = fetched
              .where((p) => postMatchesFeedLanguage(p, selectedLanguage))
              .toList();
        }
        fetched.sort((a, b) => b.displayTime.compareTo(a.displayTime));
        if (reset) {
          _posts = dedupeNewsPosts(fetched);
          _page = apiPage + 1;
        } else {
          _posts = mergeDedupedPosts(_posts, fetched);
          _page = apiPage + 1;
        }
        _hasMore = apiPage < apiPages;
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

  Future<void> _fetchLocalPosts({required bool reset}) async {
    try {
      final page = reset ? 1 : _page;
      final res = await _retryWithBackoff(() => ApiService.getLocalNews(
        lat: _preferredLat,
        lng: _preferredLng,
        radiusKm: 75,
        city: _cityForFeedQuery(),
        district: _districtForLocalQuery(),
        mandal: _mandalForLocalQuery(),
        state: _stateForLocalQuery(),
        constituency: 'all',
        politicsScope: localScopeForApi,
        language: selectedLanguage,
        page: page,
      ));
      if (res['success'] == true) {
        final rawPosts = (res['posts'] as List)
            .map((p) => NewsPost.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList();
        final apiPage = int.tryParse('${res['page']}') ?? page;
        final apiPages = int.tryParse('${res['pages']}') ?? 1;

        var fetched = rawPosts;
        if (selectedLanguage != 'all') {
          fetched = fetched
              .where((p) => postMatchesFeedLanguage(p, selectedLanguage))
              .toList();
        }
        fetched.sort((a, b) => b.displayTime.compareTo(a.displayTime));
        if (reset) {
          _posts = dedupeNewsPosts(fetched);
          _page = apiPage + 1;
        } else {
          _posts = mergeDedupedPosts(_posts, fetched);
          _page = apiPage + 1;
        }
        _hasMore = apiPage < apiPages;
        _error = null;
      } else {
        _error = (res['message']?.toString().trim().isNotEmpty == true)
            ? res['message'].toString().trim()
            : 'Failed to load local news.';
      }
    } catch (e) {
      _error = _formatError(
        e,
        fallback: 'Failed to load local news. Check your connection.',
      );
    }
  }

  // Update a single post in the list (e.g. after like/bookmark)
  void updatePost(String postId, {int? likes, bool? liked}) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    final post = _posts[index];
    if (likes != null && post.likes != likes) {
      // Update likes count
      _posts[index] = NewsPost.fromJson({
        ...post.toJson(),
        'likes': likes,
      });
    }
    // liked is local state - handled by UI widgets

    notifyListeners();
  }

  bool isPostSeen(String postId) => _seenPostIds.contains(postId);

  Future<void> markPostAsSeen(String postId) async {
    if (postId.isEmpty || _seenPostIds.contains(postId)) return;
    _seenPostIds.add(postId);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_seenPostsKey, _seenPostIds.toList());
    if (ApiService.isAuthenticated) {
      unawaited(ApiService.markPostSeen(postId));
    }
  }

  /// Loads breaking headlines for Quick News; falls back to latest headlines.
  Future<void> loadBreakingFeed() async {
    _breakingLoading = true;
    _breakingError = null;
    notifyListeners();
    try {
      List<NewsPost> parseFeed(Map<String, dynamic> res) {
        if (res['success'] != true || res['posts'] is! List) return [];
        var fetched = (res['posts'] as List)
            .map((p) => NewsPost.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList();
        if (selectedLanguage != 'all') {
          fetched = fetched
              .where((p) => postMatchesFeedLanguage(p, selectedLanguage))
              .toList();
        }
        fetched.sort((a, b) => b.displayTime.compareTo(a.displayTime));
        return dedupeNewsPosts(fetched);
      }

      var res = await ApiService.getFeed(
        page: 1,
        language: selectedLanguage,
        breaking: true,
        days: 7,
      );
      var breakingOnly = parseFeed(res).where((p) => p.isBreaking).toList();
      _breakingHighlightPosts = breakingOnly.take(6).toList();

      var posts = parseFeed(res);
      if (posts.isEmpty) {
        res = await ApiService.getFeed(
          page: 1,
          language: selectedLanguage,
          days: 7,
        );
        posts = parseFeed(res);
      }
      _breakingPosts = posts.take(12).toList();
      _breakingError =
          _breakingPosts.isEmpty ? 'No headlines available right now.' : null;
    } catch (e) {
      _breakingPosts = [];
      _breakingError = _formatError(e);
    }
    _breakingLoading = false;
    notifyListeners();
  }

  /// Breaking + trending rails for the main feed header.
  Future<void> loadFeedHighlights() async {
    await Future.wait([loadBreakingFeed(), loadTrendingFeed()]);
  }

  Future<void> loadTrendingFeed() async {
    try {
      final res = await ApiService.getFeed(
        page: 1,
        limit: 8,
        language: selectedLanguage,
        sort: 'trending',
        days: 2,
      );
      if (res['success'] == true && res['posts'] is List) {
        var fetched = (res['posts'] as List)
            .map((p) => NewsPost.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList();
        if (selectedLanguage != 'all') {
          fetched = fetched
              .where((p) => postMatchesFeedLanguage(p, selectedLanguage))
              .toList();
        }
        _trendingPosts = dedupeNewsPosts(fetched).take(8).toList();
      } else {
        _trendingPosts = [];
      }
    } catch (_) {
      _trendingPosts = [];
    }
    notifyListeners();
  }
}
