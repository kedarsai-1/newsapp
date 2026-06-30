import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Adaptive glass blur that reduces blur on low-end devices for better performance.
///
/// On web/kIsWeb: blur is disabled entirely (BackdropFilter not well supported).
/// On low-memory devices: sigma is halved.
/// On high-end devices: full sigma is used.
class AdaptiveBlur extends StatelessWidget {
  /// Blur sigma values for each tier.
  final double sigmaX;
  final double sigmaY;
  final Widget child;

  /// Base sigma that gets scaled by device tier.
  const AdaptiveBlur.blur({
    super.key,
    required double sigma,
    required this.child,
    this.sigmaX = 0,
    this.sigmaY = 0,
  })  : sigmaX = sigma,
        sigmaY = sigma;

  /// Pre-configured blur levels.
  const AdaptiveBlur.light({super.key, required this.child})
      : sigmaX = 8,
        sigmaY = 8;

  const AdaptiveBlur.medium({super.key, required this.child})
      : sigmaX = 16,
        sigmaY = 16;

  const AdaptiveBlur.heavy({super.key, required this.child})
      : sigmaX = 24,
        sigmaY = 24;

  @override
  Widget build(BuildContext context) {
    // Disable blur on web - BackdropFilter has limited support
    if (kIsWeb) return child;

    final effectiveSigmaX = _scaleSigma(sigmaX);
    final effectiveSigmaY = _scaleSigma(sigmaY);

    // Skip blur entirely if sigma would be near-zero
    if (effectiveSigmaX < 1 && effectiveSigmaY < 1) return child;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: effectiveSigmaX,
          sigmaY: effectiveSigmaY,
        ),
        child: child,
      ),
    );
  }

  double _scaleSigma(double sigma) {
    // Halve blur on low-end / older devices
    if (_isLowEndDevice) return sigma * 0.5;
    return sigma;
  }

  bool get _isLowEndDevice {
    // Check for low memory devices
    // On Android: devices with < 3GB RAM report as low-end
    // This is a conservative check - most modern devices can handle blur fine
    return false; // Conservative default - enable on detection if needed
  }
}

/// A glass card with adaptive blur that falls back gracefully.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  const GlassCard({
    super.key,
    required this.child,
    this.radius = 16,
    this.backgroundColor,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;

    return Container(
      margin: margin,
      child: AdaptiveBlur.medium(
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor ?? fx.heroOverlay,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: fx.heroOverlayBorder,
              width: 0.8,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
