import 'package:flutter/widgets.dart';

/// Central spacing scale for consistent UI rhythm.
class AppSpacing {
  AppSpacing._();

  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;

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
}

