import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/design_tokens.dart';

/// Enhanced theme system for the premium Home Feed
///
/// Extends Material 3 with editorial design adjustments
/// for fast-consumption news reading experience.
class FeedEnhancedTheme {
  const FeedEnhancedTheme._();

  // ════════════════════════════════════════════════════════════════════
  // LIGHT THEME - Clean, bright, modern
  // ════════════════════════════════════════════════════════════════════
  static ThemeData get light {
    final base = ThemeData.light();
    final colors = _createLightColors();

    return base.copyWith(
      // Color scheme
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.scaffoldBackground,
      backgroundColor: colors.scaffoldBackground,
      cardColor: colors.surface,
      dividerColor: colors.divider,
      focusColor: colors.primary.withValues(alpha: 0.15),

      // Text themes
      textTheme: _createTextTheme(colors, isDark: false),
      primaryTextTheme: _createTextTheme(colors, isDark: false),
      accentTextTheme: _createTextTheme(colors, isDark: false),

      // Typography
      typography: Typography.material2021(platform: TargetPlatform.android),

      // Card elevation
      cardTheme: CardTheme(
        elevation: DesignTokens.elevationSM,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.cardBorderRadius),
        ),
      ),

      // App bar
      appBarTheme: AppBarTheme(
        elevation: DesignTokens.elevationNone,
        centerTitle: true,
        backgroundColor: colors.scaffoldBackground,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: DesignTokens.elevationSM,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        iconTheme: IconThemeData(
          color: colors.textPrimary,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: DesignTokens.elevationMD,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          ),
          textStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ),

      // Outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.primary.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          ),
        ),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        labelStyle: TextStyle(
          fontSize: DesignTokens.fontSizeLabel,
          fontWeight: FontWeight.w500,
          height: DesignTokens.lineHeightLabel,
          color: colors.textPrimary,
        ),
        backgroundColor: colors.surface,
        selectedColor: colors.primary.withValues(alpha: 0.1),
        secondarySelectedColor: colors.primary.withValues(alpha: 0.05),
        shadowColor: Colors.transparent,
        elevation: DesignTokens.elevationNone,
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space8,
          vertical: DesignTokens.space4,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: DesignTokens.space6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        side: BorderSide(
          color: colors.divider.withValues(alpha: 0.3),
          width: 1,
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          borderSide: BorderSide(
            color: colors.divider.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          borderSide: BorderSide(
            color: colors.divider.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          borderSide: BorderSide(
            color: colors.primary,
            width: 1.5,
          ),
        ),
        hintStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colors.textHint,
        ),
      ),

      // Bottom navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.textSecondary,
        elevation: DesignTokens.elevationMD,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Floating action button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: DesignTokens.elevationMD,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
        indent: 0,
        endIndent: 0,
      ),

      // Snack bar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.snackBarBg,
        contentTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        ),
        elevation: DesignTokens.elevationMD,
      ),

      // Dialog theme
      dialogTheme: DialogTheme(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius2XL),
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colors.textPrimary,
        ),
        elevation: DesignTokens.elevationXL,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // DARK THEME - Premium dark, high contrast
  // ════════════════════════════════════════════════════════════════════
  static ThemeData get dark {
    final base = ThemeData.dark();
    final colors = _createDarkColors();

    return base.copyWith(
      // Color scheme
      primaryColor: colors.primary,
      scaffoldBackgroundColor: colors.scaffoldBackground,
      backgroundColor: colors.scaffoldBackground,
      cardColor: colors.surface,
      dividerColor: colors.divider,
      focusColor: colors.primary.withValues(alpha: 0.15),

      // Text themes
      textTheme: _createTextTheme(colors, isDark: true),
      primaryTextTheme: _createTextTheme(colors, isDark: true),
      accentTextTheme: _createTextTheme(colors, isDark: true),

      // Typography
      typography: Typography.material2021(platform: TargetPlatform.android),

      // Card elevation
      cardTheme: CardTheme(
        elevation: DesignTokens.elevationSM,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.cardBorderRadius),
        ),
        color: colors.surface,
      ),

      // App bar
      appBarTheme: AppBarTheme(
        elevation: DesignTokens.elevationNone,
        centerTitle: true,
        backgroundColor: colors.scaffoldBackground,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: DesignTokens.elevationSM,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        iconTheme: IconThemeData(
          color: colors.textPrimary,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: DesignTokens.elevationMD,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          ),
          textStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ),

      // Outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.primary.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          ),
        ),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        labelStyle: TextStyle(
          fontSize: DesignTokens.fontSizeLabel,
          fontWeight: FontWeight.w500,
          height: DesignTokens.lineHeightLabel,
          color: colors.textPrimary,
        ),
        backgroundColor: colors.surface,
        selectedColor: colors.primary.withValues(alpha: 0.2),
        secondarySelectedColor: colors.primary.withValues(alpha: 0.1),
        shadowColor: Colors.transparent,
        elevation: DesignTokens.elevationNone,
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space8,
          vertical: DesignTokens.space4,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: DesignTokens.space6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        side: BorderSide(
          color: colors.divider.withValues(alpha: 0.5),
          width: 1,
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          borderSide: BorderSide(
            color: colors.divider.withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          borderSide: BorderSide(
            color: colors.divider.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
          borderSide: BorderSide(
            color: colors.primary,
            width: 1.5,
          ),
        ),
        hintStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colors.textTertiary,
        ),
      ),

      // Bottom navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.textSecondary,
        elevation: DesignTokens.elevationMD,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Floating action button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: DesignTokens.elevationMD,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
        indent: 0,
        endIndent: 0,
      ),

      // Snack bar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.snackBarBg,
        contentTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
        ),
        elevation: DesignTokens.elevationMD,
      ),

      // Dialog theme
      dialogTheme: DialogTheme(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius2XL),
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: colors.textPrimary,
        ),
        elevation: DesignTokens.elevationXL,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // COLOR PALETTES
  // ════════════════════════════════════════════════════════════════════
  static AppPalette _createLightColors() {
    return const AppPalette(
      // Primary brand
      primary: Color(0xFF0E9F6E),
      primaryDark: Color(0xFF057A55),

      // Background surfaces
      scaffoldBackground: Color(0xFFFFFFFF),
      surface: Color(0xFFF8F9FA),
      cardBorder: Color(0xFFE5E7EB),

      // Text hierarchy
      textPrimary: Color(0xFF111827),
      textSecondary: Color(0xFF6B7280),
      textTertiary: Color(0xFF9CA3AF),
      textHint: Color(0xFFD1D5DB),

      // Brand accents
      accentGreen: Color(0xFF10B981),
      accentGreenLight: Color(0xFF6EE7B7),
      accentOrange: Color(0xFFF97316),
      accentOrangeLight: Color(0xFFFFD8A8),
      accentPurple: Color(0xFF8B5CF6),

      // Gradients for visual interest
      gradientStart: Color(0xFF0EA5E9),
      gradientMid: Color(0xFF8B5CF6),
      gradientEnd: Color(0xFFEC4899),

      // Support colors
      blobGreen: Color(0xFF10B981),
      blobPurple: Color(0xFF8B5CF6),
      blobOrange: Color(0xFFF97316),

      // Glass surfaces
      glassSurface: Color(0xFFFFFFFF),
      glassBorder: Color(0xFFE5E7EB),
      glassBorderBright: Color(0xFFD1D5DB),

      // Special states
      breaking: Color(0xFFDC2626),
      error: Color(0xFFEF4444),
      warning: Color(0xFFF59E0B),
      success: Color(0xFF10B981),
      info: Color(0xFF3B82F6),

      // Navigation
      navSelected: Color(0xFF0E9F6E),
      navUnselected: Color(0xFF6B7280),

      // Dialog & inputs
      dialogBackground: Color(0xFFFFFFFF),
      categoryChipBg: Color(0xFFF3F4F6),
      inputFill: Color(0xFFF3F4F6),
      inputBorder: Color(0xFFD1D5DB),

      // Snack bar
      snackBarBg: Color(0xFF374151),

      // Divider and shimmer
      divider: Color(0xFFE5E7EB),
      shimmerBase: Color(0xFFF3F4F6),
      shimmerHighlight: Color(0xFFE8E8E8),
    );
  }

  static AppPalette _createDarkColors() {
    return const AppPalette(
      // Primary brand
      primary: Color(0xFF10B981),
      primaryDark: Color(0xFF059669),

      // Background surfaces
      scaffoldBackground: Color(0xFF0D0D0D),
      surface: Color(0xFF1A1A1A),
      cardBorder: Color(0xFF2D2D2D),

      // Text hierarchy
      textPrimary: Color(0xFFFFFFFF),
      textSecondary: Color(0xFFE5E7EB),
      textTertiary: Color(0xFF9CA3AF),
      textHint: Color(0xFF6B7280),

      // Brand accents
      accentGreen: Color(0xFF10B981),
      accentGreenLight: Color(0xFF6EE7B7),
      accentOrange: Color(0xFFF97316),
      accentOrangeLight: Color(0xFFFFA94D),
      accentPurple: Color(0xFFA78BFA),

      // Gradients for visual interest
      gradientStart: Color(0xFF0EA5E9),
      gradientMid: Color(0xFF8B5CF6),
      gradientEnd: Color(0xFFEC4899),

      // Support colors
      blobGreen: Color(0xFF10B981),
      blobPurple: Color(0xFF8B5CF6),
      blobOrange: Color(0xFFF97316),

      // Glass surfaces
      glassSurface: Color(0xFF1A1A1A),
      glassBorder: Color(0xFF2D2D2D),
      glassBorderBright: Color(0xFF3D3D3D),

      // Special states
      breaking: Color(0xFFEF4444),
      error: Color(0xFFF87171),
      warning: Color(0xFFFBBF24),
      success: Color(0xFF34D399),
      info: Color(0xFF60A5FA),

      // Navigation
      navSelected: Color(0xFF10B981),
      navUnselected: Color(0xFF9CA3AF),

      // Dialog & inputs
      dialogBackground: Color(0xFF1A1A1A),
      categoryChipBg: Color(0xFF2D2D2D),
      inputFill: Color(0xFF2D2D2D),
      inputBorder: Color(0xFF3D3D3D),

      // Snack bar
      snackBarBg: Color(0xFF374151),

      // Divider and shimmer
      divider: Color(0x33FFFFFF),
      shimmerBase: Color(0x1AFFFFFF),
      shimmerHighlight: Color(0x26FFFFFF),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // TEXT THEME CREATION
  // ════════════════════════════════════════════════════════════════════
  static TextTheme _createTextTheme(AppPalette colors, {required bool isDark}) {
    return TextTheme(
      // Display
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: colors.textPrimary,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: colors.textPrimary,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: colors.textPrimary,
      ),

      // Headline
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: colors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: colors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: colors.textPrimary,
      ),

      // Title
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: colors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: colors.textPrimary,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: colors.textPrimary,
      ),

      // Body
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: colors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: colors.textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: colors.textSecondary,
      ),

      // Label
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: colors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: colors.textPrimary,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: colors.textSecondary,
      ),
    );
  }
}