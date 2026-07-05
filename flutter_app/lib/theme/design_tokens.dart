import 'package:flutter/material.dart';

/// Premium design tokens for the Home Feed experience
///
/// Provides consistent spacing, typography, corner radii, elevation,
/// and animation curves across all news feed components.
///
/// Values are derived from Material 3 guidelines with custom editorial
/// adjustments for fast-consumption news reading.
class DesignTokens {
  DesignTokens._();

  // ════════════════════════════════════════════════════════════════════
  // SPACING — 8dp grid system with editorial adjustments
  // ════════════════════════════════════════════════════════════════════
  static const space1 = 1.0;
  static const space2 = 2.0;
  static const space4 = 4.0;
  static const space6 = 6.0;
  static const space8 = 8.0;
  static const space10 = 10.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;
  static const space32 = 32.0;
  static const space40 = 40.0;
  static const space48 = 48.0;
  static const space52 = 52.0;
  static const space56 = 56.0;

  // ════════════════════════════════════════════════════════════════════
  // CORNER RADII
  // ════════════════════════════════════════════════════════════════════
  static const radiusXS = 4.0;
  static const radiusSM = 8.0;
  static const radiusMD = 12.0;
  static const radiusLG = 16.0;
  static const radiusXL = 20.0;
  static const radius2XL = 24.0;
  static const radiusFull = 999.0;

  // ════════════════════════════════════════════════════════════════════
  // TYPOGRAPHY — Google Fonts Inter
  // ════════════════════════════════════════════════════════════════════
  static const String fontFamily = 'Inter';

  // Display / Headlines
  static const double fontSizeDisplay = 32;
  static const double fontSizeHeadlineL = 24;
  static const double fontSizeHeadlineM = 20;
  static const double fontSizeHeadlineS = 18;
  static const double fontSizeBodyL = 16;
  static const double fontSizeBodyM = 14;
  static const double fontSizeBodyS = 12;
  static const double fontSizeLabel = 13;
  static const double fontSizeLabelM = 12;
  static const double fontSizeLabelS = 11;

  static const double lineHeightDisplay = 1.2;
  static const double lineHeightHeadline = 1.25;
  static const double lineHeightBody = 1.5;
  static const double lineHeightLabel = 1.4;
  static const double lineHeightLabelS = 1.3;

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.25,
    letterSpacing: -0.3,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.2,
  );

  // Body / Summary
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.0,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0.1,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.2,
  );

  // Labels / Chips
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.1,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.3,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.2,
  );

  // ════════════════════════════════════════════════════════════════════
  // ELEVATION
  // ════════════════════════════════════════════════════════════════════
  static const double elevationNone = 0;
  static const double elevationSM = 1;
  static const double elevationMD = 2;
  static const double elevationLG = 4;
  static const double elevationXL = 8;

  // ════════════════════════════════════════════════════════════════════
  // ANIMATION DURATIONS
  // ════════════════════════════════════════════════════════════════════
  static const Duration durationInstant = Duration(milliseconds: 100);
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationMedium = Duration(milliseconds: 350);
  static const Duration durationSlow = Duration(milliseconds: 500);
  static const Duration durationSpring = Duration(milliseconds: 400);

  // ════════════════════════════════════════════════════════════════════
  // ANIMATION CURVES
  // ════════════════════════════════════════════════════════════════════
  static const Curve curveEase = Curves.easeInOut;
  static const Curve curveEaseIn = Curves.easeIn;
  static const Curve curveEaseOut = Curves.easeOut;
  static const Curve curveSpring = Curves.elasticOut;
  static const Curve curveBounce = Curves.bounceOut;
  static const Curve curveSmooth = Cubic(0.25, 0.46, 0.45, 0.94);

  // ════════════════════════════════════════════════════════════════════
  // TOUCH TARGETS
  // ════════════════════════════════════════════════════════════════════
  static const double minTouchTarget = 48.0;
  static const double iconSizeSM = 16.0;
  static const double iconSizeMD = 20.0;
  static const double iconSizeLG = 24.0;
  static const double iconSizeXL = 28.0;

  // ════════════════════════════════════════════════════════════════════
  // RESPONSIVE BREAKPOINTS
  // ════════════════════════════════════════════════════════════════════
  static const double breakpointCompact = 600;
  static const double breakpointMedium = 840;
  static const double breakpointExpanded = 1200;

  // ════════════════════════════════════════════════════════════════════
  // SCROLL BEHAVIOR
  // ════════════════════════════════════════════════════════════════════
  static const double appBarHeight = 80;
  static const double categoryBarHeight = 56;
  static const double breakingBannerHeight = 48;
  static const double cardSpacing = 8.0;
  static const double cardPadding = 16.0;
  static const double cardBorderRadius = 20.0;
  static const double cardImageAspectRatio = 16 / 9;
  static const double cardMaxWidth = 800.0;
}