import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton placeholders matching [DailyhuntFeedCard] layout.
class DailyhuntFeedShimmer extends StatelessWidget {
  final int itemCount;

  const DailyhuntFeedShimmer({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE6E6E6),
      highlightColor: const Color(0xFFF5F5F5),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4),
        itemCount: itemCount,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 10),
              Container(height: 16, width: double.infinity, color: Colors.white),
              const SizedBox(height: 8),
              Container(height: 14, width: 280, color: Colors.white),
              const SizedBox(height: 6),
              Container(height: 12, width: 160, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
