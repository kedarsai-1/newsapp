import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants.dart';
import '../theme/app_spacing.dart';

/// Shimmer list loader that matches the horizontal `NewsCard` layout.
class NewsShimmerLoader extends StatelessWidget {
  final int count;

  const NewsShimmerLoader({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      itemCount: count,
      itemBuilder: (_, __) => const _NewsCardSkeleton(),
    );
  }
}

class _NewsCardSkeleton extends StatelessWidget {
  const _NewsCardSkeleton();

  @override
  Widget build(BuildContext context) {
    // Keep this in sync with `NewsCard` spacing/layout.
    return Padding(
      padding: AppSpacing.cardMargin,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonImage(),
            SizedBox(width: AppSpacing.s12),
            Expanded(child: _SkeletonText()),
          ],
        ),
      ),
    );
  }
}

class _SkeletonImage extends StatelessWidget {
  const _SkeletonImage();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: const _PaletteShimmer(width: 90, height: 70, radius: 12),
    );
  }
}

class _SkeletonText extends StatelessWidget {
  const _SkeletonText();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PaletteShimmer(width: double.infinity, height: 14, radius: 8),
        SizedBox(height: AppSpacing.s8),
        _PaletteShimmer(width: 220, height: 12, radius: 8),
        SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            Expanded(child: _PaletteShimmer(width: double.infinity, height: 10, radius: 8)),
            SizedBox(width: AppSpacing.s8),
            _PaletteShimmer(width: 60, height: 10, radius: 8),
          ],
        ),
      ],
    );
  }
}

class _PaletteShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _PaletteShimmer({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Shimmer.fromColors(
      baseColor: p.inputFill,
      highlightColor: Color.lerp(p.surface, p.primary, 0.12)!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: p.inputFill,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

