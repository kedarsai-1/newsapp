import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Placeholder rows matching [DailyhuntSavedArticleTile] while bookmarks load.
class DailyhuntSavedListShimmer extends StatelessWidget {
  final int itemCount;

  const DailyhuntSavedListShimmer({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8E8E8),
      highlightColor: const Color(0xFFF8F8F8),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.only(top: 4),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          height: 116,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
