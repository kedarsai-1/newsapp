import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants.dart';
import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/feed/dailyhunt_feed_skeleton.dart';
import '../../widgets/feed/feed_image_cache.dart';
import '../../widgets/feed/feed_highlights_rail.dart';
import '../../widgets/feed/feed_list_view.dart';
import '../../widgets/feed/feed_scope_chip_bar.dart';
import '../../widgets/feed/local_saved_location_bar.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';
import '../../widgets/feed/breaking_banner.dart';
import '../../widgets/dailyhunt/dailyhunt_category_tab_bar.dart';
import '../../widgets/feed/dailyhunt_feed_article_card.dart';
import '../../widgets/feed/feed_list_tuning.dart';
import '../../utils/category_navigation.dart';
import '../../utils/i18n.dart';
import '../../utils/post_share.dart';
import '../../widgets/dailyhunt/xpresso_side_menu.dart';
import '../../widgets/premium_utils.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

/// Feed tab labels → API category slugs (`null` = Top News / all).
const List<(String, String?)> _kFeedTabs = [
  ('Top News', null),
  ('Politics', 'politics'),
  ('Sports', 'sports'),
  ('Entertainment', 'entertainment'),
  ('Technology', 'technology'),
  ('Business', 'business'),
  ('Health', 'health'),
  ('Education', 'education'),
  ('Crime', 'crime'),
  ('Agriculture', 'agriculture'),
  ('Jobs & Exams', 'jobs'),
  ('Local', 'local'),
];

const List<String> _kFeedTabLabels = [
  'Top News',
  'Politics',
  'Sports',
  'Entertainment',
  'Technology',
  'Business',
  'Health',
  'Education',
  'Crime',
  'Agriculture',
  'Jobs & Exams',
  'Local',
];

