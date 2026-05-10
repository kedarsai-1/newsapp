import 'package:flutter/material.dart';

import '../design_system/dailyhunt/dailyhunt_theme_builder.dart';
import '../design_system/dailyhunt/dailyhunt_tokens.dart';

/// Backward-compatible entry points for Dailyhunt-style UI.
///
/// Prefer importing `package:news_app/design_system/dailyhunt/dailyhunt.dart`
/// for full tokens, typography, themes, and widgets.
class DailyhuntTheme {
  DailyhuntTheme._();

  /// Primary green (alias of [DhTokens.accent]).
  static const Color accentGreen = DhTokens.accent;
  static const Color accentGreenDark = DhTokens.accentDark;

  /// Material 3 light color scheme (green seed).
  static ColorScheme colorScheme() => DhTokens.lightColorScheme();

  /// Light overlay for embedding in the host app (e.g. settings / saved screens).
  static ThemeData overlay(BuildContext context) {
    final merged = DailyhuntDesignThemes.overlayLight(context);
    return merged.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    );
  }
}
