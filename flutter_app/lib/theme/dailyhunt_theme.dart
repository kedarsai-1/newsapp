import 'package:flutter/material.dart';

import '../widgets/feed/feed_xpresso_theme.dart';

/// Dailyhunt / Xpresso theme helpers (legacy imports).
class DailyhuntTheme {
  DailyhuntTheme._();

  static Color accent(BuildContext context) =>
      FeedXpressoTheme.fx(context).accent;

  static Color accentGreen(BuildContext context) =>
      FeedXpressoTheme.fx(context).accent;

  static Color accentGreenDark(BuildContext context) =>
      FeedXpressoTheme.fx(context).accent;

  static ColorScheme colorScheme(BuildContext context) =>
      Theme.of(context).colorScheme;

  static ThemeData overlay(BuildContext context) => Theme.of(context);
}
