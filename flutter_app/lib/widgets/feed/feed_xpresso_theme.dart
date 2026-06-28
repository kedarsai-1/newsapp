import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/indic_fonts.dart';
import 'feed_xpresso_palette.dart';

export 'feed_xpresso_palette.dart';

extension FeedXpressoContext on BuildContext {
  FeedXpressoPalette get fx => FeedXpressoTheme.fx(this);
}

/// Dailyhunt Xpresso design tokens + global Material theme (light & dark).
abstract final class FeedXpressoTheme {
  static const FeedXpressoPalette _dark = FeedXpressoPalette.dark;

  /// Resolved palette for the current [Theme] — prefer over static getters.
  static FeedXpressoPalette fx(BuildContext context) {
    return Theme.of(context).extension<FeedXpressoPalette>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? FeedXpressoPalette.dark
            : FeedXpressoPalette.light);
  }

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color get background => _dark.background;
  static Color get chrome => _dark.chrome;
  static Color get surface => _dark.surface;
  static Color get surfaceElevated => _dark.surfaceElevated;
  static Color get sheet => _dark.sheet;
  static Color get divider => _dark.divider;
  static Color get imagePlaceholder => _dark.imagePlaceholder;
  static Color get iconSurface => _dark.iconSurface;
  static Color get iconFg => _dark.iconFg;
  static Color get iconFgMuted => _dark.iconFgMuted;
  static Color get title => _dark.title;
  static Color get summary => _dark.summary;
  static Color get meta => _dark.meta;
  static Color get cardSurface => _dark.cardSurface;
  static Color get actionMuted => _dark.actionMuted;
  static Color get actionActive => _dark.actionActive;
  static Color get chipInactive => _dark.chipInactive;
  static Color get chipActive => _dark.chipActive;
  static Color get chipInactiveBg => _dark.chipInactiveBg;
  static Color get chipInactiveBorder => _dark.chipInactiveBorder;
  static Color get scopePillIdle => _dark.scopePillIdle;
  static Color get scopePillActive => _dark.scopePillActive;
  static Color get scopePillBorderIdle => _dark.scopePillBorderIdle;
  static Color get scopePillBorderActive => _dark.scopePillBorderActive;
  static Color get scopePillTextIdle => _dark.scopePillTextIdle;
  static Color get scopePillTextActive => _dark.scopePillTextActive;
  static Color get shimmerBase => _dark.shimmerBase;
  static Color get shimmerHighlight => _dark.shimmerHighlight;
  static Color get verifiedBadge => _dark.verifiedBadge;
  static Color get shareAccent => _dark.shareAccent;
  static Color get accent => _dark.accent;
  static Color get sourceLabel => _dark.sourceLabel;

  /// Cinematic landscape frame — 16:9 (width ÷ height).
  static const double imageAspectRatio = 16 / 9;

  static const BoxFit imageFit = BoxFit.cover;

  static const Alignment imageAlignment = Alignment.center;

  /// Editorial card — fixed 16:9 hero.
  static double feedImageAspectRatio(double width) => imageAspectRatio;

  static const int titleMaxLines = 3;
  static const int summaryMaxLines = 1;

  static const double cardRadius = 10;
  static const BorderRadius cardBorderRadius = BorderRadius.all(Radius.circular(cardRadius));
  static const BorderRadius imageBorderRadius = BorderRadius.all(Radius.circular(cardRadius));

  static Color cardBorder(BuildContext context) => fx(context).divider;

  /// Horizontal gutter; divider separates cards.
  static const EdgeInsets cardMargin = EdgeInsets.fromLTRB(14, 12, 14, 12);

  static const double imageToTitleGap = 12;

  /// Copy block below the image.
  static const EdgeInsets rowContentPadding = EdgeInsets.fromLTRB(12, 10, 12, 10);

  static const EdgeInsets overlayContentPadding = rowContentPadding;

  /// Reserved width for like / share / bookmark so meta never overlaps.
  static const double actionRowWidth = 52;

  static TextStyle get titleStyle => _dark.titleStyle;
  static TextStyle get sourceStyle => _dark.sourceStyle;
  static TextStyle get summaryStyle => _dark.summaryStyle;
  static TextStyle get metaStyle => _dark.metaStyle;
  static TextStyle get chipStyle => _dark.chipStyle;
  static TextStyle get screenTitleStyle => _dark.screenTitleStyle;

  static Color get navBackground => _dark.navBackground;
  static Color get navActiveIcon => _dark.navActiveIcon;
  static Color get navActiveLabel => _dark.navActiveLabel;
  static Color get navInactiveIcon => _dark.navInactiveIcon;
  static Color get navInactiveLabel => _dark.navInactiveLabel;
  static Color get navActiveIndicator => _dark.navActiveIndicator;
  static const double navBarHeight = 46;
  static const double navIconSize = 20;
  static const double navLabelSize = 9;
  static const double navIndicatorWidth = 22;
  static const double navIndicatorHeight = 2.5;

  static double feedBottomInset(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + navBarHeight;

  static ThemeData theme() => darkTheme();

  static ThemeData darkTheme() =>
      buildTheme(palette: FeedXpressoPalette.dark, appPalette: AppPalette.xpresso);

  static ThemeData lightTheme() =>
      buildTheme(palette: FeedXpressoPalette.light, appPalette: AppPalette.light);

  static ThemeData buildTheme({
    required FeedXpressoPalette palette,
    required AppPalette appPalette,
  }) {
    final isLight = palette == FeedXpressoPalette.light;
    final scheme = isLight
        ? ColorScheme.light(
            brightness: Brightness.light,
            primary: palette.chipActive,
            onPrimary: Colors.white,
            secondary: palette.iconFgMuted,
            onSecondary: palette.title,
            surface: palette.background,
            onSurface: palette.title,
            onSurfaceVariant: palette.summary,
            surfaceContainerHighest: palette.surfaceElevated,
            outline: palette.divider,
            outlineVariant: palette.divider,
            error: const Color(0xFFDC2626),
            onError: Colors.white,
          )
        : ColorScheme.dark(
            brightness: Brightness.dark,
            primary: palette.iconFg,
            onPrimary: palette.title,
            secondary: palette.iconFgMuted,
            onSecondary: palette.title,
            surface: palette.background,
            onSurface: palette.title,
            onSurfaceVariant: palette.summary,
            surfaceContainerHighest: palette.surfaceElevated,
            surfaceContainerHigh: palette.surface,
            surfaceContainer: palette.surface,
            outline: palette.divider,
            outlineVariant: palette.divider,
            error: palette.error,
            onError: palette.title,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: isLight ? Brightness.light : Brightness.dark,
      extensions: <ThemeExtension<dynamic>>[palette, appPalette],
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      cardColor: palette.surfaceElevated,
      dividerColor: palette.divider,
      disabledColor: palette.iconFgMuted,
      hintColor: palette.meta,
      colorScheme: scheme,
      iconTheme: IconThemeData(color: palette.iconFg),
      primaryIconTheme: IconThemeData(color: palette.iconFg),
      textTheme: IndicFonts.textThemeFor(palette),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.title,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: palette.screenTitleStyle,
        iconTheme: IconThemeData(color: palette.iconFg),
      ),
      cardTheme: CardThemeData(
        color: palette.surfaceElevated,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: palette.divider, width: 0.5),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: palette.divider,
        thickness: 0.5,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.iconFg,
        textColor: palette.title,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: palette.title,
        ),
        subtitleTextStyle: TextStyle(color: palette.summary, fontSize: 13),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        labelStyle: TextStyle(color: palette.meta),
        hintStyle: TextStyle(color: palette.iconFgMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.divider, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: palette.iconFg, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surface,
        selectedColor: palette.iconSurface,
        disabledColor: palette.surface,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: palette.summary,
        ),
        secondaryLabelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: palette.title,
        ),
        side: BorderSide(color: palette.divider, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return palette.iconSurface;
            return palette.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return palette.title;
            return palette.summary;
          }),
          side: WidgetStateProperty.all(
            BorderSide(color: palette.divider, width: 0.5),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.title;
          return palette.iconFgMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.iconSurface;
          return palette.surfaceElevated;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return palette.iconFg;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(palette.background),
        side: BorderSide(color: palette.divider, width: 1),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.iconSurface,
          foregroundColor: palette.title,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.iconSurface,
          foregroundColor: palette.title,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: palette.iconFg),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.navBackground,
        selectedItemColor: palette.navActiveIcon,
        unselectedItemColor: palette.navInactiveIcon,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: palette.navBackground,
        indicatorColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        height: navBarHeight,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: navIconSize,
            color: selected ? palette.navActiveIcon : palette.navInactiveIcon,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: navLabelSize,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? palette.navActiveLabel : palette.navInactiveLabel,
          );
        }),
      ),
      drawerTheme: DrawerThemeData(
        elevation: 0,
        backgroundColor: palette.background,
        scrimColor: palette.drawerScrim,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.sheet,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: palette.divider, width: 0.5),
        ),
        titleTextStyle: palette.screenTitleStyle,
        contentTextStyle: TextStyle(color: palette.summary, fontSize: 14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.sheet,
        elevation: 0,
        modalElevation: 0,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: palette.iconFgMuted,
        dragHandleSize: const Size(36, 4),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          side: BorderSide(color: palette.divider, width: 0.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surfaceElevated,
        contentTextStyle: TextStyle(color: palette.title, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: palette.divider, width: 0.5),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.sheet,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: palette.divider, width: 0.5),
        ),
        textStyle: TextStyle(color: palette.title, fontSize: 14),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(color: palette.title),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.iconFg,
        linearTrackColor: palette.surfaceElevated,
      ),
    );
  }
}

/// Approx. row height at ~390pt width (16:9 hero + divider; copy lives on overlay).
/// Approx. row height at ~390pt width (16:9 image + copy + card margin).
const double kFeedRowExtent = 360;
