import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Dailyhunt-style feed skeleton: fixed grey shimmer (#E0E0E0 / #F5F5F5), dense rows.
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
    this.padding = const EdgeInsets.only(bottom: 8),
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
            : (physics ?? const BouncingScrollPhysics()),
        padding: padding,
        itemCount: count,
        itemBuilder: (_, __) => const _FeedRowSkeleton(),
      ),
    );
  }

  /// Minimal grey blocks (top bar / chips). Uses same shimmer greys.
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
  static const Color _highlight = Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Shimmer.fromColors(
        baseColor: _base,
        highlightColor: _highlight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _base,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 13,
                        decoration: BoxDecoration(
                          color: _base,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        height: 13,
                        decoration: BoxDecoration(
                          color: _base,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: w * 0.72,
                        height: 11,
                        decoration: BoxDecoration(
                          color: _base,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: w * 0.42,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _base,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
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
