import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'feed_xpresso_palette_enhanced.dart';

/// Creates a full ThemeData from a [FeedXpressoPaletteEnhanced].
ThemeData buildEnhancedTheme(FeedXpressoPaletteEnhanced palette) {
  final isDark = palette.background.computeLuminance() < 0.2;

  return ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: palette.accent,
      onPrimary: palette.onAccent,
      primaryContainer: palette.accentSurface,
      secondary: palette.accentSecondary,
      onSecondary: Colors.white,
      secondaryContainer: palette.accentSecondarySurface,
      tertiary: palette.accentTertiary,
      onTertiary: Colors.white,
      tertiaryContainer: palette.accentTertiarySurface,
      error: palette.error,
      onError: Colors.white,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      surfaceContainerHighest: palette.surfaceElevated,
      outline: palette.divider,
    ),
    scaffoldBackgroundColor: palette.background,
    cardTheme: CardThemeData(
      color: palette.cardSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: palette.glassBorder.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: palette.onAccent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        textStyle: GoogleFonts.notoSans(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.textPrimary,
        side: BorderSide(color: palette.glassBorder, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: GoogleFonts.notoSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: GoogleFonts.notoSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: palette.chipInactiveBg,
      selectedColor: palette.chipActiveBg,
      secondarySelectedColor: palette.accent.withValues(alpha: 0.1),
      shadowColor: Colors.transparent,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelStyle: GoogleFonts.notoSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: palette.chipInactiveBorder,
          width: 1,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.glassSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.glassBorder, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.glassBorder, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.borderFocus, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: palette.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: GoogleFonts.notoSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: palette.textTertiary,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      elevation: 0,
      dragHandleColor: palette.glassBorder,
      dragHandleSize: const Size(40, 4),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: palette.navBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: palette.accentSurface,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return GoogleFonts.notoSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: states.contains(WidgetState.selected)
              ? palette.navActiveLabel
              : palette.navInactiveLabel,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? palette.navActiveIcon
              : palette.navInactiveIcon,
        );
      }),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: palette.textPrimary),
      titleTextStyle: GoogleFonts.notoSans(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: palette.title,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.surfaceElevated,
      contentTextStyle: GoogleFonts.notoSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(
      color: palette.divider,
      thickness: 1,
      space: 0,
    ),
    textTheme: _buildTextTheme(palette),
  );
}

TextTheme _buildTextTheme(FeedXpressoPaletteEnhanced palette) {
  return TextTheme(
    displayLarge: GoogleFonts.notoSans(
      fontSize: 32,
      fontWeight: FontWeight.w900,
      height: 1.1,
      letterSpacing: -0.6,
      color: palette.title,
    ),
    displayMedium: GoogleFonts.notoSans(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      height: 1.2,
      letterSpacing: -0.4,
      color: palette.title,
    ),
    displaySmall: GoogleFonts.notoSans(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: -0.3,
      color: palette.title,
    ),
    headlineLarge: GoogleFonts.notoSans(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      height: 1.3,
      letterSpacing: -0.2,
      color: palette.title,
    ),
    headlineMedium: GoogleFonts.notoSans(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: -0.2,
      color: palette.title,
    ),
    headlineSmall: GoogleFonts.notoSans(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: -0.1,
      color: palette.title,
    ),
    titleLarge: GoogleFonts.notoSans(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.4,
      letterSpacing: -0.1,
      color: palette.title,
    ),
    titleMedium: GoogleFonts.notoSans(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: 0.1,
      color: palette.title,
    ),
    titleSmall: GoogleFonts.notoSans(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: 0.1,
      color: palette.textSecondary,
    ),
    bodyLarge: GoogleFonts.notoSans(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
      letterSpacing: 0.1,
      color: palette.textPrimary,
    ),
    bodyMedium: GoogleFonts.notoSans(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
      letterSpacing: 0.1,
      color: palette.textPrimary,
    ),
    bodySmall: GoogleFonts.notoSans(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.4,
      letterSpacing: 0.1,
      color: palette.textSecondary,
    ),
    labelLarge: GoogleFonts.notoSans(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: 0.5,
      color: palette.textPrimary,
    ),
    labelMedium: GoogleFonts.notoSans(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.3,
      letterSpacing: 0.2,
      color: palette.textSecondary,
    ),
    labelSmall: GoogleFonts.notoSans(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: 0.2,
      color: palette.textTertiary,
    ),
  );
}
