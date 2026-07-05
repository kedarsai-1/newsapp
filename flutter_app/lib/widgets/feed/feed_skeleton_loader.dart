import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/app_palette.dart';
import '../../theme/design_tokens.dart';

/// Premium feed skeleton loader
///
/// Matches the NewsCard layout exactly:
/// - Image placeholder with 16:9 aspect
/// - Headline skeleton (2 lines)
/// - Summary skeleton (4 lines)
/// - Category badge skeleton
/// - Metadata row skeleton
/// - Action bar skeleton
class FeedSkeletonLoader extends StatelessWidget {
  final int count;
  final AppPalette? palette;

  const FeedSkeletonLoader({
    super.key,
    this.count = 5,
    this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final palette = this.palette ?? context.palette;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.cardPadding,
        vertical: DesignTokens.space8,
      ),
      itemCount: count,
      itemBuilder: (context, index) => _buildCardSkeleton(palette),
    );
  }

  Widget _buildCardSkeleton(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: DesignTokens.cardSpacing,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(DesignTokens.cardBorderRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image skeleton
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(DesignTokens.cardBorderRadius),
                topRight: Radius.circular(DesignTokens.cardBorderRadius),
              ),
              child: AspectRatio(
                aspectRatio: DesignTokens.cardImageAspectRatio,
                child: _buildShimmerBox(
                  palette,
                  height: double.infinity,
                ),
              ),
            ),

            // Content skeleton
            Padding(
              padding: const EdgeInsets.all(DesignTokens.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge skeleton
                  _buildShimmerBox(
                    palette,
                    width: 80,
                    height: 24,
                    radius: 4,
                  ),
                  const SizedBox(height: DesignTokens.space12),

                  // Headline skeleton (2 lines)
                  _buildShimmerBox(
                    palette,
                    width: double.infinity,
                    height: 22,
                  ),
                  const SizedBox(height: DesignTokens.space6),
                  _buildShimmerBox(
                    palette,
                    width: 0.75 * double.infinity,
                    height: 22,
                  ),
                  const SizedBox(height: DesignTokens.space12),

                  // Summary skeleton (4 lines)
                  _buildShimmerBox(
                    palette,
                    width: double.infinity,
                    height: 18,
                  ),
                  const SizedBox(height: DesignTokens.space6),
                  _buildShimmerBox(
                    palette,
                    width: 0.9 * double.infinity,
                    height: 18,
                  ),
                  const SizedBox(height: DesignTokens.space6),
                  _buildShimmerBox(
                    palette,
                    width: 0.85 * double.infinity,
                    height: 18,
                  ),
                  const SizedBox(height: DesignTokens.space6),
                  _buildShimmerBox(
                    palette,
                    width: 0.65 * double.infinity,
                    height: 18,
                  ),
                  const SizedBox(height: DesignTokens.space16),

                  // Metadata skeleton
                  Row(
                    children: [
                      _buildShimmerBox(
                        palette,
                        width: 60,
                        height: 16,
                        radius: 4,
                      ),
                      const SizedBox(width: DesignTokens.space16),
                      _buildShimmerBox(
                        palette,
                        width: 50,
                        height: 16,
                        radius: 4,
                      ),
                      const Spacer(),
                      _buildShimmerBox(
                        palette,
                        width: 50,
                        height: 16,
                        radius: 4,
                      ),
                    ],
                  ),

                  const SizedBox(height: DesignTokens.space12),

                  // Action bar skeleton
                  Row(
                    children: [
                      _buildShimmerBox(
                        palette,
                        width: 32,
                        height: 32,
                        radius: DesignTokens.radiusSM,
                      ),
                      const SizedBox(width: DesignTokens.space12),
                      _buildShimmerBox(
                        palette,
                        width: 32,
                        height: 32,
                        radius: DesignTokens.radiusSM,
                      ),
                      const SizedBox(width: DesignTokens.space12),
                      _buildShimmerBox(
                        palette,
                        width: 32,
                        height: 32,
                        radius: DesignTokens.radiusSM,
                      ),
                      const Spacer(),
                      _buildShimmerBox(
                        palette,
                        width: 32,
                        height: 32,
                        radius: DesignTokens.radiusSM,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerBox(
    AppPalette palette, {
    double? width,
    double? height = 16,
    double radius = 3,
  }) {
    return Shimmer.fromColors(
      baseColor: palette.shimmerBase,
      highlightColor: palette.shimmerHighlight,
      period: const Duration(milliseconds: 1200),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: palette.shimmerBase,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}