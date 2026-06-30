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
  final Color accentLight;
  final Color accentSurface;
  final Color accentBorder;
  final Color onAccent;
  final Color accentSecondary;
  final Color accentSecondaryLight;
  final Color accentSecondarySurface;
  final Color accentSecondaryBorder;
  final Color accentTertiary;
  final Color accentTertiaryLight;
  final Color accentTertiarySurface;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color glassSurface;
  final Color glassSurfaceBright;
  final Color glassBorder;
  final Color glassBorderBright;
  final Color sourceLabel;
  final Color navBackground;
  final Color navActiveIcon;
  final Color navActiveLabel;
  final Color navInactiveIcon;
  final Color navInactiveLabel;
  final Color navActiveIndicator;
  final Color drawerScrim;
  final Color errorSurface;
  final Color errorBorder;
  final Color onErrorSurface;
  final Color successSurface;
  final Color successBorder;
  final Color onSuccessSurface;
  final Color warningSurface;
  final Color warningBorder;
  final Color onWarningSurface;
  final Color heroOverlay;
  final Color heroOverlayBorder;
  final Color heroActionFg;
  final Color heroShadow;
  final Color heroFg;
  final Color heroFgMuted;
  final Color heroSurfaceSubtle;
  final Color heroSurfaceMuted;
  final Color overlayScrim;
  final Color overlayFg;
  final Color overlayFgMuted;
  final Color onImage;
  final Color onImageMuted;
  final Color liked;
  final Color favorite;
  final Color onVideo;
  final Color onVideoMuted;
  final Color mediaViewerBackground;
  final Color live;
  final Color brandGoogle;

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
    required this.accentLight,
    required this.accentSurface,
    required this.accentBorder,
    required this.onAccent,
    required this.accentSecondary,
    required this.accentSecondaryLight,
    required this.accentSecondarySurface,
    required this.accentSecondaryBorder,
    required this.accentTertiary,
    required this.accentTertiaryLight,
    required this.accentTertiarySurface,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.glassSurface,
    required this.glassSurfaceBright,
    required this.glassBorder,
    required this.glassBorderBright,
    required this.sourceLabel,
    required this.navBackground,
    required this.navActiveIcon,
    required this.navActiveLabel,
    required this.navInactiveIcon,
    required this.navInactiveLabel,
    required this.navActiveIndicator,
    required this.drawerScrim,
    required this.errorSurface,
    required this.errorBorder,
    required this.onErrorSurface,
    required this.successSurface,
    required this.successBorder,
    required this.onSuccessSurface,
    required this.warningSurface,
    required this.warningBorder,
    required this.onWarningSurface,
    required this.heroOverlay,
    required this.heroOverlayBorder,
    required this.heroActionFg,
    required this.heroShadow,
    required this.heroFg,
    required this.heroFgMuted,
    required this.heroSurfaceSubtle,
    required this.heroSurfaceMuted,
    required this.overlayScrim,
    required this.overlayFg,
    required this.overlayFgMuted,
    required this.onImage,
    required this.onImageMuted,
    required this.liked,
    required this.favorite,
    required this.onVideo,
    required this.onVideoMuted,
    required this.mediaViewerBackground,
    required this.live,
    required this.brandGoogle,
  });

  /// Primary body text — alias for [title].
  Color get textPrimary => title;

  /// Secondary body text — alias for [summary].
  Color get textSecondary => summary;

  /// Tertiary / caption text — alias for [meta].
  Color get textTertiary => meta;

  /// Hint / disabled text — alias for [iconFgMuted].
  Color get textHint => iconFgMuted;

  /// Video/image placeholder — alias for [imagePlaceholder].
  Color get videoPlaceholder => imagePlaceholder;

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

  /// Zodiac / decorative card gradients (12 signs).
  static const List<List<Color>> zodiacSignGradients = [
    [Color(0xFFFFE0E0), Color(0xFFFFB4B4)],
    [Color(0xFFE8F5E9), Color(0xFFA5D6A7)],
    [Color(0xFFFFF8E1), Color(0xFFFFE082)],
    [Color(0xFFE3F2FD), Color(0xFF90CAF9)],
    [Color(0xFFFFF3E0), Color(0xFFFFB74D)],
    [Color(0xFFEDE7F6), Color(0xFFB39DDB)],
    [Color(0xFFFCE4EC), Color(0xFFF48FB1)],
    [Color(0xFFE0F2F1), Color(0xFF4DB6AC)],
    [Color(0xFFFFF3E0), Color(0xFFFFA726)],
    [Color(0xFFECEFF1), Color(0xFF90A4AE)],
    [Color(0xFFE1F5FE), Color(0xFF4FC3F7)],
    [Color(0xFFE8EAF6), Color(0xFF7986CB)],
  ];

  static const Color cricketPitchGreen = Color(0xFF0D7A3E);
  static const Color cricketPitchGreenDark = Color(0xFF065F46);

  /// Cricket team jersey accent colors keyed by team code.
  static Color cricketTeamColor(String code) {
    switch (code.toUpperCase()) {
      case 'IND':
        return const Color(0xFF1F4FA0);
      case 'AUS':
        return const Color(0xFFF7C500);
      case 'ENG':
        return const Color(0xFFD7152B);
      case 'PAK':
        return cricketPitchGreen;
      case 'NZ':
        return const Color(0xFF1F4FA0);
      case 'SA':
        return const Color(0xFF00897B);
      case 'WI':
        return const Color(0xFF512DA8);
      case 'SL':
        return const Color(0xFF1565C0);
      default:
        return const Color(0xFF6B7280);
    }
  }

  /// Category chip gradient colors + emoji for feed scope pills.
  static (String emoji, List<Color> gradient) categoryGradient(String name) {
    final n = name.toLowerCase();
    if (n.contains('polit')) {
      return ('🏛️', [const Color(0xFFC084FC), const Color(0xFF8B5CF6)]);
    }
    if (n.contains('sport')) {
      return ('⚽', [const Color(0xFF34D399), const Color(0xFF059669)]);
    }
    if (n.contains('entert')) {
      return ('🎬', [const Color(0xFFFBBF24), const Color(0xFFD97706)]);
    }
    if (n.contains('tech')) {
      return ('💻', [const Color(0xFF38BDF8), const Color(0xFF0284C7)]);
    }
    if (n.contains('busin')) {
      return ('💼', [const Color(0xFFF472B6), const Color(0xFFDB2777)]);
    }
    if (n.contains('financ') || n.contains('market')) {
      return ('📈', [const Color(0xFF2DD4BF), const Color(0xFF0D9488)]);
    }
    if (n.contains('health')) {
      return ('🩺', [const Color(0xFFF87171), const Color(0xFFDC2626)]);
    }
    if (n.contains('educat')) {
      return ('🎓', [const Color(0xFF818CF8), const Color(0xFF4F46E5)]);
    }
    if (n.contains('local')) {
      return ('📍', [const Color(0xFFF97316), const Color(0xFFEA580C)]);
    }
    if (n.contains('crime')) {
      return ('🚨', [const Color(0xFFFCA5A5), const Color(0xFFEF4444)]);
    }
    if (n.contains('weather')) {
      return ('🌦️', [const Color(0xFF7DD3FC), const Color(0xFF0EA5E9)]);
    }
    if (n.contains('general')) {
      return ('📰', [const Color(0xFFD1D5DB), const Color(0xFF9CA3AF)]);
    }
    return ('📰', [const Color(0xFF9A9A9A), const Color(0xFF5C5C5C)]);
  }

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
    accentLight: Color(0xFFE8C547),
    accentSurface: Color(0x1AD4AF37),
    accentBorder: Color(0x66D4AF37),
    onAccent: Color(0xFF0A0A0A),
    accentSecondary: Color(0xFFF97316),
    accentSecondaryLight: Color(0xFFFDBA74),
    accentSecondarySurface: Color(0x26F97316),
    accentSecondaryBorder: Color(0x59F97316),
    accentTertiary: Color(0xFFC084FC),
    accentTertiaryLight: Color(0xFFE9D5FF),
    accentTertiarySurface: Color(0x33C084FC),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFE8B84A),
    error: Color(0xFFEF5350),
    info: Color(0xFF64B5F6),
    glassSurface: Color(0xFF141414),
    glassSurfaceBright: Color(0xFF1A1A1A),
    glassBorder: Color(0xFF2E2E2E),
    glassBorderBright: Color(0xFF3A3A3A),
    sourceLabel: Color(0xFFB0B0B0),
    navBackground: Color(0xFF080808),
    navActiveIcon: Color(0xFFF0F0F0),
    navActiveLabel: Color(0xFFD4AF37),
    navInactiveIcon: Color(0xFF757575),
    navInactiveLabel: Color(0xFF757575),
    navActiveIndicator: Color(0xFFD4AF37),
    drawerScrim: Color(0x99000000),
    errorSurface: Color(0xFF2A1518),
    errorBorder: Color(0xFF5C2B30),
    onErrorSurface: Color(0xFFFCA5A5),
    successSurface: Color(0xFF0D2818),
    successBorder: Color(0xFF166534),
    onSuccessSurface: Color(0xFF86EFAC),
    warningSurface: Color(0xFF2D2410),
    warningBorder: Color(0xFF78590A),
    onWarningSurface: Color(0xFFFCD34D),
    heroOverlay: Color(0x66000000),
    heroOverlayBorder: Color(0x29FFFFFF),
    heroActionFg: Color(0xFFFFFFFF),
    heroShadow: Color(0x26000000),
    heroFg: Color(0xEBFFFFFF),
    heroFgMuted: Color(0xB3FFFFFF),
    heroSurfaceSubtle: Color(0x0AFFFFFF),
    heroSurfaceMuted: Color(0x1AFFFFFF),
    overlayScrim: Color(0x99000000),
    overlayFg: Color(0xFFF5F5F5),
    overlayFgMuted: Color(0xB3FFFFFF),
    onImage: Color(0xFFFFFFFF),
    onImageMuted: Color(0xB3FFFFFF),
    liked: Color(0xFFEF4444),
    favorite: Color(0xFFEF4444),
    onVideo: Color(0xFFF5F5F5),
    onVideoMuted: Color(0xB3FFFFFF),
    mediaViewerBackground: Color(0xFF000000),
    live: Color(0xFFE53935),
    brandGoogle: Color(0xFF4285F4),
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
    accentLight: Color(0xFF333333),
    accentSurface: Color(0x0F1A1A1A),
    accentBorder: Color(0x331A1A1A),
    onAccent: Color(0xFFFFFFFF),
    accentSecondary: Color(0xFFEA580C),
    accentSecondaryLight: Color(0xFFF97316),
    accentSecondarySurface: Color(0x14EA580C),
    accentSecondaryBorder: Color(0x40EA580C),
    accentTertiary: Color(0xFF7C3AED),
    accentTertiaryLight: Color(0xFFA78BFA),
    accentTertiarySurface: Color(0x147C3AED),
    success: Color(0xFF059669),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
    info: Color(0xFF0284C7),
    glassSurface: Color(0xFFF5F5F5),
    glassSurfaceBright: Color(0xFFEFEFEF),
    glassBorder: Color(0xFFE3E3E3),
    glassBorderBright: Color(0xFFD5D5D5),
    sourceLabel: Color(0xFF3A3A3A),
    navBackground: Color(0xFFFFFFFF),
    navActiveIcon: Color(0xFF1A1A1A),
    navActiveLabel: Color(0xFF1A1A1A),
    navInactiveIcon: Color(0xFFABABAB),
    navInactiveLabel: Color(0xFF9E9E9E),
    navActiveIndicator: Color(0xFF1A1A1A),
    drawerScrim: Color(0x66000000),
    errorSurface: Color(0xFFFEF2F2),
    errorBorder: Color(0xFFFECACA),
    onErrorSurface: Color(0xFFB91C1C),
    successSurface: Color(0xFFECFDF5),
    successBorder: Color(0xFFA7F3D0),
    onSuccessSurface: Color(0xFF047857),
    warningSurface: Color(0xFFFEF3C7),
    warningBorder: Color(0xFFFDE68A),
    onWarningSurface: Color(0xFFB45309),
    heroOverlay: Color(0xA6FFFFFF),
    heroOverlayBorder: Color(0x14000000),
    heroActionFg: Color(0xFF000000),
    heroShadow: Color(0x26000000),
    heroFg: Color(0xEB1A1A1A),
    heroFgMuted: Color(0xB35C5C5C),
    heroSurfaceSubtle: Color(0x08000000),
    heroSurfaceMuted: Color(0x0F000000),
    overlayScrim: Color(0x66000000),
    overlayFg: Color(0xFFFFFFFF),
    overlayFgMuted: Color(0xB3FFFFFF),
    onImage: Color(0xFFFFFFFF),
    onImageMuted: Color(0xB3FFFFFF),
    liked: Color(0xFFDC2626),
    favorite: Color(0xFFDC2626),
    onVideo: Color(0xFFF5F5F5),
    onVideoMuted: Color(0xB3FFFFFF),
    mediaViewerBackground: Color(0xFF000000),
    live: Color(0xFFE53935),
    brandGoogle: Color(0xFF4285F4),
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
      accentLight: l(accentLight, other.accentLight),
      accentSurface: l(accentSurface, other.accentSurface),
      accentBorder: l(accentBorder, other.accentBorder),
      onAccent: l(onAccent, other.onAccent),
      accentSecondary: l(accentSecondary, other.accentSecondary),
      accentSecondaryLight: l(accentSecondaryLight, other.accentSecondaryLight),
      accentSecondarySurface: l(accentSecondarySurface, other.accentSecondarySurface),
      accentSecondaryBorder: l(accentSecondaryBorder, other.accentSecondaryBorder),
      accentTertiary: l(accentTertiary, other.accentTertiary),
      accentTertiaryLight: l(accentTertiaryLight, other.accentTertiaryLight),
      accentTertiarySurface: l(accentTertiarySurface, other.accentTertiarySurface),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      error: l(error, other.error),
      info: l(info, other.info),
      glassSurface: l(glassSurface, other.glassSurface),
      glassSurfaceBright: l(glassSurfaceBright, other.glassSurfaceBright),
      glassBorder: l(glassBorder, other.glassBorder),
      glassBorderBright: l(glassBorderBright, other.glassBorderBright),
      sourceLabel: l(sourceLabel, other.sourceLabel),
      navBackground: l(navBackground, other.navBackground),
      navActiveIcon: l(navActiveIcon, other.navActiveIcon),
      navActiveLabel: l(navActiveLabel, other.navActiveLabel),
      navInactiveIcon: l(navInactiveIcon, other.navInactiveIcon),
      navInactiveLabel: l(navInactiveLabel, other.navInactiveLabel),
      navActiveIndicator: l(navActiveIndicator, other.navActiveIndicator),
      drawerScrim: l(drawerScrim, other.drawerScrim),
      errorSurface: l(errorSurface, other.errorSurface),
      errorBorder: l(errorBorder, other.errorBorder),
      onErrorSurface: l(onErrorSurface, other.onErrorSurface),
      successSurface: l(successSurface, other.successSurface),
      successBorder: l(successBorder, other.successBorder),
      onSuccessSurface: l(onSuccessSurface, other.onSuccessSurface),
      warningSurface: l(warningSurface, other.warningSurface),
      warningBorder: l(warningBorder, other.warningBorder),
      onWarningSurface: l(onWarningSurface, other.onWarningSurface),
      heroOverlay: l(heroOverlay, other.heroOverlay),
      heroOverlayBorder: l(heroOverlayBorder, other.heroOverlayBorder),
      heroActionFg: l(heroActionFg, other.heroActionFg),
      heroShadow: l(heroShadow, other.heroShadow),
      heroFg: l(heroFg, other.heroFg),
      heroFgMuted: l(heroFgMuted, other.heroFgMuted),
      heroSurfaceSubtle: l(heroSurfaceSubtle, other.heroSurfaceSubtle),
      heroSurfaceMuted: l(heroSurfaceMuted, other.heroSurfaceMuted),
      overlayScrim: l(overlayScrim, other.overlayScrim),
      overlayFg: l(overlayFg, other.overlayFg),
      overlayFgMuted: l(overlayFgMuted, other.overlayFgMuted),
      onImage: l(onImage, other.onImage),
      onImageMuted: l(onImageMuted, other.onImageMuted),
      liked: l(liked, other.liked),
      favorite: l(favorite, other.favorite),
      onVideo: l(onVideo, other.onVideo),
      onVideoMuted: l(onVideoMuted, other.onVideoMuted),
      mediaViewerBackground: l(mediaViewerBackground, other.mediaViewerBackground),
      live: l(live, other.live),
      brandGoogle: l(brandGoogle, other.brandGoogle),
    );
  }
}
