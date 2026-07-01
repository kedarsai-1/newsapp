import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';
import '../../widgets/premium_news_ui.dart';

enum _ViewMode { list, grid }

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<NewsPost> _bookmarks = [];
  bool _loading = true;
  String? _selectedCategoryId;
  _ViewMode _viewMode = _ViewMode.list;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    final bookmarks = res['success'] == true
        ? (res['bookmarks'] as List).map((p) => NewsPost.fromJson(p)).toList()
        : <NewsPost>[];
    context.read<NewsProvider>().setSavedCount(bookmarks.length);
    setState(() {
      _bookmarks = bookmarks;
      _loading = false;
    });
  }

  Future<void> _remove(NewsPost post) async {
    HapticFeedback.lightImpact();
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
      context.read<NewsProvider>().setSavedCount(_bookmarks.length);
      if (_selectedCategoryId != null &&
          _bookmarks.every((p) => p.category?.id != _selectedCategoryId)) {
        _selectedCategoryId = null;
      }
    });
  }

  Future<void> _removeSelected() async {
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final toRemove = _selectedIds.toList();
    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    int removed = 0;

    for (final id in toRemove) {
      final matches = _bookmarks.where((p) => p.id == id);
      if (matches.isEmpty) continue;
      final post = matches.first;
      if (loggedIn) {
        await ApiService.toggleBookmark(id);
      } else {
        await ApiService.toggleGuestBookmark(post);
      }
      removed++;
    }

    if (!mounted) return;
    setState(() {
      _bookmarks.removeWhere((p) => _selectedIds.contains(p.id));
      context.read<NewsProvider>().setSavedCount(_bookmarks.length);
      _selectedIds.clear();
      _selectMode = false;
    });

    messenger.showSnackBar(
      SnackBar(
        content: Text('Removed $removed saved article${removed == 1 ? '' : 's'}'),
        behavior: SnackBarBehavior.floating,
        width: 280,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: _load,
        ),
      ),
    );
  }

  List<NewsPost> get _filtered {
    var posts = _selectedCategoryId == null ? _bookmarks : _bookmarks
        .where((p) => p.category?.id == _selectedCategoryId)
        .toList();

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      posts = posts.where((p) =>
          p.title.toLowerCase().contains(q) ||
          p.displaySourceName.toLowerCase().contains(q)).toList();
    }
    return posts;
  }

  List<Category> get _distinctCategories {
    final map = <String, Category>{};
    for (final b in _bookmarks) {
      final c = b.category;
      if (c != null) map[c.id] = c;
    }
    return map.values.toList();
  }

  Map<String, List<NewsPost>> _groupByDate(List<NewsPost> posts) {
    final now = DateTime.now();
    final groups = <String, List<NewsPost>>{};
    for (final post in posts) {
      final diff = now.difference(post.displayTime);
      String key;
      if (diff.inMinutes < 60 && post.displayTime.day == now.day &&
          post.displayTime.month == now.month && post.displayTime.year == now.year) {
        key = 'Today';
      } else if ((diff.inHours < 48 && post.displayTime.day == now.day - 1) ||
          (now.day == 1 && _isYesterday(post.displayTime, now))) {
        key = 'Yesterday';
      } else if (diff.inDays < 7) {
        key = 'This Week';
      } else {
        key = 'Older';
      }
      groups.putIfAbsent(key, () => []).add(post);
    }
    return groups;
  }

  bool _isYesterday(DateTime dt, DateTime now) {
    final yesterday = now.subtract(const Duration(days: 1));
    return dt.day == yesterday.day &&
           dt.month == yesterday.month &&
           dt.year == yesterday.year;
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIds.addAll(_filtered.map((p) => p.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final w = MediaQuery.sizeOf(context).width;
    final horizontal = w >= 720 ? 20.0 : 14.0;
    final bottomInset = FeedXpressoTheme.feedBottomInset(context);

    return Scaffold(
      backgroundColor: fx.background,
      body: RefreshIndicator(
        color: fx.accent,
        backgroundColor: fx.background,
        edgeOffset: 8,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── App Bar ────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              toolbarHeight: _selectMode ? 56 : 52,
              backgroundColor: fx.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              foregroundColor: fx.title,
              leading: _selectMode
                  ? Semantics(
                      label: 'Exit selection mode',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          _selectMode = false;
                          _selectedIds.clear();
                        }),
                      ),
                    )
                  : null,
              title: _selectMode
                  ? Text(
                      '${_selectedIds.length} selected',
                      style: GoogleFonts.notoSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: fx.title,
                      ),
                    )
                  : Text(
                      'Saved',
                      style: GoogleFonts.notoSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: fx.title,
                      ),
                    ),
              actions: _selectMode
                  ? [
                      Semantics(
                        label: 'Select all articles',
                        button: true,
                        child: IconButton(
                          icon: const Icon(Icons.select_all_rounded),
                          tooltip: 'Select all',
                          onPressed: _selectAll,
                        ),
                      ),
                      Semantics(
                        label: 'Remove selected articles',
                        button: true,
                        child: IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: fx.error),
                          tooltip: 'Remove selected',
                          onPressed: _selectedIds.isNotEmpty ? _removeSelected : null,
                        ),
                      ),
                    ]
                  : [
                      Semantics(
                        label: _viewMode == _ViewMode.list ? 'Switch to grid view' : 'Switch to list view',
                        button: true,
                        child: IconButton(
                          icon: Icon(
                            _viewMode == _ViewMode.list
                                ? Icons.grid_view_rounded
                                : Icons.view_list_rounded,
                            color: fx.iconFg,
                          ),
                          tooltip: _viewMode == _ViewMode.list ? 'Grid view' : 'List view',
                          onPressed: () => setState(() {
                            _viewMode = _viewMode == _ViewMode.list
                                ? _ViewMode.grid
                                : _ViewMode.list;
                          }),
                        ),
                      ),
                    ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(height: 1, thickness: 1, color: fx.divider),
              ),
            ),

            // ── Hero Stats Banner ──────────────────────────────────
            if (!_selectMode && !_loading && _bookmarks.isNotEmpty)
              SliverToBoxAdapter(
                child: _HeroBanner(
                  count: _bookmarks.length,
                  fx: fx,
                  categoryCount: _distinctCategories.length,
                ),
              ),

            // ── Search Bar ─────────────────────────────────────────
            if (!_selectMode && !_loading && _bookmarks.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: fx.glassSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: fx.glassBorder, width: 1),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: GoogleFonts.notoSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: fx.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search saved articles...',
                        hintStyle: GoogleFonts.notoSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: fx.textTertiary,
                        ),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: fx.textTertiary, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? Semantics(
                                label: 'Clear search',
                                button: true,
                                child: IconButton(
                                  icon: Icon(Icons.close_rounded,
                                      color: fx.textTertiary, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Category Filter Chips ──────────────────────────────
            if (!_selectMode && !_loading && _distinctCategories.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 0),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _FilterChip(
                        label: 'All',
                        emoji: '📋',
                        selected: _selectedCategoryId == null,
                        onTap: () => setState(() => _selectedCategoryId = null),
                        fx: fx,
                      ),
                      const SizedBox(width: 8),
                      ..._distinctCategories.map((cat) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _FilterChip(
                              label: cat.name,
                              emoji: cat.icon,
                              selected: _selectedCategoryId == cat.id,
                              onTap: () =>
                                  setState(() => _selectedCategoryId = cat.id),
                              fx: fx,
                            ),
                          )),
                    ],
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 8)),

            // ── Loading State ──────────────────────────────────────
            if (_loading)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 24),
                sliver: SliverToBoxAdapter(
                  child: _LoadingShimmer(count: 6, fx: fx),
                ),
              )

            // ── Empty State ─────────────────────────────────────────
            else if (_bookmarks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  fx: fx,
                  onExplore: () => context.go('/feed'),
                ),
              )

            // ── Filtered Empty ──────────────────────────────────────
            else if (_filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _FilteredEmpty(fx: fx),
              )

            // ── Article Lists ────────────────────────────────────────
            else if (_viewMode == _ViewMode.list ||
                (_searchQuery.isNotEmpty || _selectedCategoryId != null))
              ..._buildGroupedList(horizontal, bottomInset, fx)

            // ── Grid ────────────────────────────────────────────────
            else
              ..._buildGrid(horizontal, bottomInset, fx),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedList(double horizontal, double bottomInset, dynamic fx) {
    final groups = _groupByDate(_filtered);
    final sectionOrder = ['Today', 'Yesterday', 'This Week', 'Older'];
    final items = <Widget>[];

    for (final section in sectionOrder) {
      final posts = groups[section];
      if (posts == null || posts.isEmpty) continue;

      items.add(
        SliverToBoxAdapter(
          child: _SectionHeader(
            label: section,
            count: posts.length,
            fx: fx,
          ),
        ),
      );

      if (_viewMode == _ViewMode.list) {
        items.add(
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _SavedListTile(
                  post: posts[index],
                  selectMode: _selectMode,
                  selected: _selectedIds.contains(posts[index].id),
                  onTap: () {
                    if (_selectMode) {
                      _toggleSelect(posts[index].id);
                    } else {
                      context.push('/article/${posts[index].id}');
                    }
                  },
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _selectMode = true);
                    _selectedIds.add(posts[index].id);
                  },
                  onRemove: () => _remove(posts[index]),
                  onToggleSelect: () => _toggleSelect(posts[index].id),
                  fx: fx,
                ),
                childCount: posts.length,
              ),
            ),
          ),
        );
      } else {
        items.add(
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 8),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width >= 720 ? 3 : 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _SavedGridCard(
                  post: posts[index],
                  selectMode: _selectMode,
                  selected: _selectedIds.contains(posts[index].id),
                  onTap: () {
                    if (_selectMode) {
                      _toggleSelect(posts[index].id);
                    } else {
                      context.push('/article/${posts[index].id}');
                    }
                  },
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _selectMode = true);
                    _selectedIds.add(posts[index].id);
                  },
                  onRemove: () => _remove(posts[index]),
                  fx: fx,
                ),
                childCount: posts.length,
              ),
            ),
          ),
        );
      }
    }

    items.add(SliverToBoxAdapter(
      child: SizedBox(height: bottomInset + 20),
    ));

    return items;
  }

  List<Widget> _buildGrid(double horizontal, double bottomInset, dynamic fx) {
    final groups = _groupByDate(_filtered);
    final sectionOrder = ['Today', 'Yesterday', 'This Week', 'Older'];
    final items = <Widget>[];

    for (final section in sectionOrder) {
      final posts = groups[section];
      if (posts == null || posts.isEmpty) continue;

      items.add(
        SliverToBoxAdapter(
          child: _SectionHeader(
            label: section,
            count: posts.length,
            fx: fx,
          ),
        ),
      );

      items.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 8),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.of(context).size.width >= 720 ? 3 : 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _SavedGridCard(
                post: posts[index],
                selectMode: _selectMode,
                selected: _selectedIds.contains(posts[index].id),
                onTap: () {
                  if (_selectMode) {
                    _toggleSelect(posts[index].id);
                  } else {
                    context.push('/article/${posts[index].id}');
                  }
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  setState(() => _selectMode = true);
                  _selectedIds.add(posts[index].id);
                },
                onRemove: () => _remove(posts[index]),
                fx: fx,
              ),
              childCount: posts.length,
            ),
          ),
        ),
      );
    }

    items.add(SliverToBoxAdapter(
      child: SizedBox(height: bottomInset + 20),
    ));

    return items;
  }
}

