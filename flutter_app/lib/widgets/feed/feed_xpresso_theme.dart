import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

/// Dailyhunt Xpresso design tokens + global Material theme.
abstract final class FeedXpressoTheme {
  static const Color background = Color(0xFF000000);
  static const Color chrome = Color(0xFF000000);
  static const Color surface = Color(0xFF0A0A0A);
  static const Color surfaceElevated = Color(0xFF141414);
  static const Color sheet = Color(0xFF0D0D0D);
  static const Color divider = Color(0xFF1E1E1E);
  static const Color imagePlaceholder = Color(0xFF0A0A0A);
  static const Color iconSurface = Color(0xFF1A1A1A);
  static const Color iconFg = Color(0xFF8A8A8A);
  static const Color iconFgMuted = Color(0xFF5A5A5A);

  static const Color title = Color(0xFFFFFFFF);
  static const Color summary = Color(0xFF6B6B6B);
  static const Color meta = Color(0xFF505050);

  static const Color cardSurface = Color(0xFF0C0C0C);
  static const Color actionMuted = Color(0xFF5C5C5C);
  static const Color actionActive = Color(0xFF9E9E9E);

  static const Color chipInactive = Color(0xFF5C5C5C);
  static const Color chipActive = Color(0xFFFFFFFF);

  static const Color shimmerBase = Color(0xFF141414);
  static const Color shimmerHighlight = Color(0xFF1E1E1E);

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

  /// Outer gutter + vertical rhythm between cards.
  static const EdgeInsets cardMargin = EdgeInsets.fromLTRB(12, 0, 12, 14);

  /// Copy block below the image.
  static const EdgeInsets rowContentPadding = EdgeInsets.fromLTRB(14, 12, 14, 13);

  static const EdgeInsets overlayContentPadding = rowContentPadding;

  /// Reserved width for like / share / bookmark so meta never overlaps.
  static const double actionRowWidth = 52;

  static const TextStyle titleStyle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 17,
    height: 1.32,
    letterSpacing: -0.35,
    color: title,
  );

  static const TextStyle summaryStyle = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w400,
    color: summary,
  );

  static const TextStyle metaStyle = TextStyle(
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w500,
    color: meta,
    letterSpacing: 0.02,
  );

  static const TextStyle chipStyle = TextStyle(
    fontSize: 11.5,
    height: 1.05,
    letterSpacing: -0.05,
  );

  static const TextStyle screenTitleStyle = TextStyle(
    fontWeight: FontWeight.w900,
    fontSize: 20,
    letterSpacing: -0.5,
    color: title,
  );

  // Bottom navigation — matte bar, no pill indicator.
  static const Color navBackground = Color(0xFF0C0C0C);
  static const Color navActiveIcon = Color(0xFFB8B8B8);
  static const Color navActiveLabel = Color(0xFF9A9A9A);
  static const Color navInactiveIcon = Color(0xFF424242);
  static const Color navInactiveLabel = Color(0xFF383838);
  static const Color navActiveIndicator = Color(0xFF8A8A8A);
  static const double navBarHeight = 42;
  static const double navIconSize = 18;
  static const double navLabelSize = 8;
  static const double navIndicatorWidth = 18;
  static const double navIndicatorHeight = 2;

  static double feedBottomInset(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + navBarHeight;

  static ThemeData theme() {
    const scheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: iconFg,
      onPrimary: title,
      secondary: iconFgMuted,
      onSecondary: title,
      surface: background,
      onSurface: title,
      onSurfaceVariant: summary,
      surfaceContainerHighest: surfaceElevated,
      surfaceContainerHigh: surface,
      surfaceContainer: surface,
      outline: divider,
      outlineVariant: divider,
      error: Color(0xFF9E9E9E),
      onError: title,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      extensions: const <ThemeExtension<dynamic>>[AppPalette.xpresso],
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: surfaceElevated,
      dividerColor: divider,
      disabledColor: iconFgMuted,
      hintColor: meta,
      colorScheme: scheme,
      iconTheme: const IconThemeData(color: iconFg),
      primaryIconTheme: const IconThemeData(color: iconFg),
      textTheme: const TextTheme(
        displaySmall: screenTitleStyle,
        titleLarge: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 17,
          color: title,
        ),
        titleMedium: titleStyle,
        titleSmall: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: title,
        ),
        bodyLarge: TextStyle(color: title, fontSize: 15),
        bodyMedium: TextStyle(color: summary, fontSize: 14),
        bodySmall: TextStyle(color: meta, fontSize: 12),
        labelMedium: TextStyle(
          color: meta,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: title,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: screenTitleStyle,
        iconTheme: IconThemeData(color: iconFg),
      ),
      cardTheme: CardThemeData(
        color: surfaceElevated,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: divider, width: 0.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 0.5,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: iconFg,
        textColor: title,
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: title,
        ),
        subtitleTextStyle: TextStyle(color: summary, fontSize: 13),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(color: meta),
        hintStyle: const TextStyle(color: iconFgMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: divider, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: iconFg, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: iconSurface,
        disabledColor: surface,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: summary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          color: title,
        ),
        side: const BorderSide(color: divider, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return iconSurface;
            return surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return title;
            return summary;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: divider, width: 0.5),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return title;
          return iconFgMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return iconSurface;
          return surfaceElevated;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return iconFg;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(background),
        side: const BorderSide(color: divider, width: 1),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: iconSurface,
          foregroundColor: title,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: iconSurface,
          foregroundColor: title,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: iconFg),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: navBackground,
        selectedItemColor: navActiveIcon,
        unselectedItemColor: navInactiveIcon,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: navBackground,
        indicatorColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        height: navBarHeight,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: navIconSize,
            color: selected ? navActiveIcon : navInactiveIcon,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: navLabelSize,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? navActiveLabel : navInactiveLabel,
          );
        }),
      ),
      drawerTheme: const DrawerThemeData(
        elevation: 0,
        backgroundColor: background,
        scrimColor: Color(0x99000000),
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: sheet,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: divider, width: 0.5),
        ),
        titleTextStyle: screenTitleStyle,
        contentTextStyle: const TextStyle(color: summary, fontSize: 14),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: sheet,
        elevation: 0,
        modalElevation: 0,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: iconFgMuted,
        dragHandleSize: Size(36, 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          side: BorderSide(color: divider, width: 0.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: const TextStyle(color: title, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: divider, width: 0.5),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: sheet,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: divider, width: 0.5),
        ),
        textStyle: const TextStyle(color: title, fontSize: 14),
      ),
      dropdownMenuTheme: const DropdownMenuThemeData(
        textStyle: TextStyle(color: title),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: iconFg,
        linearTrackColor: surfaceElevated,
      ),
    );
  }
}

/// Approx. row height at ~390pt width (16:9 hero + divider; copy lives on overlay).
/// Approx. row height at ~390pt width (16:9 image + copy + card margin).
const double kFeedRowExtent = 360;
