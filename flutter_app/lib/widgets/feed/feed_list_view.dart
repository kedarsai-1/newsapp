import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../premium_animations.dart';
import 'dailyhunt_feed_article_card.dart';
import 'feed_image_cache.dart';
import 'feed_list_tuning.dart';
import 'feed_xpresso_theme.dart';

/// Scrollable feed list — isolated from [NewsProvider] rebuilds above the list.
class FeedListView extends StatefulWidget {
  final List<NewsPost> posts;
  final bool loadingMore;
  final double bottomInset;
  final ScrollController scrollController;
  final Map<String, bool> likedByPostId;
  final Map<String, bool> bookmarkedByPostId;
  final Future<void> Function() onRefresh;
  final Future<bool> Function(NewsPost) onLike;
  final Future<bool> Function(NewsPost) onBookmark;
  final void Function(NewsPost) onShare;
  final void Function(NewsPost) onOpen;

  const FeedListView({
    super.key,
    required this.posts,
    required this.loadingMore,
    required this.bottomInset,
    required this.scrollController,
    required this.likedByPostId,
    required this.bookmarkedByPostId,
    required this.onRefresh,
    required this.onLike,
    required this.onBookmark,
    required this.onShare,
    required this.onOpen,
  });

  @override
  State<FeedListView> createState() => _FeedListViewState();
}

class _FeedListViewState extends State<FeedListView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final itemCount = widget.posts.length + (widget.loadingMore ? 1 : 0);

    final fx = FeedXpressoTheme.fx(context);
    return ColoredBox(
      color: fx.background,
      child: FeedListTuning.clampingScroll(
        child: RefreshIndicator(
          color: fx.iconFg,
          backgroundColor: fx.background,
          onRefresh: widget.onRefresh,
          child: ListView.builder(
          controller: widget.scrollController,
          physics: FeedListTuning.scrollPhysics,
          cacheExtent: FeedListTuning.cacheExtent,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false,
          padding: FeedListTuning.listPadding.copyWith(bottom: widget.bottomInset),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index >= widget.posts.length) {
              return const FeedListLoadingFooter();
            }
            final post = widget.posts[index];
            return StaggeredEntranceAnimation(
              index: index.clamp(0, 6),
              child: DailyhuntFeedArticleCard(
                key: ValueKey(post.id),
                post: post,
                liked: widget.likedByPostId[post.id] ?? false,
                saved: widget.bookmarkedByPostId[post.id] ?? false,
                onOpen: () => widget.onOpen(post),
                onLike: () => widget.onLike(post),
                onShare: () => widget.onShare(post),
                onBookmark: () => widget.onBookmark(post),
              ),
            );
          },
          ),
        ),
      ),
    );
  }
}

/// Lightweight snapshot for [Selector] — avoids rebuilding chrome on scroll/load ticks.
class FeedListSnapshot {
  final List<NewsPost> posts;
  final String? error;
  final bool refreshing;
  final bool loading;
  final bool hasMore;

  const FeedListSnapshot({
    required this.posts,
    required this.error,
    required this.refreshing,
    required this.loading,
    required this.hasMore,
  });

  @override
  bool operator ==(Object other) {
    return other is FeedListSnapshot &&
        identical(posts, other.posts) &&
        error == other.error &&
        refreshing == other.refreshing &&
        loading == other.loading &&
        hasMore == other.hasMore;
  }

  @override
  int get hashCode => Object.hash(posts, error, refreshing, loading, hasMore);
}

FeedListSnapshot readFeedListSnapshot(NewsProvider provider) {
  return FeedListSnapshot(
    posts: provider.posts,
    error: provider.error,
    refreshing: provider.refreshing,
    loading: provider.loading,
    hasMore: provider.hasMore,
  );
}

void scheduleFeedImagePrecache(
  BuildContext context,
  List<NewsPost> posts,
  ScrollController controller,
) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted || !controller.hasClients || posts.isEmpty) return;
    FeedImagePrecache.onScroll(context, posts, controller.position);
  });
}
