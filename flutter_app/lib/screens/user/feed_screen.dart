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
import '../../widgets/feed/dailyhunt_feed_article_card.dart';
import '../../widgets/feed/dailyhunt_feed_skeleton.dart';
import '../../widgets/feed/feed_image_cache.dart';
import '../../widgets/feed/feed_list_tuning.dart';
import '../../widgets/premium_news_ui.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedListBody extends StatefulWidget {
  final NewsProvider provider;
  final double bottomInset;
  final Map<String, bool> likedByPostId;
  final Map<String, bool> bookmarkedByPostId;
  final Future<void> Function() onRefresh;
  final ScrollController scrollController;
  final Future<bool> Function(NewsPost) onLike;
  final Future<bool> Function(NewsPost) onBookmark;
  final void Function(NewsPost) onShare;

  const _FeedListBody({
    required this.provider,
    required this.bottomInset,
    required this.likedByPostId,
    required this.bookmarkedByPostId,
    required this.onRefresh,
    required this.scrollController,
    required this.onLike,
    required this.onBookmark,
    required this.onShare,
  });

  @override
  State<_FeedListBody> createState() => _FeedListBodyState();
}

class _FeedListBodyState extends State<_FeedListBody>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = widget.provider;
    final extra = provider.loading && provider.hasMore ? 1 : 0;

    return RefreshIndicator(
      color: DailyhuntTheme.accentGreen,
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: widget.scrollController,
        physics: FeedListTuning.scrollPhysics,
        cacheExtent: FeedListTuning.cacheExtent,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        padding: FeedListTuning.listPadding.copyWith(bottom: widget.bottomInset),
        itemCount: provider.posts.length + extra,
        itemBuilder: (context, index) {
          if (index >= provider.posts.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final post = provider.posts[index];
          return DailyhuntFeedArticleCard(
            key: ValueKey(post.id),
            post: post,
            liked: widget.likedByPostId[post.id] ?? false,
            saved: widget.bookmarkedByPostId[post.id] ?? false,
            onTap: () => context.push('/article/${post.id}'),
            onLike: () => widget.onLike(post),
            onShare: () => widget.onShare(post),
            onBookmark: () => widget.onBookmark(post),
          );
        },
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsProvider>();
    final bottomInset = MediaQuery.paddingOf(context).bottom + 72;
    final chipIndex = _chipIndexForProvider(provider);

    return Theme(
      data: DailyhuntTheme.overlay(context),
      child: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return Scaffold(
            backgroundColor: Colors.white,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RepaintBoundary(
                  child: _DailyhuntFeedAppBar(colorScheme: cs),
                ),
                RepaintBoundary(
                  child: _CategoryChipStrip(
                    selectedIndex: chipIndex,
                    onSelect: _selectCategoryChip,
                  ),
                ),
                Expanded(
                  child: _buildBody(provider, bottomInset, cs),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(NewsProvider provider, double bottomInset, ColorScheme cs) {
    if (provider.error != null) {
      return ErrorState(message: provider.error!, onRetry: provider.refresh);
    }
    if (provider.posts.isEmpty && provider.refreshing) {
      FeedImagePrecache.reset();
      return const DailyhuntFeedSkeleton(rowCount: 10);
    }
    if (provider.posts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        FeedImagePrecache.onScroll(
          context,
          provider.posts,
          _scrollController.position,
        );
      });
    }
    if (provider.posts.isEmpty) {
      return const EmptyState(
        icon: Icons.article_outlined,
        title: 'No stories yet',
        subtitle: 'Pull down to refresh or pick another category.',
      );
    }

    return _FeedListBody(
      provider: provider,
      bottomInset: bottomInset,
      likedByPostId: _likedByPostId,
      bookmarkedByPostId: _bookmarkedByPostId,
      scrollController: _scrollController,
      onRefresh: () async {
        await provider.refresh();
        _scrollFeedToTop();
      },
      onLike: _toggleLike,
      onBookmark: _toggleBookmark,
      onShare: _share,
    );
  }
}

class _DailyhuntFeedAppBar extends StatelessWidget {
  final ColorScheme colorScheme;

  const _DailyhuntFeedAppBar({required this.colorScheme});

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
                  icon: CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFE8EAED),
                    child: Icon(
                      Icons.person_rounded,
                      size: 20,
                      color: colorScheme.onSurface.withValues(alpha: 0.75),
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
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            letterSpacing: -0.4,
                            color: colorScheme.onSurface,
                          ),
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
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: colorScheme.onSurface.withValues(alpha: 0.75),
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

class _CategoryChipStrip extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _CategoryChipStrip({
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: _kFeedTabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final selected = i == selectedIndex;
            final label = _kFeedTabs[i].$1;
            return Center(
              child: Material(
                color: selected
                    ? DailyhuntTheme.accentGreen.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () => onSelect(i),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected
                            ? DailyhuntTheme.accentGreen
                            : const Color(0xFF5F6368),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
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
