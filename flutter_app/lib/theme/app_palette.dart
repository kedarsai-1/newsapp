import 'package:flutter/material.dart';

/// Semantic colors for light and dark UI (glass surfaces, text, brand).
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color primary;
  final Color primaryDark;
  final Color scaffoldBackground;
  final Color surface;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color textTertiary;
  final Color accentGreen;
  final Color accentGreenLight;
  final Color accentOrange;
  final Color accentOrangeLight;
  final Color accentPurple;
  final Color gradientStart;
  final Color gradientMid;
  final Color gradientEnd;
  final Color blobGreen;
  final Color blobPurple;
  final Color blobOrange;
  final Color glassSurface;
  final Color glassBorder;
  final Color glassBorderBright;
  final Color breaking;
  final Color error;
  final Color warning;
  final Color success;
  final Color info;
  final Color navSelected;
  final Color navUnselected;
  final Color dialogBackground;
  final Color categoryChipBg;
  final Color inputFill;
  final Color inputBorder;
  final Color snackBarBg;

  const AppPalette({
    required this.primary,
    required this.primaryDark,
    required this.scaffoldBackground,
    required this.surface,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.textTertiary,
    required this.accentGreen,
    required this.accentGreenLight,
    required this.accentOrange,
    required this.accentOrangeLight,
    required this.accentPurple,
    required this.gradientStart,
    required this.gradientMid,
    required this.gradientEnd,
    required this.blobGreen,
    required this.blobPurple,
    required this.blobOrange,
    required this.glassSurface,
    required this.glassBorder,
    required this.glassBorderBright,
    required this.breaking,
    required this.error,
    required this.warning,
    required this.success,
    required this.info,
    required this.navSelected,
    required this.navUnselected,
    required this.dialogBackground,
    required this.categoryChipBg,
    required this.inputFill,
    required this.inputBorder,
    required this.snackBarBg,
  });

  /// Dark “editorial” theme — deep ink, mint accent, soft aurora gradient.
  static const AppPalette dark = AppPalette(
    // Base surfaces (consistent true-dark).
    scaffoldBackground: Color(0xFF0D0D0D),
    surface: Color(0xFF1A1A1A), // card/surface
    glassSurface: Color(0xFF1A1A1A),
    dialogBackground: Color(0xFF1A1A1A),
    snackBarBg: Color(0xFF1A1A1A),
    inputFill: Color(0xFF141414),

    // Borders
    cardBorder: Color(0x2EFFFFFF),
    glassBorder: Color(0x24FFFFFF),
    glassBorderBright: Color(0x33FFFFFF),
    inputBorder: Color(0x26FFFFFF),

    // Brand (green/teal family)
    primary: Color(0xFF34D399),
    primaryDark: Color(0xFF059669),
    accentGreen: Color(0xFF34D399),
    accentGreenLight: Color(0xFF2DD4BF), // teal highlight for gradient
    accentOrange: Color(0xFFF97316),
    accentOrangeLight: Color(0xFFFDBA74),
    accentPurple: Color(0xFFC084FC),

    // Background gradient (subtle, within the #0D0D0D–#121212 range)
    gradientStart: Color(0xFF0D0D0D),
    gradientMid: Color(0xFF101010),
    gradientEnd: Color(0xFF121212),
    blobGreen: Color(0xFF34D399),
    blobPurple: Color(0xFFA78BFA),
    blobOrange: Color(0xFFF97316),

    // Text hierarchy (white → greys)
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xBFFFFFFF),
    textTertiary: Color(0x99FFFFFF),
    textHint: Color(0x66FFFFFF),
    breaking: Color(0xFFF97316),
    error: Color(0xFFF87171),
    warning: Color(0xFFFBBF24),
    success: Color(0xFF34D399),
    info: Color(0xFF38BDF8),
    navSelected: Color(0xFF34D399),
    navUnselected: Color(0x99FFFFFF),
    categoryChipBg: Color(0x2634D399),
  );

  /// Light theme: airy paper, crisp emerald accent.
  static const AppPalette light = AppPalette(
    // Brand (richer green for production visibility)
    primary: Color(0xFF0E9F6E),
    primaryDark: Color(0xFF057A55),

    // Surfaces (clean, premium)
    scaffoldBackground: Color(0xFFF5F7FA), // required
    surface: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE5E7EB), // required

    // Text hierarchy (required contrast)
    textPrimary: Color(0xFF111111),   // required
    textSecondary: Color(0xFF555555), // required
    textHint: Color(0xFF888888),      // required
    textTertiary: Color(0xFF6B7280),

    accentGreen: Color(0xFF0E9F6E),
    accentGreenLight: Color(0xFF34D399),
    accentOrange: Color(0xFFEA580C),
    accentOrangeLight: Color(0xFFF97316),
    accentPurple: Color(0xFF7C3AED),
    gradientStart: Color(0xFFECFDF5),
    gradientMid: Color(0xFFF4F7FB),
    gradientEnd: Color(0xFFFFFFFF),
    blobGreen: Color(0xFF10B981),
    blobPurple: Color(0xFFA78BFA),
    blobOrange: Color(0xFFF97316),
    glassSurface: Color(0xFFFFFFFF),
    glassBorder: Color(0xFFE5E7EB),
    glassBorderBright: Color(0xFFDFE3EA),
    breaking: Color(0xFFEA580C),
    error: Color(0xFFDC2626),
    warning: Color(0xFFD97706),
    success: Color(0xFF0E9F6E),
    info: Color(0xFF0284C7),
    navSelected: Color(0xFF0E9F6E),
    navUnselected: Color(0xFF888888),
    dialogBackground: Color(0xFFFFFFFF),
    categoryChipBg: Color(0xFFF1F3F5), // inactive chips background
    inputFill: Color(0xFFF3F4F6),
    inputBorder: Color(0xFFE5E7EB),
    snackBarBg: Color(0xFF1E293B),
  );

  @override
  AppPalette copyWith({
    Color? primary,
    Color? scaffoldBackground,
    Color? surface,
    Color? textPrimary,
  }) {
    return AppPalette(
      primary: primary ?? this.primary,
      primaryDark: primaryDark,
      scaffoldBackground: scaffoldBackground ?? this.scaffoldBackground,
      surface: surface ?? this.surface,
      cardBorder: cardBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary,
      textHint: textHint,
      textTertiary: textTertiary,
      accentGreen: accentGreen,
      accentGreenLight: accentGreenLight,
      accentOrange: accentOrange,
      accentOrangeLight: accentOrangeLight,
      accentPurple: accentPurple,
      gradientStart: gradientStart,
      gradientMid: gradientMid,
      gradientEnd: gradientEnd,
      blobGreen: blobGreen,
      blobPurple: blobPurple,
      blobOrange: blobOrange,
      glassSurface: glassSurface,
      glassBorder: glassBorder,
      glassBorderBright: glassBorderBright,
      breaking: breaking,
      error: error,
      warning: warning,
      success: success,
      info: info,
      navSelected: navSelected,
      navUnselected: navUnselected,
      dialogBackground: dialogBackground,
      categoryChipBg: categoryChipBg,
      inputFill: inputFill,
      inputBorder: inputBorder,
      snackBarBg: snackBarBg,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      scaffoldBackground:
          Color.lerp(scaffoldBackground, other.scaffoldBackground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accentGreen: Color.lerp(accentGreen, other.accentGreen, t)!,
      accentGreenLight:
          Color.lerp(accentGreenLight, other.accentGreenLight, t)!,
      accentOrange: Color.lerp(accentOrange, other.accentOrange, t)!,
      accentOrangeLight:
          Color.lerp(accentOrangeLight, other.accentOrangeLight, t)!,
      accentPurple: Color.lerp(accentPurple, other.accentPurple, t)!,
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientMid: Color.lerp(gradientMid, other.gradientMid, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!,
      blobGreen: Color.lerp(blobGreen, other.blobGreen, t)!,
      blobPurple: Color.lerp(blobPurple, other.blobPurple, t)!,
      blobOrange: Color.lerp(blobOrange, other.blobOrange, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassBorderBright:
          Color.lerp(glassBorderBright, other.glassBorderBright, t)!,
      breaking: Color.lerp(breaking, other.breaking, t)!,
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      info: Color.lerp(info, other.info, t)!,
      navSelected: Color.lerp(navSelected, other.navSelected, t)!,
      navUnselected: Color.lerp(navUnselected, other.navUnselected, t)!,
      dialogBackground:
          Color.lerp(dialogBackground, other.dialogBackground, t)!,
      categoryChipBg: Color.lerp(categoryChipBg, other.categoryChipBg, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      snackBarBg: Color.lerp(snackBarBg, other.snackBarBg, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
