import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_palette.dart';
import 'app_typography.dart';

/// Material [ThemeData] for light (paper) and dark (glass night) appearances.
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const p = AppPalette.light;
    return _base(p, Brightness.light);
  }

  static ThemeData dark() {
    const p = AppPalette.dark;
    return _base(p, Brightness.dark);
  }

  static ThemeData _base(AppPalette p, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final baseText = ThemeData(brightness: brightness).textTheme;
    final textTheme = AppTypography.buildTextTheme(
      GoogleFonts.plusJakartaSansTextTheme(baseText).apply(
      bodyColor: p.textPrimary,
      displayColor: p.textPrimary,
      ),
      p,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.scaffoldBackground,
      extensions: <ThemeExtension<dynamic>>[p],
      textTheme: textTheme,
      colorScheme: isLight
          ? ColorScheme.light(
              primary: p.primary,
              onPrimary: Colors.white,
              secondary: p.accentPurple,
              onSecondary: Colors.white,
              surface: p.surface,
              onSurface: p.textPrimary,
              error: p.error,
              onError: Colors.white,
            )
          : ColorScheme.dark(
              primary: p.primary,
              onPrimary: Colors.white,
              secondary: p.accentPurple,
              onSecondary: Colors.white,
              surface: p.surface,
              onSurface: p.textPrimary,
              error: p.error,
              onError: Colors.white,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
            color: p.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        iconTheme: IconThemeData(color: p.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isLight ? p.surface : Colors.transparent,
        selectedItemColor: p.navSelected,
        unselectedItemColor: p.navUnselected,
        type: BottomNavigationBarType.fixed,
        elevation: isLight ? 8 : 0,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.glassBorder, width: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.inputBorder, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
        labelStyle: TextStyle(color: p.textTertiary),
        hintStyle: TextStyle(color: p.textHint),
      ),
      iconTheme: IconThemeData(color: p.textSecondary),
      dividerTheme: DividerThemeData(color: p.glassBorder, thickness: 0.8),
      dialogTheme: DialogThemeData(
        backgroundColor: p.dialogBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.glassBorder, width: 0.8),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.dialogBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.accentGreenLight,
        unselectedLabelColor: p.textTertiary,
        indicatorColor: p.primary,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? p.primary : Colors.transparent,
        ),
        side: BorderSide(color: p.glassBorderBright, width: 1.5),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.snackBarBg,
        contentTextStyle:
            TextStyle(color: isLight ? Colors.white : p.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
