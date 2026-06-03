import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'feed/feed_xpresso_theme.dart';

/// Premium glassmorphic feed shimmer loader — matches GlassSportsArticleCard boundaries.
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
    return ColoredBox(
      color: backgroundColor ?? Colors.transparent, // Default to transparent so blobs show through
      child: ListView.builder(
        shrinkWrap: shrinkWrap,
        physics: shrinkWrap
            ? const NeverScrollableScrollPhysics()
            : (physics ?? const BouncingScrollPhysics()),
        padding: padding,
        itemCount: count,
        itemBuilder: (_, __) => const _GlassRowSkeleton(),
      ),
    );
  }

  static Widget greyBox(
    BuildContext context, {
    required double width,
    required double height,
    double radius = 3,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06);
    final highlightColor = isDark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.10);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class _GlassRowSkeleton extends StatelessWidget {
  const _GlassRowSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);
    final highlightColor = isDark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.09);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 0.8,
        ),
      ),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1.88,
                child: Container(
                  color: baseColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Title placeholder lines
            Container(height: 12, width: double.infinity, color: baseColor),
            const SizedBox(height: 7),
            Container(height: 12, width: double.infinity, color: baseColor),
            const SizedBox(height: 7),
            FractionallySizedBox(
              widthFactor: 0.72,
              alignment: Alignment.centerLeft,
              child: Container(height: 12, color: baseColor),
            ),
            const SizedBox(height: 14),
            // Footer placeholder row
            Row(
              children: [
                Container(height: 10, width: 88, color: baseColor),
                const Spacer(),
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
