import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../constants.dart';
import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/dailyhunt_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/feed/dailyhunt_feed_skeleton.dart';
import '../../widgets/feed/feed_image_cache.dart';
import '../../widgets/feed/feed_list_view.dart';
import '../../widgets/dailyhunt/dailyhunt_category_tab_bar.dart';
import '../../widgets/premium_news_ui.dart';

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
  ('Local', 'local'),
  ('Business', 'business'),
];

const List<String> _kFeedTabLabels = [
  'Top News',
  'Politics',
  'Sports',
  'Entertainment',
  'Technology',
  'Local',
  'Business',
];

class _FeedScreenState extends State<FeedScreen> {
  static const _likedCacheKey = 'feed_liked_state_cache_v1';

  final ScrollController _scrollController = ScrollController();
  final Map<String, bool> _bookmarkedByPostId = {};
  final Map<String, bool> _likedByPostId = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _restoreLikedCache();
    _primeBookmarkState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NewsProvider>();
      if (provider.posts.isEmpty && !provider.refreshing) provider.refresh();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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
    if (pos.maxScrollExtent <= 0) return;
    if (pos.pixels >= pos.maxScrollExtent - 480) {
      if (news.hasMore && !news.loading) news.loadMore();
    }
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
    final text =
        '${post.title}\n\n${premiumSnippet(post, maxLength: 260)}\n\n${post.sourceUrl ?? ''}';
    await Share.share(text, subject: post.title);
  }

  void _openArticle(NewsPost post) {
    context.push('/article/${post.id}');
  }

  Future<void> _refreshFeed() async {
    await context.read<NewsProvider>().refresh();
    _scrollFeedToTop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom + 72;

    return Theme(
      data: DailyhuntTheme.overlay(context),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const RepaintBoundary(child: _DailyhuntFeedAppBar()),
            RepaintBoundary(
              child: Selector<NewsProvider, int>(
                selector: (_, news) => _chipIndexForProvider(news),
                builder: (_, chipIndex, __) => DailyhuntCategoryTabBar(
                  categories: _kFeedTabLabels,
                  selectedIndex: chipIndex,
                  onSelected: _selectCategoryChip,
                ),
              ),
            ),
            Expanded(
              child: Selector<NewsProvider, FeedListSnapshot>(
                selector: (_, news) => readFeedListSnapshot(news),
                builder: (context, snap, _) {
                  if (snap.error != null) {
                    return ErrorState(
                      message: snap.error!,
                      onRetry: context.read<NewsProvider>().refresh,
                    );
                  }
                  if (snap.posts.isEmpty && snap.refreshing) {
                    FeedImagePrecache.reset();
                    return const DailyhuntFeedSkeleton(rowCount: 10);
                  }
                  if (snap.posts.isEmpty) {
                    return const EmptyState(
                      icon: Icons.article_outlined,
                      title: 'No stories yet',
                      subtitle: 'Pull down to refresh or pick another category.',
                    );
                  }
                  scheduleFeedImagePrecache(
                    context,
                    snap.posts,
                    _scrollController,
                  );
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
                    onShare: _share,
                    onOpen: _openArticle,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyhuntFeedAppBar extends StatelessWidget {
  const _DailyhuntFeedAppBar();

  static const _titleStyle = TextStyle(
    fontWeight: FontWeight.w900,
    fontSize: 17,
    letterSpacing: -0.4,
    color: Color(0xFF111111),
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Profile',
                  onPressed: () => context.go('/settings'),
                  icon: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFE8EAED),
                    child: Icon(
                      Icons.person_rounded,
                      size: 20,
                      color: Color(0xFF5F6368),
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: DailyhuntTheme.accentGreen,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.article_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          AppConstants.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _titleStyle,
                        ),
                      ),
                    ],
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
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFF5F6368),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FeedSearchDelegate extends SearchDelegate<String> {
  final NewsProvider provider;

  FeedSearchDelegate(this.provider);

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear_rounded),
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, ''),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
      );

  @override
  Widget buildResults(BuildContext context) =>
      _SearchResults(provider: provider, query: query);

  @override
  Widget buildSuggestions(BuildContext context) => query.isEmpty
      ? const Center(child: Text('Search news, topics, places...'))
      : _SearchResults(provider: provider, query: query);
}

class _SearchResults extends StatefulWidget {
  final NewsProvider provider;
  final String query;

  const _SearchResults({required this.provider, required this.query});

  @override
  State<_SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends State<_SearchResults> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void didUpdateWidget(covariant _SearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _run();
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    await widget.provider.search(widget.query);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (widget.provider.posts.isEmpty) {
      return const EmptyState(icon: Icons.search_off, title: 'No results');
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      padding: const EdgeInsets.all(12),
      itemCount: widget.provider.posts.length,
      itemBuilder: (context, index) {
        final post = widget.provider.posts[index];
        return DhNewsCard(
          title: post.title,
          summary: premiumSnippet(post, maxLength: 120),
          imageUrl: premiumImageUrl(post),
          sourceLabel: post.sourceName ?? post.category?.name ?? 'News',
          timeLabel: timeago.format(post.displayTime),
          onTap: () => context.push('/article/${post.id}'),
        );
      },
    );
  }
}

void openFeedSearch(BuildContext context) {
  final provider = context.read<NewsProvider>();
  showSearch(context: context, delegate: FeedSearchDelegate(provider));
}
