import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Reusable gradient tokens for backgrounds and accents.
class AppGradients {
  AppGradients._();

  static LinearGradient background(AppPalette p) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [p.gradientStart, p.gradientMid, p.gradientEnd],
        stops: const [0.0, 0.5, 1.0],
      );

  static LinearGradient accent(AppPalette p) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [p.primary, p.accentGreenLight, p.accentPurple],
      );

  static LinearGradient darkOverlay() => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.55),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.80),
        ],
        stops: const [0.0, 0.45, 1.0],
      );
}
