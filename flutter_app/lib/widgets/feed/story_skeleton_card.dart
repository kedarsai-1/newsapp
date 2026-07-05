import 'package:flutter/material.dart';

import '../news_shimmer_loader.dart';
import 'feed_xpresso_theme.dart';

/// Loading state skeleton matching StoryPageCard layout.
class StorySkeletonCard extends StatelessWidget {
  const StorySkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Shimmer image placeholder ─────────────────────────────────────
        Container(
          color: fx.surface,
          child: NewsShimmerLoader.greyBox(context,
              width: double.infinity,
              height: double.infinity,
              radius: 0),
        ),

        // ── Gradient scrim ────────────────────────────────────────────────
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x10000000),
                  Color(0x28000000),
                  Color(0x5A000000),
                  Color(0x89000000),
                ],
                stops: const [0.0, 0.1, 0.45, 1.0],
              ),
            ),
          ),
        ),

        // ── Skeleton content ──────────────────────────────────────────────
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 56), // AppBar height
              // Source + time placeholder
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: NewsShimmerLoader.greyBox(
                        context,
                        width: 0.45,
                        height: 18,
                        radius: 4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    NewsShimmerLoader.greyBox(
                      context,
                      width: 0.2,
                      height: 18,
                      radius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Expandable content at bottom
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Headline shimmer
                    NewsShimmerLoader.greyBox(
                      context,
                      width: 0.8,
                      height: 40,
                      radius: 0,
                    ),
                    const SizedBox(height: 10),
                    NewsShimmerLoader.greyBox(
                      context,
                      width: 0.65,
                      height: 40,
                      radius: 0,
                    ),
                    const SizedBox(height: 10),
                    NewsShimmerLoader.greyBox(
                      context,
                      width: 0.4,
                      height: 40,
                      radius: 0,
                    ),
                    const SizedBox(height: 20),
                    // Summary shimmer
                    NewsShimmerLoader.greyBox(
                      context,
                      width: 0.9,
                      height: 18,
                      radius: 0,
                    ),
                    const SizedBox(height: 10),
                    NewsShimmerLoader.greyBox(
                      context,
                      width: 0.7,
                      height: 18,
                      radius: 0,
                    ),
                    const SizedBox(height: 10),
                    NewsShimmerLoader.greyBox(
                      context,
                      width: 0.6,
                      height: 18,
                      radius: 0,
                    ),
                    const SizedBox(height: 10),
                    NewsShimmerLoader.greyBox(
                      context,
                      width: 0.5,
                      height: 18,
                      radius: 0,
                    ),
                    const SizedBox(height: 20),
                    // Action buttons shimmer
                    Row(
                      children: [
                        NewsShimmerLoader.greyBox(
                          context,
                          width: 44,
                          height: 44,
                          radius: 22,
                        ),
                        const SizedBox(width: 16),
                        NewsShimmerLoader.greyBox(
                          context,
                          width: 44,
                          height: 44,
                          radius: 22,
                        ),
                        const SizedBox(width: 16),
                        NewsShimmerLoader.greyBox(
                          context,
                          width: 44,
                          height: 44,
                          radius: 22,
                        ),
                        const SizedBox(width: 16),
                        NewsShimmerLoader.greyBox(
                          context,
                          width: 44,
                          height: 44,
                          radius: 22,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

}
