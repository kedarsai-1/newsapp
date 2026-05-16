import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'feed/feed_xpresso_theme.dart';

/// Editorial feed shimmer — rounded card, image on top, copy below.
class NewsShimmerLoader extends StatelessWidget {
  final int count;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;

  const NewsShimmerLoader({
    super.key,
    this.count = 8,
    this.shrinkWrap = false,
    this.physics,
    this.padding = EdgeInsets.zero,
    this.backgroundColor = FeedXpressoTheme.background,
  });

  static const Color kBase = FeedXpressoTheme.shimmerBase;
  static const Color kHighlight = FeedXpressoTheme.shimmerHighlight;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: ListView.builder(
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap
            ? const NeverScrollableScrollPhysics()
            : (physics ?? const ClampingScrollPhysics()),
        padding: padding,
        itemCount: count,
        itemBuilder: (_, __) => const _EditorialRowSkeleton(),
      ),
    );
  }

  static Widget greyBox({
    required double width,
    required double height,
    double radius = 3,
  }) {
    return Shimmer.fromColors(
      baseColor: kBase,
      highlightColor: kHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: kBase,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _EditorialRowSkeleton extends StatelessWidget {
  const _EditorialRowSkeleton();

  static const Color _base = FeedXpressoTheme.shimmerBase;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: NewsShimmerLoader.kBase,
      highlightColor: NewsShimmerLoader.kHighlight,
      child: Padding(
        padding: FeedXpressoTheme.cardMargin,
        child: ClipRRect(
          borderRadius: FeedXpressoTheme.cardBorderRadius,
          child: ColoredBox(
            color: FeedXpressoTheme.cardSurface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AspectRatio(
                  aspectRatio: FeedXpressoTheme.imageAspectRatio,
                  child: ColoredBox(color: _base),
                ),
                Padding(
                  padding: FeedXpressoTheme.rowContentPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 14, width: double.infinity, color: _base),
                      const SizedBox(height: 5),
                      Container(height: 12, width: double.infinity, color: _base),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: Container(height: 10, color: _base)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: FeedXpressoTheme.actionRowWidth,
                            child: Container(height: 10, color: _base),
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
      ),
    );
  }
}
