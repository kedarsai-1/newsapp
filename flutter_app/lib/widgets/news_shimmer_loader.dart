import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../widgets/feed/feed_xpresso_theme.dart';

/// Dailyhunt-style feed shimmer — image block, headline lines, meta + action row.
class NewsShimmerLoader extends StatelessWidget {
  final int count;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  const NewsShimmerLoader({
    super.key,
    this.count = 8,
    this.shrinkWrap = false,
    this.physics,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final bg = backgroundColor ?? fx.background;
    return ColoredBox(
      color: bg,
      child: ListView.builder(
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap
            ? const NeverScrollableScrollPhysics()
            : (physics ?? const ClampingScrollPhysics()),
        padding: padding,
        itemCount: count,
        itemBuilder: (_, __) => _DailyhuntRowSkeleton(fx: fx),
      ),
    );
  }

  static Widget greyBox(
    BuildContext context, {
    required double width,
    required double height,
    double radius = 3,
  }) {
    final fx = FeedXpressoTheme.fx(context);
    return Shimmer.fromColors(
      baseColor: fx.shimmerBase,
      highlightColor: fx.shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: fx.shimmerBase,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _DailyhuntRowSkeleton extends StatelessWidget {
  final FeedXpressoPalette fx;

  const _DailyhuntRowSkeleton({required this.fx});

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    return Shimmer.fromColors(
      baseColor: fx.shimmerBase,
      highlightColor: fx.shimmerHighlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: FeedXpressoTheme.cardMargin,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: FeedXpressoTheme.imageBorderRadius,
                  child: AspectRatio(
                    aspectRatio: FeedXpressoTheme.imageAspectRatio,
                    child: ColoredBox(color: fx.shimmerBase),
                  ),
                ),
                SizedBox(height: FeedXpressoTheme.imageToTitleGap),
                Container(height: 12, width: double.infinity, color: fx.shimmerBase),
                SizedBox(height: 7),
                Container(height: 12, width: double.infinity, color: fx.shimmerBase),
                SizedBox(height: 7),
                FractionallySizedBox(
                  widthFactor: 0.72,
                  alignment: Alignment.centerLeft,
                  child: Container(height: 12, color: fx.shimmerBase),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Container(height: 10, width: 88, color: fx.shimmerBase),
                    const Spacer(),
                    Container(height: 14, width: 14, color: fx.shimmerBase),
                    SizedBox(width: 18),
                    Container(height: 14, width: 14, color: fx.shimmerBase),
                    SizedBox(width: 18),
                    Container(height: 14, width: 4, color: fx.shimmerBase),
                  ],
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            indent: 12,
            endIndent: 12,
            color: fx.divider,
          ),
        ],
      ),
    );
  }
}