// ─── Hero Banner ──────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final int count;
  final int categoryCount;
  final dynamic fx;

  const _HeroBanner({
    required this.count,
    required this.categoryCount,
    required this.fx,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            fx.accent,
            fx.accent.withValues(alpha: 0.65),
            fx.accentTertiary,
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: fx.accent.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(Icons.bookmark_rounded,
                size: 100, color: Colors.white.withValues(alpha: 0.08)),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.bookmark_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count saved article${count == 1 ? '' : 's'}',
                        style: GoogleFonts.notoSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Across $categoryCount topic${categoryCount == 1 ? '' : 's'}',
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withValues(alpha: 0.6), size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;
  final dynamic fx;

  const _FilterChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
    required this.fx,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Filter by ${label.toLowerCase()}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? fx.accent : fx.glassSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? fx.accent : fx.glassBorder,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: fx.accent.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji.isNotEmpty) ...[
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.notoSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : fx.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section Header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  final dynamic fx;

  const _SectionHeader({
    required this.label,
    required this.count,
    required this.fx,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.notoSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: fx.title,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: fx.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.notoSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fx.accent,
              ),
            ),
          ),
          const Spacer(),
          Container(
            width: 20,
            height: 2,
            decoration: BoxDecoration(
              color: fx.divider,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Saved List Tile ──────────────────────────────────────────────────────────

class _SavedListTile extends StatelessWidget {
  final NewsPost post;
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRemove;
  final VoidCallback onToggleSelect;
  final dynamic fx;

  const _SavedListTile({
    required this.post,
    required this.selectMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onRemove,
    required this.onToggleSelect,
    required this.fx,
  });

  @override
  Widget build(BuildContext context) {
    final imgUrl = premiumImageUrl(post);

    return Dismissible(
      key: ValueKey('saved-${post.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: fx.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline_rounded, color: fx.error, size: 24),
      ),
      child: Semantics(
        label: 'Saved article: ${post.title}',
        button: true,
        onDismiss: () => onRemove(),
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: fx.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? fx.accent.withValues(alpha: 0.5)
                  : fx.glassBorder.withValues(alpha: 0.5),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Select checkbox
              if (selectMode)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Semantics(
                    button: true,
                    label: '${selected ? 'Deselect' : 'Select'} article',
                    child: GestureDetector(
                      onTap: onToggleSelect,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: selected ? fx.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? fx.accent : fx.divider,
                          width: 1.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 14)
                          : null,
                    ),
                  ),
                ),
                ),

              // Thumbnail
              if (imgUrl?.isNotEmpty == true)
                Padding(
                  padding: EdgeInsets.only(
                    left: selectMode ? 10 : 4,
                    top: 10,
                    bottom: 10,
                    right: 4,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imgUrl,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 90,
                        height: 90,
                        color: fx.imagePlaceholder,
                        child: Icon(Icons.image_rounded,
                            color: fx.iconFgMuted, size: 28),
                      ),
                    ),
                  ),
                ),

              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: imgUrl != null ? 12 : 14,
                    right: 4,
                    top: 12,
                    bottom: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category badge
                      if (post.category != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: fx.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            post.category!.name,
                            style: GoogleFonts.notoSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: fx.accent,
                            ),
                          ),
                        ),
                      Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.notoSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: fx.title,
                          height: 1.35,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            post.displaySourceName,
                            style: GoogleFonts.notoSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: fx.textTertiary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('·',
                              style: TextStyle(color: fx.textTertiary, fontSize: 11)),
                          const SizedBox(width: 4),
                          Text(
                            timeago.format(post.displayTime),
                            style: GoogleFonts.notoSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: fx.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Remove button
              if (!selectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Semantics(
                    label: 'Remove saved article',
                    button: true,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: 'Remove',
                      onPressed: onRemove,
                      icon: Icon(
                        Icons.bookmark_remove_rounded,
                        size: 20,
                        color: fx.iconFgMuted,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// ─── Saved Grid Card ─────────────────────────────────────────────────────────

class _SavedGridCard extends StatelessWidget {
  final NewsPost post;
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onRemove;
  final dynamic fx;

  const _SavedGridCard({
    required this.post,
    required this.selectMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onRemove,
    required this.fx,
  });

  @override
  Widget build(BuildContext context) {
    final imgUrl = premiumImageUrl(post);
    final accent = fx.accent;

    return Semantics(
      label: 'Saved article: ${post.title}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
        decoration: BoxDecoration(
          color: fx.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.6)
                : fx.glassBorder.withValues(alpha: 0.5),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? accent.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: selected ? 12 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Image
            if (imgUrl != null && imgUrl.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  imgUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: fx.imagePlaceholder,
                    child: Icon(Icons.image_rounded,
                        color: fx.iconFgMuted, size: 36),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Container(color: fx.imagePlaceholder),
              ),

            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.02),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.3, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            // Category
            if (post.category != null)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    post.category!.name,
                    style: GoogleFonts.notoSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // Select indicator
            if (selectMode)
              Positioned(
                top: 8,
                right: 8,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? accent : Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? accent : Colors.white.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 14)
                      : null,
                ),
              ),

            // Bottom content
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${post.displaySourceName} · ${timeago.format(post.displayTime)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                      if (!selectMode)
                        Semantics(
                          label: 'Remove saved article',
                          button: true,
                          child: GestureDetector(
                            onTap: onRemove,
                            child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.bookmark_remove_rounded,
                                color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ─── Empty States ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final dynamic fx;
  final VoidCallback onExplore;

  const _EmptyState({required this.fx, required this.onExplore});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    fx.accent.withValues(alpha: 0.15),
                    fx.accentTertiary.withValues(alpha: 0.15),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bookmark_border_rounded,
                  size: 48, color: fx.accent.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 24),
            Text(
              'No saved articles yet',
              style: GoogleFonts.notoSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: fx.title,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Save stories from the feed or Shorts\nwith the bookmark button.',
              style: GoogleFonts.notoSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: fx.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Semantics(
              label: 'Explore feed',
              button: true,
              child: GestureDetector(
                onTap: onExplore,
                child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [fx.accent, fx.accentTertiary],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: fx.accent.withValues(alpha: 0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.explore_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Explore Feed',
                      style: GoogleFonts.notoSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredEmpty extends StatelessWidget {
  final dynamic fx;

  const _FilteredEmpty({required this.fx});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_alt_off_rounded,
                size: 52, color: fx.textTertiary),
            const SizedBox(height: 20),
            Text(
              'Nothing in this topic',
              style: GoogleFonts.notoSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: fx.title,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try "All" or pick another category.',
              style: GoogleFonts.notoSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: fx.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading Shimmer ─────────────────────────────────────────────────────────

class _LoadingShimmer extends StatelessWidget {
  final int count;
  final dynamic fx;

  const _LoadingShimmer({required this.count, required this.fx});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: fx.glassSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 90,
                decoration: BoxDecoration(
                  color: fx.imagePlaceholder,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 10,
                        width: 50,
                        decoration: BoxDecoration(
                          color: fx.imagePlaceholder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: fx.imagePlaceholder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 12,
                        width: 180,
                        decoration: BoxDecoration(
                          color: fx.imagePlaceholder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: 100,
                        decoration: BoxDecoration(
                          color: fx.imagePlaceholder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}
