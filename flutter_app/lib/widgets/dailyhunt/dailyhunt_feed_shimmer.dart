import 'package:flutter/material.dart';

import '../news_shimmer_loader.dart';

/// Dense list shimmer for Dailyhunt-style home (non-scroll parent supplies physics).
class DailyhuntFeedShimmer extends StatelessWidget {
  final int itemCount;

  const DailyhuntFeedShimmer({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return NewsShimmerLoader(
      count: itemCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 2),
    );
  }
}
