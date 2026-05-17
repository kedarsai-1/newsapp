import 'package:flutter/material.dart';

/// Resolved feed colors for light or dark — use [FeedXpressoTheme.fx].
@immutable
class FeedXpressoPalette extends ThemeExtension<FeedXpressoPalette> {
  final Color background;
  final Color chrome;
  final Color surface;
  final Color surfaceElevated;
  final Color sheet;
  final Color divider;
  final Color imagePlaceholder;
  final Color iconSurface;
  final Color iconFg;
  final Color iconFgMuted;
  final Color title;
  final Color summary;
  final Color meta;
  final Color cardSurface;
  final Color actionMuted;
  final Color actionActive;
  final Color chipInactive;
  final Color chipActive;
  final Color chipInactiveBg;
  final Color chipInactiveBorder;
  final Color scopePillIdle;
  final Color scopePillActive;
  final Color scopePillBorderIdle;
  final Color scopePillBorderActive;
  final Color scopePillTextIdle;
  final Color scopePillTextActive;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color verifiedBadge;
  final Color shareAccent;
  final Color accent;
  final Color sourceLabel;
  final Color navBackground;
  final Color navActiveIcon;
  final Color navActiveLabel;
  final Color navInactiveIcon;
  final Color navInactiveLabel;
  final Color navActiveIndicator;
  final Color drawerScrim;

  const FeedXpressoPalette({
    required this.background,
    required this.chrome,
    required this.surface,
    required this.surfaceElevated,
    required this.sheet,
    required this.divider,
    required this.imagePlaceholder,
    required this.iconSurface,
    required this.iconFg,
    required this.iconFgMuted,
    required this.title,
    required this.summary,
    required this.meta,
    required this.cardSurface,
    required this.actionMuted,
    required this.actionActive,
    required this.chipInactive,
    required this.chipActive,
    required this.chipInactiveBg,
    required this.chipInactiveBorder,
    required this.scopePillIdle,
    required this.scopePillActive,
    required this.scopePillBorderIdle,
    required this.scopePillBorderActive,
    required this.scopePillTextIdle,
    required this.scopePillTextActive,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.verifiedBadge,
    required this.shareAccent,
    required this.accent,
    required this.sourceLabel,
    required this.navBackground,
    required this.navActiveIcon,
    required this.navActiveLabel,
    required this.navInactiveIcon,
    required this.navInactiveLabel,
    required this.navActiveIndicator,
    required this.drawerScrim,
  });

