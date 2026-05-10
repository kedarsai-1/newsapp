import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography tuned for bold headlines + regional scripts (Noto Sans family stack).
class DhTypography {
  DhTypography._();

  static const List<String> regionalFallback = [
    'Noto Sans Telugu',
    'Noto Sans Devanagari',
    'Noto Sans Kannada',
    'Noto Sans Tamil',
    'Noto Sans Malayalam',
    'Noto Sans Bengali',
    'Noto Sans Gujarati',
    'Noto Sans',
    'sans-serif',
  ];

  /// Builds a full [TextTheme] with readable line heights for Indic scripts.
  static TextTheme textTheme(TextTheme base, Color bodyColor, Color displayColor) {
    final noto = GoogleFonts.notoSansTextTheme(base).apply(
      bodyColor: bodyColor,
      displayColor: displayColor,
      fontFamilyFallback: regionalFallback,
    );
    return noto.copyWith(
      headlineLarge: noto.headlineLarge?.copyWith(
        fontWeight: FontWeight.w900,
        fontSize: 28,
        height: 1.12,
        letterSpacing: -0.6,
      ),
      headlineMedium: noto.headlineMedium?.copyWith(
        fontWeight: FontWeight.w900,
        fontSize: 22,
        height: 1.15,
        letterSpacing: -0.45,
      ),
      headlineSmall: noto.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 20,
        height: 1.18,
        letterSpacing: -0.35,
      ),
      titleLarge: noto.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 18,
        height: 1.22,
        letterSpacing: -0.25,
      ),
      titleMedium: noto.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        height: 1.28,
      ),
      titleSmall: noto.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        height: 1.3,
      ),
      bodyLarge: noto.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 16,
        height: 1.55,
      ),
      bodyMedium: noto.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        height: 1.5,
      ),
      bodySmall: noto.bodySmall?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 13,
        height: 1.45,
      ),
      labelLarge: noto.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
        height: 1.2,
      ),
      labelMedium: noto.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 11.5,
        letterSpacing: 0.4,
        height: 1.2,
      ),
    );
  }
}
