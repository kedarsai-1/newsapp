import 'package:flutter/material.dart';

/// Semantic colors and radii for the Dailyhunt-inspired design system.
class DhTokens {
  DhTokens._();

  /// Primary brand green (Dailyhunt-adjacent).
  static const Color accent = Color(0xFF0A8F57);
  static const Color accentDark = Color(0xFF067347);
  static const Color accentMuted = Color(0x1A0A8F57);

  static const Color lightScaffold = Color(0xFFF5F6F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOutline = Color(0xFFE5E7EB);

  static const Color darkScaffold = Color(0xFF0F0F0F);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkSurfaceHigh = Color(0xFF242424);
  static const Color darkOutline = Color(0xFF2E2E2E);

  static const double radiusCard = 16;
  static const double radiusChip = 20;
  static const double radiusButton = 14;
  static const double radiusAction = 999;

  static const double elevationCard = 2;
  static const double elevationNav = 0;

  static ColorScheme lightColorScheme() {
    return ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: lightSurface,
      onSurface: const Color(0xFF111827),
      surfaceContainerHighest: const Color(0xFFF3F4F6),
    );
  }

  static ColorScheme darkColorScheme() {
    return ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: darkSurface,
      onSurface: const Color(0xFFF3F4F6),
      surfaceContainerHighest: darkSurfaceHigh,
    );
  }
}
