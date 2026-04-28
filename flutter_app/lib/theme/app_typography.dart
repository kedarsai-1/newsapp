import 'package:flutter/material.dart';
import 'app_palette.dart';

/// Central typography system for the app.
///
/// Targets:
/// - Title: 16–18px, semi-bold, white
/// - Subtitle: 13–14px, medium grey
/// - Meta: 11–12px, light grey
///
/// Telugu/Indic readability: slightly taller line-height.
class AppTypography {
  AppTypography._();

  // Telugu and other Indic scripts benefit from extra leading.
  // Slightly increased vs default to avoid cramped glyphs/diacritics.
  static const double titleHeight = 1.26;
  static const double subtitleHeight = 1.44;
  static const double metaHeight = 1.28;
  static const double bodyHeight = 1.82;

  static const TextStyle headline = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.12,
    letterSpacing: -0.6,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: bodyHeight,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: metaHeight,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static TextTheme buildTextTheme(TextTheme base, AppPalette p) {
    // Map our hierarchy to standard TextTheme slots so most Text widgets
    // automatically get correct defaults.
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: headline.fontSize,
        fontWeight: headline.fontWeight,
        height: headline.height,
        letterSpacing: headline.letterSpacing,
        leadingDistribution: TextLeadingDistribution.even,
        color: p.textPrimary,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.16,
        letterSpacing: -0.4,
        leadingDistribution: TextLeadingDistribution.even,
        color: p.textPrimary,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: titleHeight,
        leadingDistribution: TextLeadingDistribution.even,
        color: p.textPrimary,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: titleHeight,
        leadingDistribution: TextLeadingDistribution.even,
        color: p.textPrimary,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: body.fontSize,
        fontWeight: body.fontWeight,
        height: body.height,
        leadingDistribution: TextLeadingDistribution.even,
        color: p.textPrimary,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        height: subtitleHeight,
        leadingDistribution: TextLeadingDistribution.even,
        color: p.textSecondary,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: caption.fontSize,
        fontWeight: caption.fontWeight,
        height: caption.height,
        leadingDistribution: TextLeadingDistribution.even,
        color: p.textHint,
      ),
    );
  }
}

extension AppTextStyles on BuildContext {
  TextTheme get textStyles => Theme.of(this).textTheme;

  TextStyle get headlineText =>
      textStyles.headlineMedium ??
      const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.16,
        leadingDistribution: TextLeadingDistribution.even,
      );

  TextStyle get titleText =>
      textStyles.titleMedium ??
      const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: AppTypography.titleHeight,
        leadingDistribution: TextLeadingDistribution.even,
      );

  TextStyle get subtitleText =>
      textStyles.bodySmall ??
      const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        height: AppTypography.subtitleHeight,
        leadingDistribution: TextLeadingDistribution.even,
      );

  TextStyle get metaText =>
      textStyles.labelSmall ??
      const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: AppTypography.metaHeight,
        leadingDistribution: TextLeadingDistribution.even,
      );
}
