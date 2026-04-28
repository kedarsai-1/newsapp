import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../constants.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/news_shimmer_loader.dart';
import '../../widgets/premium_news_ui.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<NewsPost> _bookmarks = [];
  bool _loading = true;
  bool _gridView = false;
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (loggedIn) {
      final res = await ApiService.toggleBookmark(post.id);
      if (res['success'] != true) return;
    } else {
      await ApiService.toggleGuestBookmark(post);
    }
    if (!mounted) return;
    setState(() => _bookmarks.removeWhere((p) => p.id == post.id));
  }

  List<NewsPost> get _filtered {
    if (_selectedCategoryId == null) return _bookmarks;
    return _bookmarks
        .where((p) => p.category?.id == _selectedCategoryId)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PremiumScaffold(
      safeArea: true,
      child: RefreshIndicator(
        color: p.primary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Saved News',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: p.textPrimary,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.7,
                                    ),
                              ),
                              Text(
                                'Read anytime, even when offline',
                                style: context.subtitleText.copyWith(
                                  color: p.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PremiumIconButton(
                          icon: AppIcons.search,
                          onTap: () => context.push('/feed'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FrostedPanel(
                      radius: 18,
                      padding: const EdgeInsets.all(10),
                      boxShadow: const [],
                      child: Row(
                        children: [
                          Icon(AppIcons.offline, color: p.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Offline support enabled',
                              style: context.metaText.copyWith(
                                color: p.textSecondary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          SegmentedButton<bool>(
                            showSelectedIcon: false,
                            style: SegmentedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              selectedBackgroundColor:
                                  p.primary.withValues(alpha: 0.22),
                              selectedForegroundColor: p.primary,
                            ),
                            segments: const [
                              ButtonSegment<bool>(
                                value: false,
                                icon: Icon(AppIcons.list, size: 16),
                              ),
                              ButtonSegment<bool>(
                                value: true,
                                icon: Icon(AppIcons.categories, size: 16),
                              ),
                            ],
                            selected: {_gridView},
                            onSelectionChanged: (value) =>
                                setState(() => _gridView = value.first),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: NewsShimmerLoader(count: 5),
              )
            else if (_bookmarks.isEmpty)
              const SliverFillRemaining(
                child: EmptyState(
                  icon: AppIcons.bookmarks,
                  title: 'No saved stories yet',
                  subtitle: 'Double tap bookmark on the news reels to save.',
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  0,
                  18,
                  110 + MediaQuery.of(context).padding.bottom,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterChip(
                                label: 'All',
                                selected: _selectedCategoryId == null,
                                onTap: () =>
                                    setState(() => _selectedCategoryId = null),
                              ),
                              const SizedBox(width: 8),
                              ...{
                                for (final b in _bookmarks)
                                  if (b.category != null)
                                    b.category!.id: b.category!
                              }.values.map((cat) {
                                final selected = _selectedCategoryId == cat.id;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _FilterChip(
                                    label: '${cat.icon} ${cat.name}',
                                    selected: selected,
                                    onTap: () => setState(
                                        () => _selectedCategoryId = cat.id),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _filtered.isEmpty
                            ? const SizedBox(
                                key: ValueKey('empty-filter'),
                                height: 220,
                                child: EmptyState(
                                  icon: AppIcons.empty,
                                  title: 'No saved stories in this category',
                                  subtitle: 'Try another filter.',
                                ),
                              )
                            : _gridView
                                ? GridView.builder(
                                    key: ValueKey(
                                        'grid-${_selectedCategoryId ?? 'all'}-${_filtered.length}'),
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _filtered.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: 0.73,
                                    ),
                                    itemBuilder: (context, index) {
                                      final post = _filtered[index];
                                      return _SavedGridCard(
                                        post: post,
                                        onTap: () =>
                                            context.push('/article/${post.id}'),
                                        onRemove: () => _remove(post),
                                      );
                                    },
                                  )
                                : ListView.builder(
                                    key: ValueKey(
                                        'list-${_selectedCategoryId ?? 'all'}-${_filtered.length}'),
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _filtered.length,
                                    itemBuilder: (context, index) {
                                      final post = _filtered[index];
                                      return Dismissible(
                                        key: ValueKey('saved-${post.id}'),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 10),
                                          alignment: Alignment.centerRight,
                                          padding:
                                              const EdgeInsets.only(right: 18),
                                          decoration: BoxDecoration(
                                            color:
                                                p.error.withValues(alpha: 0.16),
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            border: Border.all(
                                              color: p.error
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ),
                                          child: Icon(Icons.delete_rounded,
                                              color: p.error),
                                        ),
                                        onDismissed: (_) => _remove(post),
                                        child: _SavedListCard(
                                          post: post,
                                          onTap: () => context
                                              .push('/article/${post.id}'),
                                          onRemove: () => _remove(post),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: p.primary.withValues(alpha: 0.2),
      backgroundColor: p.surface.withValues(alpha: 0.52),
      side: BorderSide(color: selected ? p.primary : p.cardBorder),
      labelStyle: TextStyle(
        color: selected ? p.primary : p.textSecondary,
        fontWeight: FontWeight.w800,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

class _SavedListCard extends StatelessWidget {
  final NewsPost post;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SavedListCard({
    required this.post,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final image = premiumImageUrl(post);
    return FrostedPanel(
      radius: 18,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 88,
                height: 88,
                child: image.isEmpty
                    ? ColoredBox(
                        color: p.inputFill,
                        child: Icon(AppIcons.image, color: p.textHint),
                      )
                    : CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => ColoredBox(color: p.inputFill),
                        errorWidget: (_, __, ___) => Icon(
                          Icons.broken_image_rounded,
                          color: p.textHint,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.titleText.copyWith(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post.sourceName ?? post.category?.name ?? 'News',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.metaText.copyWith(color: p.textHint),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(AppIcons.offline, size: 14, color: p.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Offline',
                        style: context.metaText.copyWith(
                          color: p.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            TapScale(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.bookmark_remove_rounded, color: p.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedGridCard extends StatelessWidget {
  final NewsPost post;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _SavedGridCard({
    required this.post,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final image = premiumImageUrl(post);
    return FrostedPanel(
      radius: 18,
      padding: const EdgeInsets.all(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1.24,
                child: image.isEmpty
                    ? ColoredBox(
                        color: p.inputFill,
                        child: Icon(AppIcons.image, color: p.textHint),
                      )
                    : CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => ColoredBox(color: p.inputFill),
                        errorWidget: (_, __, ___) => Icon(
                          Icons.broken_image_rounded,
                          color: p.textHint,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              post.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.titleText.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                height: 1.22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              post.sourceName ?? post.category?.name ?? 'News',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.metaText.copyWith(color: p.textHint),
            ),
            const Spacer(),
            Row(
              children: [
                Icon(AppIcons.offline, size: 13, color: p.primary),
                const SizedBox(width: 4),
                Text(
                  timeago.format(post.createdAt),
                  style: context.metaText.copyWith(color: p.textHint),
                ),
                const Spacer(),
                InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 16, color: p.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