  TextStyle get titleStyle => TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 17,
        height: 1.34,
        letterSpacing: -0.35,
        color: title,
      );

  TextStyle get sourceStyle => TextStyle(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: sourceLabel,
      );

  TextStyle get summaryStyle => TextStyle(
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w400,
        color: summary,
      );

  TextStyle get metaStyle => TextStyle(
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w400,
        color: meta,
      );

  TextStyle get chipStyle => const TextStyle(
        fontSize: 13,
        height: 1.1,
        letterSpacing: -0.1,
      );

  TextStyle get screenTitleStyle => TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 20,
        letterSpacing: -0.5,
        color: title,
      );

  static const FeedXpressoPalette dark = FeedXpressoPalette(
    background: Color(0xFF050505),
    chrome: Color(0xFF050505),
    surface: Color(0xFF0E0E0E),
    surfaceElevated: Color(0xFF161616),
    sheet: Color(0xFF0A0A0A),
    divider: Color(0xFF2E2E2E),
    imagePlaceholder: Color(0xFF121212),
    iconSurface: Color(0xFF1C1C1C),
    iconFg: Color(0xFF9A9A9A),
    iconFgMuted: Color(0xFF5C5C5C),
    title: Color(0xFFF7F7F7),
    summary: Color(0xFF757575),
    meta: Color(0xFF8A8A8A),
    cardSurface: Color(0xFF0C0C0C),
    actionMuted: Color(0xFF5C5C5C),
    actionActive: Color(0xFF9E9E9E),
    chipInactive: Color(0xFF9A9A9A),
    chipActive: Color(0xFFF7F7F7),
    chipInactiveBg: Color(0xFF141414),
    chipInactiveBorder: Color(0xFF333333),
    scopePillIdle: Color(0xFF181818),
    scopePillActive: Color(0xFFF5F5F5),
    scopePillBorderIdle: Color(0xFF4A4A4A),
    scopePillBorderActive: Color(0xFFF2F2F2),
    scopePillTextIdle: Color(0xFFB8B8B8),
    scopePillTextActive: Color(0xFF0A0A0A),
    shimmerBase: Color(0xFF1A1A1A),
    shimmerHighlight: Color(0xFF2A2A2A),
    verifiedBadge: Color(0xFF4A9EFF),
    shareAccent: Color(0xFF25D366),
    accent: Color(0xFFD4AF37),
    sourceLabel: Color(0xFFB0B0B0),
    navBackground: Color(0xFF080808),
    navActiveIcon: Color(0xFFF0F0F0),
    navActiveLabel: Color(0xFFD4AF37),
    navInactiveIcon: Color(0xFF424242),
    navInactiveLabel: Color(0xFF383838),
    navActiveIndicator: Color(0xFFD4AF37),
    drawerScrim: Color(0x99000000),
  );

  static const FeedXpressoPalette light = FeedXpressoPalette(
    background: Color(0xFFFFFFFF),
    chrome: Color(0xFFFFFFFF),
    surface: Color(0xFFF7F7F7),
    surfaceElevated: Color(0xFFFFFFFF),
    sheet: Color(0xFFFFFFFF),
    divider: Color(0xFFE5E5E5),
    imagePlaceholder: Color(0xFFF0F0F0),
    iconSurface: Color(0xFFF5F5F5),
    iconFg: Color(0xFF5C5C5C),
    iconFgMuted: Color(0xFF9E9E9E),
    title: Color(0xFF1A1A1A),
    summary: Color(0xFF5C5C5C),
    meta: Color(0xFF7A7A7A),
    cardSurface: Color(0xFFFFFFFF),
    actionMuted: Color(0xFF6B6B6B),
    actionActive: Color(0xFF1A1A1A),
    chipInactive: Color(0xFF6B6B6B),
    chipActive: Color(0xFF1A1A1A),
    chipInactiveBg: Color(0xFFF5F5F5),
    chipInactiveBorder: Color(0xFFE3E3E3),
    scopePillIdle: Color(0xFFF5F5F5),
    scopePillActive: Color(0xFF1A1A1A),
    scopePillBorderIdle: Color(0xFFE3E3E3),
    scopePillBorderActive: Color(0xFF1A1A1A),
    scopePillTextIdle: Color(0xFF555555),
    scopePillTextActive: Color(0xFFFFFFFF),
    shimmerBase: Color(0xFFE8E8E8),
    shimmerHighlight: Color(0xFFF8F8F8),
    verifiedBadge: Color(0xFF1A73E8),
    shareAccent: Color(0xFF25D366),
    accent: Color(0xFF1A1A1A),
    sourceLabel: Color(0xFF3A3A3A),
    navBackground: Color(0xFFFFFFFF),
    navActiveIcon: Color(0xFF1A1A1A),
    navActiveLabel: Color(0xFF1A1A1A),
    navInactiveIcon: Color(0xFFABABAB),
    navInactiveLabel: Color(0xFF9E9E9E),
    navActiveIndicator: Color(0xFF1A1A1A),
    drawerScrim: Color(0x66000000),
  );

  @override
  FeedXpressoPalette copyWith() => this;

  @override
  FeedXpressoPalette lerp(ThemeExtension<FeedXpressoPalette>? other, double t) {
    if (other is! FeedXpressoPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return FeedXpressoPalette(
      background: l(background, other.background),
      chrome: l(chrome, other.chrome),
      surface: l(surface, other.surface),
      surfaceElevated: l(surfaceElevated, other.surfaceElevated),
      sheet: l(sheet, other.sheet),
      divider: l(divider, other.divider),
      imagePlaceholder: l(imagePlaceholder, other.imagePlaceholder),
      iconSurface: l(iconSurface, other.iconSurface),
      iconFg: l(iconFg, other.iconFg),
      iconFgMuted: l(iconFgMuted, other.iconFgMuted),
      title: l(title, other.title),
      summary: l(summary, other.summary),
      meta: l(meta, other.meta),
      cardSurface: l(cardSurface, other.cardSurface),
      actionMuted: l(actionMuted, other.actionMuted),
      actionActive: l(actionActive, other.actionActive),
      chipInactive: l(chipInactive, other.chipInactive),
      chipActive: l(chipActive, other.chipActive),
      chipInactiveBg: l(chipInactiveBg, other.chipInactiveBg),
      chipInactiveBorder: l(chipInactiveBorder, other.chipInactiveBorder),
      scopePillIdle: l(scopePillIdle, other.scopePillIdle),
      scopePillActive: l(scopePillActive, other.scopePillActive),
      scopePillBorderIdle: l(scopePillBorderIdle, other.scopePillBorderIdle),
      scopePillBorderActive: l(scopePillBorderActive, other.scopePillBorderActive),
      scopePillTextIdle: l(scopePillTextIdle, other.scopePillTextIdle),
      scopePillTextActive: l(scopePillTextActive, other.scopePillTextActive),
      shimmerBase: l(shimmerBase, other.shimmerBase),
      shimmerHighlight: l(shimmerHighlight, other.shimmerHighlight),
      verifiedBadge: l(verifiedBadge, other.verifiedBadge),
      shareAccent: l(shareAccent, other.shareAccent),
      accent: l(accent, other.accent),
      sourceLabel: l(sourceLabel, other.sourceLabel),
      navBackground: l(navBackground, other.navBackground),
      navActiveIcon: l(navActiveIcon, other.navActiveIcon),
      navActiveLabel: l(navActiveLabel, other.navActiveLabel),
      navInactiveIcon: l(navInactiveIcon, other.navInactiveIcon),
      navInactiveLabel: l(navInactiveLabel, other.navInactiveLabel),
      navActiveIndicator: l(navActiveIndicator, other.navActiveIndicator),
      drawerScrim: l(drawerScrim, other.drawerScrim),
    );
  }
}
