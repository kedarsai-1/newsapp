import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'feed/compact_news_row.dart';

/// Dense grey shimmer rows aligned with [CompactNewsRow] sizing.
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
    this.backgroundColor = Colors.white,
  });

  static const Color kBase = Color(0xFFE0E0E0);
  static const Color kHighlight = Color(0xFFF5F5F5);

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
        itemBuilder: (_, __) => const _FeedRowSkeleton(),
      ),
    );
  }

  static Widget greyBox({
    required double width,
    required double height,
    double radius = 4,
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

class _FeedRowSkeleton extends StatelessWidget {
  const _FeedRowSkeleton();

  static const Color _base = Color(0xFFE0E0E0);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Shimmer.fromColors(
        baseColor: _base,
        highlightColor: NewsShimmerLoader.kHighlight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: kFeedThumbSize,
                  height: kFeedThumbSize,
                  decoration: BoxDecoration(
                    color: _base,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _base,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _base,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: 10,
                        width: 100,
                        decoration: BoxDecoration(
                          color: _base,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(height: 1, thickness: 1, color: Color(0xFFEDEDED)),
          ],
        ),
      ),
    );
  }
}
