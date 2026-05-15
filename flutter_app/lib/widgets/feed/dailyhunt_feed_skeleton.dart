import 'package:flutter/material.dart';

import '../news_shimmer_loader.dart';

/// Full feed loading chrome: white surface, minimal top bar + chip strip + dense list shimmer.
class DailyhuntFeedSkeleton extends StatelessWidget {
  final int rowCount;

  const DailyhuntFeedSkeleton({super.key, this.rowCount = 10});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 64;
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _skeletonAppBar(context),
          _skeletonChipStrip(),
          Expanded(
            child: NewsShimmerLoader(
              count: rowCount,
              padding: EdgeInsets.only(bottom: bottom),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonAppBar(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0.5,
      shadowColor: Colors.black12,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                NewsShimmerLoader.greyBox(width: 36, height: 36, radius: 18),
                Expanded(
                  child: Center(
                    child: NewsShimmerLoader.greyBox(width: 120, height: 18, radius: 4),
                  ),
                ),
                NewsShimmerLoader.greyBox(width: 36, height: 36, radius: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _skeletonChipStrip() {
    return ColoredBox(
      color: Colors.white,
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
              child: NewsShimmerLoader.greyBox(width: w, height: 14, radius: 3),
            );
          },
        ),
      ),
    );
  }
}
