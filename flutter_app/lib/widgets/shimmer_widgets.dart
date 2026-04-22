import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants.dart';

class _PaletteShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const _PaletteShimmer(
      {required this.width, required this.height, this.radius = 8});

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

class NewsCardShimmer extends StatelessWidget {
  const NewsCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.glassSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.cardBorder, width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PaletteShimmer(width: double.infinity, height: 155, radius: 10),
        const SizedBox(height: 10),
        _PaletteShimmer(width: 70, height: 18, radius: 6),
        const SizedBox(height: 8),
        _PaletteShimmer(width: double.infinity, height: 14),
        const SizedBox(height: 5),
        _PaletteShimmer(width: 200, height: 14),
        const SizedBox(height: 10),
        Row(children: [
          _PaletteShimmer(width: 60, height: 11),
          const SizedBox(width: 10),
          _PaletteShimmer(width: 55, height: 11),
          const SizedBox(width: 10),
          _PaletteShimmer(width: 70, height: 11),
        ]),
      ]),
    );
  }
}

/// Full-height story skeleton for the vertical feed (matches reader layout).
class FeedStoryShimmer extends StatelessWidget {
  const FeedStoryShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        children: [
          Expanded(
            flex: 48,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: _PaletteShimmer(
                  width: double.infinity, height: double.infinity, radius: 22),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            flex: 52,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: p.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PaletteShimmer(width: 120, height: 8, radius: 4),
                  const SizedBox(height: 16),
                  _PaletteShimmer(
                      width: double.infinity, height: 22, radius: 8),
                  const SizedBox(height: 8),
                  _PaletteShimmer(
                      width: double.infinity, height: 22, radius: 8),
                  const SizedBox(height: 16),
                  _PaletteShimmer(
                      width: double.infinity, height: 14, radius: 6),
                  const SizedBox(height: 6),
                  _PaletteShimmer(
                      width: double.infinity, height: 14, radius: 6),
                  const SizedBox(height: 6),
                  _PaletteShimmer(width: 200, height: 14, radius: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mimics article detail layout (hero + title + body lines).
class ArticleDetailShimmer extends StatelessWidget {
  const ArticleDetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: p.surface,
          flexibleSpace: FlexibleSpaceBar(
            background: _PaletteShimmer(
              width: double.infinity,
              height: 240,
              radius: 0,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _PaletteShimmer(width: 72, height: 22, radius: 8),
                    const SizedBox(width: 8),
                    _PaletteShimmer(width: 88, height: 22, radius: 8),
                  ],
                ),
                const SizedBox(height: 16),
                _PaletteShimmer(width: double.infinity, height: 26, radius: 8),
                const SizedBox(height: 10),
                _PaletteShimmer(width: double.infinity, height: 26, radius: 8),
                const SizedBox(height: 20),
                _PaletteShimmer(width: 140, height: 14, radius: 6),
                const SizedBox(height: 12),
                _PaletteShimmer(width: double.infinity, height: 14, radius: 6),
                const SizedBox(height: 6),
                _PaletteShimmer(width: double.infinity, height: 14, radius: 6),
                const SizedBox(height: 6),
                _PaletteShimmer(width: 220, height: 14, radius: 6),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class FeedShimmer extends StatelessWidget {
  final int count;
  const FeedShimmer({super.key, this.count = 1});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (_, __) => const FeedStoryShimmer(),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GlassColors.borderWhite, width: 0.8),
      ),
      child: Row(
        children: [
          const _GlassShimmer(width: 44, height: 44, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _GlassShimmer(width: 130, height: 13),
                const SizedBox(height: 5),
                const _GlassShimmer(width: 190, height: 11),
              ],
            ),
          ),
          const _GlassShimmer(width: 50, height: 22, radius: 12),
        ],
      ),
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
      children: List.generate(
        4,
        (_) => Container(
          decoration: BoxDecoration(
            color: GlassColors.surfaceWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GlassColors.borderWhite, width: 0.8),
          ),
          padding: const EdgeInsets.all(14),
          child: Shimmer.fromColors(
            baseColor: GlassColors.surfaceWhite,
            highlightColor: GlassColors.surfaceBright,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: GlassColors.surfaceBright,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 55,
                  height: 22,
                  decoration: BoxDecoration(
                    color: GlassColors.surfaceBright,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 85,
                  height: 11,
                  decoration: BoxDecoration(
                    color: GlassColors.surfaceBright,
                    borderRadius: BorderRadius.circular(4),
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

class _GlassShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const _GlassShimmer(
      {required this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: GlassColors.surfaceWhite,
      highlightColor: GlassColors.surfaceBright,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: GlassColors.surfaceWhite,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
