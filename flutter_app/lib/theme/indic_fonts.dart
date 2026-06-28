import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/feed/feed_xpresso_palette.dart';

/// Latin + Telugu + Devanagari coverage for hi/te feed copy on web and mobile.
abstract final class IndicFonts {
  static const _fallbackFamilies = <String>[
    'Noto Sans Telugu',
    'Noto Sans Devanagari',
    'Noto Sans',
  ];

  static Future<void> preload() async {
    try {
      await GoogleFonts.pendingFonts([
        GoogleFonts.notoSans(),
        GoogleFonts.notoSansTelugu(),
        GoogleFonts.notoSansDevanagari(),
      ]);
    } catch (_) {
      // Offline / blocked CDN — system fonts still render.
    }
  }

  static TextStyle style(TextStyle base) {
    return GoogleFonts.notoSans(textStyle: base).copyWith(
      fontFamilyFallback: _fallbackFamilies,
    );
  }

  static TextTheme textThemeFor(FeedXpressoPalette palette) {
    return TextTheme(
      displaySmall: style(palette.screenTitleStyle),
      titleLarge: style(TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 17,
        color: palette.title,
      )),
      titleMedium: style(palette.titleStyle),
      titleSmall: style(TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: palette.title,
      )),
      bodyLarge: style(TextStyle(color: palette.title, fontSize: 15)),
      bodyMedium: style(TextStyle(color: palette.summary, fontSize: 14)),
      bodySmall: style(TextStyle(color: palette.meta, fontSize: 12)),
      labelMedium: style(TextStyle(
        color: palette.meta,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      )),
    );
  }
}
