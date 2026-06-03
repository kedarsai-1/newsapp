import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../feed/feed_xpresso_palette.dart';
import '../feed/feed_xpresso_theme.dart';
import '../news_shimmer_loader.dart';

/// Premium glassmorphic sports hub loading skeleton.
class SportsHomeShimmer extends StatelessWidget {
  const SportsHomeShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
      children: [
        _sectionTitleShimmer(context, width: 130),
        const SizedBox(height: 12),
        SizedBox(
          height: 124,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, _) => _glassLiveCard(context),
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitleShimmer(context, width: 110),
        const SizedBox(height: 12),
        const NewsShimmerLoader(
          count: 3,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
        ),
      ],
    );
  }

  Widget _sectionTitleShimmer(BuildContext context, {required double width}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06);
    final highlightColor = isDark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.10);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: 15,
        alignment: Alignment.centerLeft,
        child: Container(
          width: width,
          height: 15,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _glassLiveCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);
    final highlightColor = isDark ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.09);

    return Container(
      width: 258,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status bullet + Tournament label
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 90, height: 10, color: baseColor),
              ],
            ),
            const SizedBox(height: 14),
            // Team A row
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 75, height: 11, color: baseColor),
                const Spacer(),
                Container(width: 32, height: 12, color: baseColor),
              ],
            ),
            const SizedBox(height: 8),
            // Team B row
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(width: 8),
                Container(width: 85, height: 11, color: baseColor),
                const Spacer(),
                Container(width: 26, height: 12, color: baseColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
