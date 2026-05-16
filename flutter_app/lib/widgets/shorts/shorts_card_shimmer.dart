import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'shorts_feed_theme.dart';

/// Card-shaped shimmer for Shorts loading state.
class ShortsCardShimmer extends StatelessWidget {
  final double topInset;

  const ShortsCardShimmer({super.key, this.topInset = 108});

  @override
  Widget build(BuildContext context) {
    const base = Color(0xFF141414);
    const highlight = Color(0xFF1E1E1E);
    return ColoredBox(
      color: ShortsFeedTheme.background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          ShortsFeedTheme.pageHPad,
          topInset,
          ShortsFeedTheme.pageHPad,
          100,
        ),
        child: Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: ShortsFeedTheme.card,
              borderRadius: BorderRadius.circular(ShortsFeedTheme.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Container(color: base),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: double.infinity,
                        color: base,
                      ),
                      const SizedBox(height: 8),
                      Container(height: 14, width: 220, color: base),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: base,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(height: 12, width: 120, color: base),
                                const SizedBox(height: 6),
                                Container(height: 10, width: 80, color: base),
                              ],
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
      ),
    );
  }
}
