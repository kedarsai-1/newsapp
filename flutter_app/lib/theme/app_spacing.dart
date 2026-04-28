import 'package:flutter/widgets.dart';

/// Central spacing scale for consistent UI rhythm.
class AppSpacing {
  AppSpacing._();

  // 8pt base grid
  static const double base = 8;
  static const double s8 = 8;
  static const double s4 = 4;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;

  // Backward compatible aliases
  static const double xs = s4;
  static const double sm = s8;
  static const double s12 = 12;
  static const double md = s16;
  static const double lg = s24;
  static const double xl = s32;
  static const double xxl = s40;

  // Common insets
  static const EdgeInsets page = EdgeInsets.all(s16);
  static const EdgeInsets cardPadding = EdgeInsets.all(s16);
  static const EdgeInsets cardMargin = EdgeInsets.symmetric(
    horizontal: s12,
    vertical: s8,
  );
  static const EdgeInsets section = EdgeInsets.symmetric(
    horizontal: s16,
    vertical: s12,
  );

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius panelRadius = BorderRadius.all(Radius.circular(20));
  static const BorderRadius buttonRadius =
      BorderRadius.all(Radius.circular(14));
}
