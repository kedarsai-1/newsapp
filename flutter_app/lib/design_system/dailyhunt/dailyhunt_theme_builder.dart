import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_palette.dart';
import 'dailyhunt_tokens.dart';
import 'dailyhunt_typography.dart';

/// Material 3 theme bundles: cards, buttons, app bar, bottom navigation.
class DailyhuntDesignThemes {
  DailyhuntDesignThemes._();

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  /// Light overlay merged with parent [context] (for embedding in host app).
  static ThemeData overlayLight(BuildContext context) {
    final parent = Theme.of(context);
    return light().copyWith(
      platform: parent.platform,
    );
  }

  /// Dark overlay merged with parent (optional Dailyhunt-dark shells).
  static ThemeData overlayDark(BuildContext context) {
    final parent = Theme.of(context);
    return dark().copyWith(
      platform: parent.platform,
    );
  }

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final cs = isLight ? DhTokens.lightColorScheme() : DhTokens.darkColorScheme();
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final textTheme = DhTypography.textTheme(
      base.textTheme,
      cs.onSurface,
      cs.onSurface,
    );

    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DhTokens.radiusCard),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: isLight ? DhTokens.lightScaffold : DhTokens.darkScaffold,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[
        isLight ? AppPalette.light : AppPalette.dark,
      ],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: isLight ? DhTokens.lightSurface : DhTokens.darkSurface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: cs.onSurface,
        ),
        iconTheme: IconThemeData(color: cs.onSurface.withValues(alpha: 0.85)),
        systemOverlayStyle: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: isLight ? DhTokens.lightSurface : DhTokens.darkSurfaceHigh,
        elevation: DhTokens.elevationCard,
        shadowColor: Colors.black.withValues(alpha: isLight ? 0.12 : 0.45),
        surfaceTintColor: Colors.transparent,
        shape: cardShape,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DhTokens.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DhTokens.radiusButton),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DhTokens.accent,
          side: const BorderSide(color: DhTokens.accent, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DhTokens.radiusButton),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        elevation: DhTokens.elevationNav,
        backgroundColor: isLight ? DhTokens.lightSurface : DhTokens.darkSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: DhTokens.accent.withValues(alpha: 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 26,
            color: selected ? DhTokens.accent : cs.onSurface.withValues(alpha: 0.55),
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? DhTokens.accent : cs.onSurface.withValues(alpha: 0.55),
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight ? const Color(0xFFF3F4F6) : DhTokens.darkSurfaceHigh,
        selectedColor: DhTokens.accent.withValues(alpha: 0.2),
        disabledColor: cs.onSurface.withValues(alpha: 0.08),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: cs.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DhTokens.radiusChip),
        ),
        side: BorderSide(color: isLight ? DhTokens.lightOutline : DhTokens.darkOutline),
      ),
      dividerTheme: DividerThemeData(
        color: cs.onSurface.withValues(alpha: isLight ? 0.08 : 0.12),
        thickness: 1,
      ),
    );
  }
}
