import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/dailyhunt/xpresso_sliver_app_bar.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';
import '../../widgets/saved/dailyhunt_saved_article_tile.dart';
import '../../widgets/saved/dailyhunt_saved_list_shimmer.dart';

/// Dailyhunt-style saved list: white cards, thumbnails, remove bookmark, empty states.
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<NewsPost> _bookmarks = [];
  bool _loading = true;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (!loggedIn) {
      final guest = await ApiService.getGuestBookmarks();
      if (!mounted) return;
      setState(() {
        _bookmarks = guest;
        _loading = false;
      });
      return;
    }

    final res = await ApiService.getBookmarks();
    if (!mounted) return;
    setState(() {
      if (res['success'] == true) {
        _bookmarks = (res['bookmarks'] as List)
            .map((p) => NewsPost.fromJson(p))
            .toList();
      }
      _loading = false;
    });
  }

  Future<void> _remove(NewsPost post) async {
    final messenger = ScaffoldMessenger.of(context);
    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (loggedIn) {
      final res = await ApiService.toggleBookmark(post.id);
      if (!mounted) return;
      if (res['success'] != true) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Could not update saved'),
            behavior: SnackBarBehavior.floating,
            width: 360,
          ),
        );
        return;
      }
    } else {
      await ApiService.toggleGuestBookmark(post);
    }
    if (!mounted) return;
    setState(() {
      _bookmarks.removeWhere((p) => p.id == post.id);
      if (_selectedCategoryId != null &&
          _bookmarks.every((p) => p.category?.id != _selectedCategoryId)) {
        _selectedCategoryId = null;
      }
    });
  }

  List<NewsPost> get _filtered {
    if (_selectedCategoryId == null) return _bookmarks;
    return _bookmarks
        .where((p) => p.category?.id == _selectedCategoryId)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final horizontal = w >= 720 ? 20.0 : 14.0;
    final bottomInset = FeedXpressoTheme.feedBottomInset(context);

    return Scaffold(
      backgroundColor: FeedXpressoTheme.background,
      body: RefreshIndicator(
        color: FeedXpressoTheme.iconFg,
        backgroundColor: FeedXpressoTheme.background,
        edgeOffset: 8,
        onRefresh: _load,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              slivers: [
                const XpressoSliverAppBar(title: 'Saved'),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 12),
                          child: Text(
                            'Articles you bookmarked appear here. Tap to read or remove.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                          ),
                        ),
                      ),
                      if (_loading)
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 24),
                          sliver: const SliverToBoxAdapter(
                            child: DailyhuntSavedListShimmer(itemCount: 7),
                          ),
                        )
                      else if (_bookmarks.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyState(
                            icon: Icons.bookmark_border_rounded,
                            title: 'No saved articles yet',
                            subtitle:
                                'Save stories from the feed or Shorts with the bookmark button.',
                            dark: true,
                          ),
                        )
                      else ...[
                        if (_distinctCategories.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 10),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const ClampingScrollPhysics(),
                                child: Row(
                                  children: [
                                    _SavedFilterChip(
                                      label: 'All',
                                      selected: _selectedCategoryId == null,
                                      onTap: () =>
                                          setState(() => _selectedCategoryId = null),
                                    ),
                                    const SizedBox(width: 8),
                                    ..._distinctCategories.map((cat) {
                                      final selected =
                                          _selectedCategoryId == cat.id;
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: _SavedFilterChip(
                                          label: '${cat.icon} ${cat.name}',
                                          selected: selected,
                                          onTap: () => setState(
                                            () => _selectedCategoryId = cat.id,
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (_filtered.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyState(
                              icon: Icons.filter_alt_off_rounded,
                              title: 'Nothing in this topic',
                              subtitle: 'Try “All” or pick another category.',
                              dark: true,
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              horizontal,
                              0,
                              horizontal,
                              bottomInset,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final post = _filtered[index];
                                  return DailyhuntSavedArticleTile(
                                      key: ValueKey('saved-${post.id}'),
                                      post: post,
                                      onTap: () =>
                                          context.push('/article/${post.id}'),
                                      onRemove: () => _remove(post),
                                    );
                                },
                                childCount: _filtered.length,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  List<Category> get _distinctCategories {
    final map = <String, Category>{};
    for (final b in _bookmarks) {
      final c = b.category;
      if (c != null) map[c.id] = c;
    }
    return map.values.toList();
  }
}

class _SavedFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SavedFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: selected ? FeedXpressoTheme.title : FeedXpressoTheme.summary,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: FeedXpressoTheme.iconSurface,
      backgroundColor: FeedXpressoTheme.surface,
      side: const BorderSide(color: FeedXpressoTheme.divider, width: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}