class _FeedScreenState extends State<FeedScreen> with WidgetsBindingObserver {
  static const _likedCacheKey = 'feed_liked_state_cache_v1';
  /// Web has no socket push — poll often enough to match server cron (~5 min).
  static const _autoRefreshInterval = Duration(minutes: 5);

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _headerCollapse = ValueNotifier(0);
  final Map<String, bool> _bookmarkedByPostId = {};
  final Map<String, bool> _likedByPostId = {};
  Timer? _autoRefreshTimer;
  DateTime? _lastFeedRefreshAt;
  bool _sidebarOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _restoreLikedCache();
    _primeBookmarkState();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) => _autoRefreshFeed());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NewsProvider>();
      provider.loadFeedHighlights();
      if (provider.posts.isEmpty && !provider.refreshing) {
        _refreshFeed(markAuto: true);
      } else {
        _maybeRefreshStaleFeed();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _headerCollapse.dispose();
    super.dispose();
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeRefreshStaleFeed();
    }
  }

  void _maybeRefreshStaleFeed() {
    final last = _lastFeedRefreshAt;
    if (last == null || DateTime.now().difference(last) >= _autoRefreshInterval) {
      _autoRefreshFeed();
    }
  }

  Future<void> _autoRefreshFeed() async {
    if (!mounted) return;
    final news = context.read<NewsProvider>();
    if (news.refreshing || news.loading) return;
    await _refreshFeed(markAuto: true, scrollToTop: false);
  }

  void _scrollFeedToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final news = context.read<NewsProvider>();
    if (news.posts.isNotEmpty) {
      FeedImagePrecache.onScroll(context, news.posts, pos);
    }
    final offset = pos.pixels;
    final progress = (offset / 100.0).clamp(0.0, 1.0);
    final quantized = (progress * 10).round() / 10;
    if ((quantized - _headerCollapse.value).abs() >= 0.08) {
      _headerCollapse.value = quantized;
    }
    if (pos.maxScrollExtent <= 0) return;
    if (pos.pixels >= pos.maxScrollExtent - 480) {
      if (news.hasMore && !news.loading) news.loadMore();
    }
  }

  /// Collapsing chrome — quantized [ValueNotifier] avoids per-pixel rebuilds (DEF-001).
  Widget _collapsingHeader({
    required double translateMax,
    required Widget child,
  }) {
    return ValueListenableBuilder<double>(
      valueListenable: _headerCollapse,
      builder: (context, adjusted, child) {
        final heightFactor = (1.0 - adjusted).clamp(0.0, 1.0);
        final opacity = (1.0 - adjusted).clamp(0.0, 1.0);
        return ClipRect(
          child: Opacity(
            opacity: opacity,
            child: Align(
              heightFactor: heightFactor,
              alignment: Alignment.topCenter,
              child: Transform.translate(
                offset: Offset(0, -translateMax * adjusted),
                child: child,
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }

  Future<void> _restoreLikedCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_likedCacheKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final restored = <String, bool>{};
      decoded.forEach((key, value) {
        if (key.trim().isEmpty) return;
        restored[key] = value == true;
      });
      if (!mounted) return;
      setState(() {
        _likedByPostId
          ..clear()
          ..addAll(restored);
      });
    } catch (_) {}
  }

  Future<void> _persistLikedCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_likedCacheKey, jsonEncode(_likedByPostId));
  }

  Future<void> _primeBookmarkState() async {
    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (loggedIn) {
      final res = await ApiService.getBookmarks();
      if (!mounted) return;
      if (res['success'] == true && res['bookmarks'] is List) {
        final map = <String, bool>{};
        for (final item in (res['bookmarks'] as List)) {
          if (item is Map<String, dynamic>) {
            final id = item['_id']?.toString() ?? '';
            if (id.isNotEmpty) map[id] = true;
          } else if (item is Map) {
            final id = item['_id']?.toString() ?? '';
            if (id.isNotEmpty) map[id] = true;
          }
        }
        setState(() {
          _bookmarkedByPostId
            ..clear()
            ..addAll(map);
        });
      }
      return;
    }
    final guest = await ApiService.getGuestBookmarks();
    if (!mounted) return;
    setState(() {
      _bookmarkedByPostId
        ..clear()
        ..addEntries(guest.map((post) => MapEntry(post.id, true)));
    });
  }

  int _chipIndexForProvider(NewsProvider news) {
    final sel = news.selectedCategoryId;
    if (sel == null) return 0;
    for (var i = 1; i < _kFeedTabs.length; i++) {
      final slug = _kFeedTabs[i].$2;
      if (slug == null) continue;
      for (final c in news.categories) {
        if (c.slug.toLowerCase() == slug && c.id == sel) return i;
      }
    }
    return 0;
  }

  Future<void> _selectCategoryChip(int index) async {
    final news = context.read<NewsProvider>();
    final slug = _kFeedTabs[index].$2;
    if (slug == null) {
      FeedImagePrecache.reset();
    await news.selectCategory(null);
      _scrollFeedToTop();
      return;
    }
    if (slug == 'sports' || slug == 'weather') {
      if (mounted) await openCategorySlug(context, slug, news: news);
      return;
    }
    Category? match;
    for (final c in news.categories) {
      if (c.slug.toLowerCase() == slug) {
        match = c;
        break;
      }
    }
    if (match == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '“${_kFeedTabs[index].$1}” is not available yet. Try again after categories load.',
          ),
          behavior: SnackBarBehavior.floating,
          width: 360,
        ),
      );
      return;
    }
    FeedImagePrecache.reset();
    await news.selectCategory(match.id);
    _scrollFeedToTop();
  }

  Future<bool> _toggleLike(NewsPost post) async {
    final id = post.id;
    final prev = _likedByPostId[id] ?? false;
    _likedByPostId[id] = !prev;

    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (!loggedIn) {
      final liked = await ApiService.toggleGuestLike(id);
      if (!mounted) return false;
      _likedByPostId[id] = liked;
      _persistLikedCache();
      return true;
    }
    final res = await ApiService.toggleLike(id);
    if (!mounted) return false;
    if (res['success'] != true) {
      _likedByPostId[id] = prev;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Could not update')),
      );
      return false;
    }
    _likedByPostId[id] = res['liked'] == true;
    _persistLikedCache();
    return true;
  }

  Future<bool> _toggleBookmark(NewsPost post) async {
    final id = post.id;
    final prev = _bookmarkedByPostId[id] ?? false;
    _bookmarkedByPostId[id] = !prev;

    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (!loggedIn) {
      final saved = await ApiService.toggleGuestBookmark(post);
      if (!mounted) return false;
      _bookmarkedByPostId[id] = saved;
      return true;
    }
    final res = await ApiService.toggleBookmark(id);
    if (!mounted) return false;
    if (res['success'] != true) {
      _bookmarkedByPostId[id] = prev;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Could not save')),
      );
      return false;
    }
    _bookmarkedByPostId[id] = res['bookmarked'] == true;
    return true;
  }

  Future<void> _share(NewsPost post) async {
    await PostShare.sharePost(post, context: context);
  }

  void _openArticle(NewsPost post) {
    context.read<NewsProvider>().markPostAsSeen(post.id);
    context.push('/article/${post.id}');
  }

  Future<void> _refreshFeed({
    bool markAuto = false,
    bool scrollToTop = true,
  }) async {
    final news = context.read<NewsProvider>();
    if (markAuto) {
      await news.refreshPostsOnly();
    } else {
      await news.refresh();
    }
    if (markAuto) _lastFeedRefreshAt = DateTime.now();
    if (scrollToTop) _scrollFeedToTop();
  }

  static (String emoji, List<Color> colors) _categoryStyle(String slug) =>
      FeedXpressoPalette.categoryGradient(slug);

  Widget _activeCategoryBanner(NewsProvider news) {
    if (news.selectedCategoryId == null) return const SizedBox.shrink();
    
    Category? activeCat;
    for (final c in news.categories) {
      if (c.id == news.selectedCategoryId) {
        activeCat = c;
        break;
      }
    }
    if (activeCat == null) return const SizedBox.shrink();
    
    final style = _categoryStyle(activeCat.slug);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: style.$2[0].withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: style.$2[0].withOpacity(0.35), width: 0.8),
      ),
      child: Row(
        children: [
          Text(style.$1, style: TextStyle(fontSize: 14)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filtering by Topic: ${activeCat.name}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: style.$2[0],
              ),
            ),
          ),
          GestureDetector(
            onTap: () async {
              await news.selectCategory(null);
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: style.$2[0].withOpacity(0.20),
              ),
              child: Icon(Icons.close_rounded, size: 12, color: style.$2[0]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarNavTile({
    required NewsProvider news,
    required String label,
    required String emoji,
    required String slug,
    required bool isSelected,
    required Future<void> Function() onTap,
  }) {
    final fx = context.fx;
    final style = _categoryStyle(slug);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: () => onTap(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? style.$2[0].withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? style.$2[0].withOpacity(0.35) : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: TextStyle(fontSize: 14)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? style.$2[0] : fx.textSecondary,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 14,
                  color: style.$2[0],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sidebarCategoryList(NewsProvider news) {
    final fx = context.fx;
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              I18n.t(context, 'feed_filter_topics').toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: fx.textTertiary,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              itemCount: news.categories.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _sidebarNavTile(
                    news: news,
                    label: I18n.t(context, 'feed_top_news'),
                    emoji: '📰',
                    slug: '',
                    isSelected: news.selectedCategoryId == null && !news.followingFeedOnly,
                    onTap: () async {
                      await news.selectCategory(null);
                      _scrollFeedToTop();
                      setState(() => _sidebarOpen = false);
                    },
                  );
                }
                if (index == 1) {
                  return _sidebarNavTile(
                    news: news,
                    label: I18n.t(context, 'feed_following'),
                    emoji: '⭐',
                    slug: 'following',
                    isSelected: news.followingFeedOnly,
                    onTap: () async {
                      await news.selectFollowingFeed();
                      _scrollFeedToTop();
                      setState(() => _sidebarOpen = false);
                    },
                  );
                }
                final cat = news.categories[index - 2];
                final bool isSelected =
                    news.selectedCategoryId == cat.id && !news.followingFeedOnly;
                final style = _categoryStyle(cat.slug);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: GestureDetector(
                    onTap: () async {
                      final slug = cat.slug.toLowerCase();
                      if (slug == 'sports' || slug == 'weather') {
                        setState(() => _sidebarOpen = false);
                        if (!context.mounted) return;
                        await openCategorySlug(context, slug, news: news);
                        return;
                      }
                      await news.selectCategory(cat.id);
                      _scrollFeedToTop();
                      setState(() => _sidebarOpen = false);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? style.$2[0].withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? style.$2[0].withOpacity(0.35)
                              : Colors.transparent,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(style.$1, style: TextStyle(fontSize: 14)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? style.$2[0] : fx.textSecondary,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 14,
                              color: style.$2[0],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final bottomInset = FeedXpressoTheme.feedBottomInset(context);
    final news = context.watch<NewsProvider>();
    final width = MediaQuery.sizeOf(context).width;

    Widget buildCuratedFeedContent() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _collapsingHeader(
            translateMax: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _activeCategoryBanner(news),
                if (news.isLocalMode) const LocalSavedLocationBar(),
                Selector<NewsProvider, _RegionChipBarData>(
                  selector: (_, news) {
                    if (news.shouldShowPoliticalScopeDropdown) {
                      return _RegionChipBarData(
                        selectedScope: news.selectedPoliticsScope,
                        options: news.politicsScopeOptions,
                        onSelectPolitics: true,
                      );
                    }
                    if (news.shouldShowLocalScopeDropdown) {
                      return _RegionChipBarData(
                        selectedScope: news.selectedLocalScope,
                        options: news.localScopeOptions,
                        onSelectPolitics: false,
                      );
                    }
                    return const _RegionChipBarData.hidden();
                  },
                  builder: (_, data, __) {
                    if (data.hidden) return const SizedBox.shrink();
                    final news = context.read<NewsProvider>();
                    return RepaintBoundary(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FeedScopeChipBar(
                            selectedScope: data.selectedScope,
                            options: data.options,
                            onSelected: data.onSelectPolitics
                                ? news.selectPoliticsScope
                                : news.selectLocalScope,
                          ),
                          if (data.onSelectPolitics) const _PoliticalReelsEntry(),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Selector<NewsProvider, FeedListSnapshot>(
                selector: (_, news) => readFeedListSnapshot(news),
                builder: (context, snap, _) {
                  if (snap.error != null) {
                    return ErrorState(
                      message: snap.error!,
                      dark: FeedXpressoTheme.isDark(context),
                      onRetry: context.read<NewsProvider>().refresh,
                    );
                  }
                  if (snap.posts.isEmpty && snap.refreshing) {
                    FeedImagePrecache.reset();
                    return const DailyhuntFeedSkeleton(
                      rowCount: 8,
                      showChrome: false,
                    );
                  }
                  if (snap.posts.isEmpty) {
                    final news = context.read<NewsProvider>();
                    final onLocal = news.shouldShowLocalScopeDropdown;
                    final scope = onLocal
                        ? news.selectedLocalScope
                        : news.selectedPoliticsScope;
                    String? scopeLabel;
                    if (scope != 'all') {
                      final opts = onLocal
                          ? news.localScopeOptions
                          : news.politicsScopeOptions;
                      for (final o in opts) {
                        if (o.$2 == scope) {
                          scopeLabel = o.$1;
                          break;
                        }
                      }
                    }
                    return EmptyState(
                      icon: Icons.article_outlined,
                      title: scopeLabel != null
                          ? 'No $scopeLabel stories yet'
                          : 'No stories yet',
                      subtitle: news.categories.isEmpty
                          ? 'Categories did not load — check API and pull to refresh.'
                          : I18n.t(context, 'feed_empty_pick_category'),
                      dark: FeedXpressoTheme.isDark(context),
                      buttonLabel: news.categories.isEmpty ? 'Retry' : null,
                      onButtonTap: news.categories.isEmpty
                          ? () => news.refresh()
                          : null,
                    );
                  }
                  scheduleFeedImagePrecache(
                    context,
                    snap.posts,
                    _scrollController,
                  );
                  final breakingPosts = context.watch<NewsProvider>().breakingHighlightPosts;
                  final trendingPosts = context.watch<NewsProvider>().trendingPosts;
                  final breakingLoading = context.watch<NewsProvider>().breakingLoading;

                  return FeedListView(
                    posts: snap.posts,
                    loadingMore: snap.loading && snap.hasMore,
                    bottomInset: bottomInset,
                    scrollController: _scrollController,
                    likedByPostId: _likedByPostId,
                    bookmarkedByPostId: _bookmarkedByPostId,
                    onRefresh: _refreshFeed,
                    onLike: _toggleLike,
                    onBookmark: _toggleBookmark,
                    listHeader: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (breakingPosts.isNotEmpty)
                          BreakingBanner(
                            breakingPosts: breakingPosts,
                            onTap: _openArticle,
                          ),
                        FeedHighlightsRail(
                          breaking: breakingPosts,
                          trending: trendingPosts,
                          loading: breakingLoading,
                          onOpen: _openArticle,
                        ),
                      ],
                    ),
                    onShare: _share,
                    onOpen: _openArticle,
                    isPostSeen: context.read<NewsProvider>().isPostSeen,
                  );
                },
              ),
            ),
        ],
      );
    }

    Widget bodyContent;
    final bool useMobileLayout = width < 800;

    if (news.layoutMode == AppLayoutMode.carouselWheel ||
        news.layoutMode == AppLayoutMode.dualDeck) {
      bodyContent = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _collapsingHeader(
            translateMax: 15,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: CategoryCarouselWheel(
                categories: news.categories,
                selectedCategoryId: news.selectedCategoryId,
                onSelected: (id) => openCategoryById(context, id, news: news),
              ),
            ),
          ),
          Expanded(
            child: buildCuratedFeedContent(),
          ),
        ],
      );
    } else {
      // Sidebar layout
      if (!useMobileLayout) {
        bodyContent = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sidebarCategoryList(news),
            Expanded(
              child: buildCuratedFeedContent(),
            ),
          ],
        );
      } else {
        bodyContent = Stack(
          children: [
            buildCuratedFeedContent(),
            if (_sidebarOpen)
              GestureDetector(
                onTap: () => setState(() => _sidebarOpen = false),
                child: Container(
                  color: fx.overlayScrim,
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: _sidebarOpen ? 0 : -260,
              top: 0,
              bottom: 0,
              width: 260,
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: fx.overlayScrim,
                      border: Border(
                        right: BorderSide(
                          color: fx.onImage.withOpacity(0.08),
                          width: 0.8,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      child: _sidebarCategoryList(news),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          child: _DailyhuntFeedAppBar(
            onMenuPressed: news.layoutMode == AppLayoutMode.sidebarPanel && useMobileLayout
                ? () => setState(() => _sidebarOpen = !_sidebarOpen)
                : null,
          ),
        ),
        Expanded(
          child: bodyContent,
        ),
      ],
    );
  }
}

class CategoryCarouselWheel extends StatefulWidget {
  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;

  const CategoryCarouselWheel({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  @override
  State<CategoryCarouselWheel> createState() => _CategoryCarouselWheelState();
}

class _CategoryCarouselWheelState extends State<CategoryCarouselWheel> {
  late final PageController _pageController;
  late List<(String, String?)> _items;

  @override
  void initState() {
    super.initState();
    _buildItems();
    final initialIdx = _selectedIndex();
    _pageController = PageController(
      viewportFraction: 0.38,
      initialPage: initialIdx,
    );
  }

  void _buildItems() {
    _items = [
      ('Top News', null),
      ...widget.categories.map((c) => (c.name, c.id)),
    ];
  }

  int _selectedIndex() {
    final sel = widget.selectedCategoryId;
    if (sel == null) return 0;
    for (int i = 0; i < widget.categories.length; i++) {
      if (widget.categories[i].id == sel) return i + 1;
    }
    return 0;
  }

  @override
  void didUpdateWidget(covariant CategoryCarouselWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categories != widget.categories) {
      _buildItems();
    }
    final activeIdx = _selectedIndex();
    if (_pageController.hasClients && _pageController.page?.round() != activeIdx) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            activeIdx,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  (String, List<Color>) _categoryStyle(String? name, FeedXpressoPalette fx) {
    if (name == null) return ('📰', [fx.meta, fx.chipInactiveBg]);
    return FeedXpressoPalette.categoryGradient(name);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: AnimatedBuilder(
        animation: _pageController,
        builder: (context, child) {
          return PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) {
              if (idx >= 0 && idx < _items.length) {
                final targetId = _items[idx].$2;
                if (targetId != widget.selectedCategoryId) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    widget.onSelected(targetId);
                  });
                }
              }
            },
            physics: const BouncingScrollPhysics(),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              double value = 0.0;
              if (_pageController.position.haveDimensions) {
                value = _pageController.page! - index;
              } else {
                value = (_pageController.initialPage - index).toDouble();
              }
              value = value.clamp(-1.0, 1.0);

              final scale = 1.0 - (value.abs() * 0.16);
              final opacity = 1.0 - (value.abs() * 0.45);
              final rotation = value * 0.38;

              final chipFx = context.fx;
              final style = _categoryStyle(item.$2 == null ? null : item.$1, chipFx);
              final isSelected = index == _selectedIndex();

              return Center(
                child: Opacity(
                  opacity: opacity.clamp(0.4, 1.0),
                  child: Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..scale(scale)
                      ..rotateY(rotation),
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                        widget.onSelected(item.$2);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? style.$2[0].withOpacity(0.20)
                              : chipFx.glassSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? style.$2[0].withOpacity(0.50)
                                : chipFx.glassBorder,
                            width: isSelected ? 1.5 : 0.8,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: style.$2[0].withOpacity(0.20),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(style.$1, style: TextStyle(fontSize: 14)),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                item.$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected ? style.$2[0] : chipFx.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoriesLoadBanner extends StatelessWidget {
  final String message;

  const _CategoriesLoadBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Material(
      color: fx.accent.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, size: 18, color: fx.accent),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fx.title,
                  height: 1.3,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.read<NewsProvider>().loadCategories(),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: fx.accent,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}


class _RegionChipBarData {
  final bool hidden;
  final String selectedScope;
  final List<(String label, String scope)> options;
  final bool onSelectPolitics;

  const _RegionChipBarData({
    required this.selectedScope,
    required this.options,
    required this.onSelectPolitics,
  }) : hidden = false;

  const _RegionChipBarData.hidden()
      : hidden = true,
        selectedScope = 'all',
        options = const [],
        onSelectPolitics = true;
}

class _DailyhuntFeedAppBar extends StatelessWidget {
  final VoidCallback? onMenuPressed;
  const _DailyhuntFeedAppBar({this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return ColoredBox(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: kToolbarHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: onMenuPressed != null
                          ? I18n.t(context, 'feed_filter_topics')
                          : 'Menu',
                      onPressed: onMenuPressed ?? () => XpressoSideMenu.open(context),
                      icon: onMenuPressed != null
                          ? Icon(
                              Icons.menu_open_rounded,
                              size: 24,
                              color: fx.accent,
                            )
                          : Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: fx.divider.withValues(alpha: 0.8),
                                  width: 0.5,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 17,
                                backgroundColor: fx.iconSurface,
                                child: Icon(
                                  Icons.person_rounded,
                                  size: 19,
                                  color: fx.iconFg,
                                ),
                              ),
                            ),
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    fx.accent.withValues(alpha: 0.35),
                                    fx.iconSurface,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: fx.accent.withValues(alpha: 0.45),
                                  width: 0.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.article_rounded,
                                color: fx.accent,
                                size: 17,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              AppConstants.appName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: fx.screenTitleStyle.copyWith(
                                fontSize: 18,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'AI News Assistant',
                      onPressed: () => context.push('/ai-chat'),
                      icon: Icon(
                        Icons.auto_awesome_rounded,
                        color: fx.accent,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Notifications',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No new notifications'),
                            duration: Duration(milliseconds: 1200),
                            behavior: SnackBarBehavior.floating,
                            width: 300,
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.notifications_none_rounded,
                        color: fx.iconFg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: fx.onImage.withOpacity(0.08)),
        ],
      ),
    );
  }
}

class FeedSearchDelegate extends SearchDelegate<String> {
  final NewsProvider provider;
  final void Function(NewsPost) onOpen;
  final Future<bool> Function(NewsPost) onLike;
  final Future<bool> Function(NewsPost) onBookmark;
  final void Function(NewsPost) onShare;
  final Map<String, bool> likedByPostId;
  final Map<String, bool> bookmarkedByPostId;

  FeedSearchDelegate({
    required this.provider,
    required this.onOpen,
    required this.onLike,
    required this.onBookmark,
    required this.onShare,
    required this.likedByPostId,
    required this.bookmarkedByPostId,
  });

  void _exit(BuildContext context) {
    provider.endSearch();
    close(context, '');
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          onPressed: () => query = '',
          icon: Icon(Icons.clear_rounded),
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        onPressed: () => _exit(context),
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
      );

  @override
  Widget buildResults(BuildContext context) =>
      _SearchResults(
        provider: provider,
        query: query,
        onOpen: onOpen,
        onLike: onLike,
        onBookmark: onBookmark,
        onShare: onShare,
        likedByPostId: likedByPostId,
        bookmarkedByPostId: bookmarkedByPostId,
      );

  @override
  Widget buildSuggestions(BuildContext context) => query.isEmpty
      ? Center(child: Text('Search news, topics, places...'))
      : buildResults(context);
}

class _SearchResults extends StatefulWidget {
  final NewsProvider provider;
  final String query;
  final void Function(NewsPost) onOpen;
  final Future<bool> Function(NewsPost) onLike;
  final Future<bool> Function(NewsPost) onBookmark;
  final void Function(NewsPost) onShare;
  final Map<String, bool> likedByPostId;
  final Map<String, bool> bookmarkedByPostId;

  const _SearchResults({
    required this.provider,
    required this.query,
    required this.onOpen,
    required this.onLike,
    required this.onBookmark,
    required this.onShare,
    required this.likedByPostId,
    required this.bookmarkedByPostId,
  });

  @override
  State<_SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends State<_SearchResults> {
  static const _debounceDuration = Duration(milliseconds: 300);

  bool _loading = true;
  Timer? _debounce;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scheduleSearch();
  }

  @override
  void didUpdateWidget(covariant _SearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _scheduleSearch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    final q = widget.query.trim();
    if (q.isEmpty) {
      widget.provider.endSearch();
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(_debounceDuration, () {
      if (mounted) _runSearch(q);
    });
  }

  Future<void> _runSearch(String query) async {
    final gen = ++_searchGeneration;
    await widget.provider.search(query);
    if (!mounted || gen != _searchGeneration) return;
    setState(() => _loading = false);
  }

  Future<void> _runImmediate() async {
    _debounce?.cancel();
    final q = widget.query.trim();
    if (q.isEmpty) {
      widget.provider.endSearch();
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    await _runSearch(q);
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    if (_loading || provider.searchLoading) {
      return const DailyhuntFeedSkeleton(rowCount: 6);
    }
    if (provider.searchError != null) {
      return ErrorState(
        message: provider.searchError!,
        onRetry: _runImmediate,
        dark: FeedXpressoTheme.isDark(context),
      );
    }
    final posts = provider.searchResults;
    if (posts.isEmpty) {
      return const EmptyState(icon: Icons.search_off, title: 'No results');
    }
    return ListView.builder(
      physics: FeedListTuning.scrollPhysics,
      cacheExtent: FeedListTuning.cacheExtent,
      padding: FeedListTuning.listPadding,
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return DailyhuntFeedArticleCard(
          key: ValueKey('search-${post.id}'),
          post: post,
          liked: widget.likedByPostId[post.id] ?? false,
          saved: widget.bookmarkedByPostId[post.id] ?? false,
          onOpen: () => widget.onOpen(post),
          onLike: () => widget.onLike(post),
          onBookmark: () => widget.onBookmark(post),
          onShare: () => widget.onShare(post),
        );
      },
    );
  }
}

class _PoliticalReelsEntry extends StatelessWidget {
  const _PoliticalReelsEntry();

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Material(
        color: fx.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.push('/political-reels'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.play_circle_outline_rounded, color: fx.accent, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Political interviews & debates',
                    style: TextStyle(
                      color: fx.title,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: fx.iconFgMuted, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void openFeedSearch(
  BuildContext context, {
  required void Function(NewsPost) onOpen,
  required Future<bool> Function(NewsPost) onLike,
  required Future<bool> Function(NewsPost) onBookmark,
  required void Function(NewsPost) onShare,
  required Map<String, bool> likedByPostId,
  required Map<String, bool> bookmarkedByPostId,
}) {
  final provider = context.read<NewsProvider>();
  showSearch<String>(
    context: context,
    delegate: FeedSearchDelegate(
      provider: provider,
      onOpen: onOpen,
      onLike: onLike,
      onBookmark: onBookmark,
      onShare: onShare,
      likedByPostId: likedByPostId,
      bookmarkedByPostId: bookmarkedByPostId,
    ),
  ).then((_) => provider.endSearch());
}
