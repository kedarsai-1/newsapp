import 'package:flutter/material.dart';

import '../widgets/feed/feed_xpresso_theme.dart';

/// Dailyhunt / Xpresso theme entry points (legacy imports).
class DailyhuntTheme {
  DailyhuntTheme._();

  static const Color accentGreen = FeedXpressoTheme.iconFg;
  static const Color accentGreenDark = FeedXpressoTheme.iconFgMuted;

  static ColorScheme colorScheme() => FeedXpressoTheme.theme().colorScheme;

  /// Xpresso dark overlay for embedded screens.
  static ThemeData overlay(BuildContext context) => FeedXpressoTheme.theme();
}
