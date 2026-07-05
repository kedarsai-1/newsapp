import 'package:flutter/material.dart';
import 'feed_xpresso_theme.dart';

/// Robust overlay system for hero cards with dynamic gradient
/// and optional scrim for high contrast text readability.
class HeroOverlay extends StatelessWidget {
  const HeroOverlay({
    super.key,
    required this.child,
    this.dominantColor,
    this.applyScrim = true,
    this.titleOpacity = 1.0,
    this.metaOpacity = 0.8,
  });

  final Widget child;
  final Color? dominantColor;
  final bool applyScrim;
  final double titleOpacity;
  final double metaOpacity;

  static const _defaultGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00000000),
      Color(0x10000000),
      Color(0x40000000),
      Color(0x89000000),
    ],
    stops: [0.0, 0.15, 0.55, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image/media
        child,
        // Scrim layer for high contrast
        if (applyScrim) _buildScrim(dominantColor),
        // Content layer
        Positioned.fill(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top space indicator
                  _buildTopSpacer(),
                  const Spacer(),
                  // Title (maintains opacity)
                  _buildTitle(context),
                  const SizedBox(height: 12),
                  // Summary
                  _buildSummary(context),
                  const SizedBox(height: 16),
                  // Source & time metadata
                  _buildSourceAndTime(context),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScrim(Color? color) {
    final gradient = color != null
        ? _colorToGradient(color)
        : _defaultGradient;

    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
        ),
      ),
    );
  }

  LinearGradient _colorToGradient(Color color) {
    // Extract brightness to determine scrim strength
    final isDark = color.computeLuminance() < 0.5;
    final alpha = isDark ? 0.95 : 0.8;

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.black.withValues(alpha: alpha * 0.1),
        Colors.black.withValues(alpha: alpha * 0.3),
        Colors.black.withValues(alpha: alpha * 0.6),
        Colors.black.withValues(alpha: alpha),
      ],
      stops: const [0.0, 0.15, 0.55, 1.0],
    );
  }

  Widget _buildTopSpacer() => const SizedBox(height: 32);

  Widget _buildTitle(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Opacity(
      opacity: titleOpacity,
      child: Text(
        'Headline Text', // Placeholder, will be passed from parent
        style: TextStyle(
          color: fx.overlayFg,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Opacity(
      opacity: metaOpacity * 0.95,
      child: Text(
        'Summary text placeholder', // Placeholder, will be passed from parent
        style: TextStyle(
          color: fx.overlayFgMuted,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.5,
          letterSpacing: -0.1,
        ),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildSourceAndTime(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Opacity(
      opacity: metaOpacity * 0.7,
      child: Row(
        children: [
          _buildSourceChip(fx),
          const SizedBox(width: 12),
          _buildTimeText(fx),
        ],
      ),
    );
  }

  Widget _buildSourceChip(FeedXpressoPalette fx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fx.overlayFgMuted.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: fx.overlayFgMuted.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Text(
        'Source',
        style: TextStyle(
          color: fx.overlayFg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildTimeText(FeedXpressoPalette fx) {
    return Text(
      '2h ago',
      style: TextStyle(
        color: fx.overlayFgMuted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}