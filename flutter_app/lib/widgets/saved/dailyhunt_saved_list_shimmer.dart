import 'package:flutter/material.dart';

import '../news_shimmer_loader.dart';

/// Saved list: same dense row skeleton as the main feed.
class DailyhuntSavedListShimmer extends StatelessWidget {
  final int itemCount;

  const DailyhuntSavedListShimmer({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return NewsShimmerLoader(
      count: itemCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 2, bottom: 4),
    );
  }
}
