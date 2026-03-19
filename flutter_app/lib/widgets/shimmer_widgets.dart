import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants.dart';

class _GlassShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const _GlassShimmer({required this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: GlassColors.surfaceWhite,
      highlightColor: GlassColors.surfaceBright,
      child: Container(
        width: width, height: height,
        decoration: BoxDecoration(
          color: GlassColors.surfaceWhite,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class NewsCardShimmer extends StatelessWidget {
  const NewsCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GlassColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GlassColors.borderWhite, width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _GlassShimmer(width: double.infinity, height: 155, radius: 10),
        const SizedBox(height: 10),
        _GlassShimmer(width: 70, height: 18, radius: 6),
        const SizedBox(height: 8),
        _GlassShimmer(width: double.infinity, height: 14),
        const SizedBox(height: 5),
        _GlassShimmer(width: 200, height: 14),
        const SizedBox(height: 10),
        Row(children: [
          _GlassShimmer(width: 60, height: 11),
          const SizedBox(width: 10),
          _GlassShimmer(width: 55, height: 11),
          const SizedBox(width: 10),
          _GlassShimmer(width: 70, height: 11),
        ]),
      ]),
    );
  }
}

class FeedShimmer extends StatelessWidget {
  final int count;
  const FeedShimmer({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: count,
      itemBuilder: (_, __) => const NewsCardShimmer(),
    );
  }
}

class UserRowShimmer extends StatelessWidget {
  const UserRowShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GlassColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GlassColors.borderWhite, width: 0.8),
      ),
      child: Row(children: [
        _GlassShimmer(width: 44, height: 44, radius: 22),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _GlassShimmer(width: 130, height: 13),
          const SizedBox(height: 5),
          _GlassShimmer(width: 190, height: 11),
        ])),
        _GlassShimmer(width: 50, height: 22, radius: 12),
      ]),
    );
  }
}

class StatsShimmer extends StatelessWidget {
  const StatsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(4, (_) => Container(
        decoration: BoxDecoration(
          color: GlassColors.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GlassColors.borderWhite, width: 0.8),
        ),
        padding: const EdgeInsets.all(14),
        child: Shimmer.fromColors(
          baseColor: GlassColors.surfaceWhite,
          highlightColor: GlassColors.surfaceBright,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 22, height: 22, decoration: BoxDecoration(color: GlassColors.surfaceBright, borderRadius: BorderRadius.circular(6))),
            const Spacer(),
            Container(width: 55, height: 22, decoration: BoxDecoration(color: GlassColors.surfaceBright, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 4),
            Container(width: 85, height: 11, decoration: BoxDecoration(color: GlassColors.surfaceBright, borderRadius: BorderRadius.circular(4))),
          ]),
        ),
      )),
    );
  }
}