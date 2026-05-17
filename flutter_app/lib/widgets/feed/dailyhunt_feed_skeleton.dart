import 'package:flutter/material.dart';

import '../news_shimmer_loader.dart';
import 'feed_xpresso_theme.dart';

/// Xpresso feed loading — article card shimmers; optional chrome placeholders.
class DailyhuntFeedSkeleton extends StatelessWidget {
  final int rowCount;

  /// When false, only article rows shimmer (use when app bar + categories are already visible).
  final bool showChrome;

  const DailyhuntFeedSkeleton({
    super.key,
    this.rowCount = 6,
    this.showChrome = false,
  });

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final bottom = FeedXpressoTheme.feedBottomInset(context);
    final listPadding = EdgeInsets.only(
      top: 6,
      bottom: bottom,
    );

    if (!showChrome) {
      return ColoredBox(
        color: fx.background,
        child: NewsShimmerLoader(
          count: rowCount,
          padding: listPadding,
        ),
      );
    }

    return ColoredBox(
      color: fx.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _skeletonAppBar(context),
          _skeletonChipStrip(context),
          Expanded(
            child: NewsShimmerLoader(
              count: rowCount,
              padding: listPadding,
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonAppBar(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return ColoredBox(
      color: fx.background,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                NewsShimmerLoader.greyBox(context, width: 32, height: 32, radius: 16),
                Expanded(
                  child: Center(
                    child: NewsShimmerLoader.greyBox(context, width: 100, height: 14, radius: 3),
                  ),
                ),
                NewsShimmerLoader.greyBox(context, width: 32, height: 32, radius: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _skeletonChipStrip(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return ColoredBox(
      color: fx.background,
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          itemCount: 7,
          separatorBuilder: (_, __) => const SizedBox(width: 4),
          itemBuilder: (_, i) {
            final w = 44.0 + (i % 3) * 14.0;
            return Center(
              child: NewsShimmerLoader.greyBox(context, width: w, height: 12, radius: 2),
            );
          },
        ),
      ),
    );
  }
}
