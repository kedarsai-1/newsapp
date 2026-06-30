import 'package:flutter/material.dart';

/// Enhanced Dailyhunt-branded feed colors with modern design system
@immutable
class FeedXpressoPaletteEnhanced extends ThemeExtension<FeedXpressoPaletteEnhanced> {
  // Enhanced Color Palette with modern gradients and better contrast
  static const _goldPrimary = Color(0xFFD4AF37);
  static const _goldSecondary = Color(0xFFE8C547);
  static const _purplePrimary = Color(0xFF8B5CF6);
  static const _purpleSecondary = Color(0xFFA78BFA);
  static const _tealPrimary = Color(0xFF14B8A6);
  static const _tealSecondary = Color(0xFF5EEAD4);
  static const _indigoPrimary = Color(0xFF6366F1);
  static const _indigoSecondary = Color(0xFF818CF8);

  // Base colors with improved contrast
  final Color background;
  final Color chrome;
  final Color surface;
  final Color surfaceElevated;
  final Color sheet;
  final Color cardSurface;
  final Color divider;
  final Color imagePlaceholder;

  // Typography enhanced with better readability
  final Color title;
  final Color subtitle;
  final Color summary;
  final Color meta;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  // Icon and action colors
  final Color iconSurface;
  final Color iconFg;
  final Color iconFgMuted;
  final Color actionMuted;
  final Color actionActive;
  final Color actionHover;

  // Chip and category enhancements
  final Color chipInactive;
  final Color chipActive;
  final Color chipInactiveBg;
  final Color chipInactiveBorder;
  final Color chipActiveBg;
  final Color chipActiveBorder;

  // Modern glass effects
  final Color glassSurface;
  final Color glassSurfaceBright;
  final Color glassBorder;
  final Color glassBorderBright;
  final Color glassOverlay;

  // Accent colors for different actions
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

  // Enhanced gradients and special colors
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color live;
  final Color verifiedBadge;
  final Color shareAccent;
  final Color liked;
  final Color favorite;

  // Navigation and brand
  final Color navBackground;
  final Color navActiveIcon;
  final Color navActiveLabel;
  final Color navInactiveIcon;
  final Color navInactiveLabel;
  final Color navActiveIndicator;
  final Color brandGradientStart;
  final Color brandGradientEnd;

  // Enhanced shadows and overlays
  final Color heroShadow;
  final Color heroOverlay;
  final Color overlayScrim;
  final Color overlayFg;
  final Color overlayFgMuted;
  final Color backdropScrim;
  final Color shimmerBase;
  final Color shimmerHighlight;

  // Image and media enhanced
  final Color onImage;
  final Color onImageMuted;
  final Color onVideo;
  final Color onVideoMuted;
  final Color mediaViewerBackground;

  // Animation and interaction states
  final Color hoverSurface;
  final Color pressedSurface;
  final Color selectedSurface;
  final Color disabled;
  final Color borderFocus;

  const FeedXpressoPaletteEnhanced({
    required this.background,
    required this.chrome,
    required this.surface,
    required this.surfaceElevated,
    required this.sheet,
    required this.cardSurface,
    required this.divider,
    required this.imagePlaceholder,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.meta,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.iconSurface,
    required this.iconFg,
    required this.iconFgMuted,
    required this.actionMuted,
    required this.actionActive,
    required this.actionHover,
    required this.chipInactive,
    required this.chipActive,
    required this.chipInactiveBg,
    required this.chipInactiveBorder,
    required this.chipActiveBg,
    required this.chipActiveBorder,
    required this.glassSurface,
    required this.glassSurfaceBright,
    required this.glassBorder,
    required this.glassBorderBright,
    required this.glassOverlay,
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
    required this.live,
    required this.verifiedBadge,
    required this.shareAccent,
    required this.liked,
    required this.favorite,
    required this.navBackground,
    required this.navActiveIcon,
    required this.navActiveLabel,
    required this.navInactiveIcon,
    required this.navInactiveLabel,
    required this.navActiveIndicator,
    required this.brandGradientStart,
    required this.brandGradientEnd,
    required this.heroShadow,
    required this.heroOverlay,
    required this.overlayScrim,
    required this.overlayFg,
    required this.overlayFgMuted,
    required this.backdropScrim,
    required this.onImage,
    required this.onImageMuted,
    required this.onVideo,
    required this.onVideoMuted,
    required this.mediaViewerBackground,
    required this.hoverSurface,
    required this.pressedSurface,
    required this.selectedSurface,
    required this.disabled,
    required this.borderFocus,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  // Enhanced dark theme with modern aesthetics
  static const FeedXpressoPaletteEnhanced dark = FeedXpressoPaletteEnhanced(
    background: Color(0xFF0A0A0A),
    chrome: Color(0xFF0D0D0D),
    surface: Color(0xFF141414),
    surfaceElevated: Color(0xFF1A1A1A),
    sheet: Color(0xFF141414),
    cardSurface: Color(0xFF1A1A1A),
    divider: Color(0xFF2A2A2A),
    imagePlaceholder: Color(0xFF2A2A2A),
    title: Color(0xFFFFFFFF),
    subtitle: Color(0xFFE0E0E0),
    summary: Color(0xFFB0B0B0),
    meta: Color(0xFF8A8A8A),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0B0B0),
    textTertiary: Color(0xFF7A7A7A),
    iconSurface: Color(0xFF1A1A1A),
    iconFg: Color(0xFFFFFFFF),
    iconFgMuted: Color(0xFF8A8A8A),
    actionMuted: Color(0xFF8A8A8A),
    actionActive: Color(0xFFFFFFFF),
    actionHover: Color(0xFFD4AF37),
    chipInactive: Color(0xFF6A6A6A),
    chipActive: Color(0xFFFFFFFF),
    chipInactiveBg: Color(0xFF1A1A1A),
    chipInactiveBorder: Color(0xFF3A3A3A),
    chipActiveBg: Color(0xFFD4AF37),
    chipActiveBorder: Color(0xFFE8C547),
    glassSurface: Color(0x1A1A1A),
    glassSurfaceBright: Color(0x2A2A2A),
    glassBorder: Color(0xFF3A3A3A),
    glassBorderBright: Color(0xFF4A4A4A),
    glassOverlay: Color(0x80000000),
    accent: _goldPrimary,
    accentLight: _goldSecondary,
    accentSurface: Color(0x1AD4AF37),
    accentBorder: Color(0x66D4AF37),
    onAccent: Color(0xFF0A0A0A),
    accentSecondary: Color(0xFF97316),
    accentSecondaryLight: Color(0xFFDBA74),
    accentSecondarySurface: Color(0x26F97316),
    accentSecondaryBorder: Color(0x59F97316),
    accentTertiary: _purplePrimary,
    accentTertiaryLight: _purpleSecondary,
    accentTertiarySurface: Color(0x338B5CF6),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFE8B84A),
    error: Color(0xFFEF5350),
    info: Color(0xFF64B5F6),
    live: Color(0xFFE53935),
    verifiedBadge: Color(0xFF4A9EFF),
    shareAccent: Color(0xFF25D366),
    liked: Color(0xFFEF4444),
    favorite: Color(0xFFEF4444),
    navBackground: Color(0xFF080808),
    navActiveIcon: Color(0xFFF0F0F0),
    navActiveLabel: _goldPrimary,
    navInactiveIcon: Color(0xFF757575),
    navInactiveLabel: Color(0xFF757575),
    navActiveIndicator: _goldPrimary,
    brandGradientStart: _goldPrimary,
    brandGradientEnd: _purplePrimary,
    heroShadow: Color(0x33000000),
    heroOverlay: Color(0x88000000),
    overlayScrim: Color(0x99000000),
    overlayFg: Color(0xFFFFFFFF),
    overlayFgMuted: Color(0xB3FFFFFF),
    backdropScrim: Color(0x66000000),
    onImage: Color(0xFFFFFFFF),
    onImageMuted: Color(0xB3FFFFFF),
    onVideo: Color(0xFFFFFFFF),
    onVideoMuted: Color(0xB3FFFFFF),
    mediaViewerBackground: Color(0xFF000000),
    hoverSurface: Color(0xFF252525),
    pressedSurface: Color(0xFF1F1F1F),
    selectedSurface: Color(0xFFD4AF371A),
    disabled: Color(0xFF4A4A4A),
    borderFocus: _goldPrimary,
    shimmerBase: Color(0xFF1A1A1A),
    shimmerHighlight: Color(0xFF2A2A2A),
  );

  // Enhanced light theme with modern aesthetics
  static const FeedXpressoPaletteEnhanced light = FeedXpressoPaletteEnhanced(
    background: Color(0xFFFFFFFF),
    chrome: Color(0xFFFFFFFF),
    surface: Color(0xFFF8F9FA),
    surfaceElevated: Color(0xFFFFFFFF),
    sheet: Color(0xFFFFFFFF),
    cardSurface: Color(0xFFFFFFFF),
    divider: Color(0xFFE0E0E0),
    imagePlaceholder: Color(0xFFF0F0F0),
    title: Color(0xFF1A1A1A),
    subtitle: Color(0xFF4A4A4A),
    summary: Color(0xFF6B6B6B),
    meta: Color(0xFF8A8A8A),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF4A4A4A),
    textTertiary: Color(0xFF6B6B6B),
    iconSurface: Color(0xFFF5F5F5),
    iconFg: Color(0xFF2A2A2A),
    iconFgMuted: Color(0xFF7A7A7A),
    actionMuted: Color(0xFF6B6B6B),
    actionActive: Color(0xFF1A1A1A),
    actionHover: _goldPrimary,
    chipInactive: Color(0xFF6B6B6B),
    chipActive: Color(0xFF1A1A1A),
    chipInactiveBg: Color(0xFFF5F5F5),
    chipInactiveBorder: Color(0xFFE0E0E0),
    chipActiveBg: _goldPrimary,
    chipActiveBorder: _goldSecondary,
    glassSurface: Color(0xFFF8F8F8),
    glassSurfaceBright: Color(0xFFFFFBFE),
    glassBorder: Color(0xFFE0E0E0),
    glassBorderBright: Color(0xFFD5D5D5),
    glassOverlay: Color(0x20000000),
    accent: _goldPrimary,
    accentLight: _goldSecondary,
    accentSurface: Color(0x1AD4AF37),
    accentBorder: Color(0x33D4AF37),
    onAccent: Color(0xFFFFFFFF),
    accentSecondary: Color(0xFFEA580C),
    accentSecondaryLight: Color(0xFFFB923C),
    accentSecondarySurface: Color(0x14EA580C),
    accentSecondaryBorder: Color(0x40EA580C),
    accentTertiary: _purplePrimary,
    accentTertiaryLight: _purpleSecondary,
    accentTertiarySurface: Color(0x147C3AED),
    success: Color(0xFF059669),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
    info: Color(0xFF0284C7),
    live: Color(0xFFE53935),
    verifiedBadge: Color(0xFF1A73E8),
    shareAccent: Color(0xFF25D366),
    liked: Color(0xFFDC2626),
    favorite: Color(0xFFDC2626),
    navBackground: Color(0xFFFFFFFF),
    navActiveIcon: Color(0xFF1A1A1A),
    navActiveLabel: Color(0xFF1A1A1A),
    navInactiveIcon: Color(0xFFABABAB),
    navInactiveLabel: Color(0xFF9E9E9E),
    navActiveIndicator: _goldPrimary,
    brandGradientStart: _goldPrimary,
    brandGradientEnd: _purplePrimary,
    heroShadow: Color(0x1A000000),
    heroOverlay: Color(0xA6FFFFFF),
    overlayScrim: Color(0x66000000),
    overlayFg: Color(0xFF000000),
    overlayFgMuted: Color(0xB3000000),
    backdropScrim: Color(0x66000000),
    onImage: Color(0xFFFFFFFF),
    onImageMuted: Color(0xB3FFFFFF),
    onVideo: Color(0xFFFFFFFF),
    onVideoMuted: Color(0xB3FFFFFF),
    mediaViewerBackground: Color(0xFF000000),
    hoverSurface: Color(0xFFF0F0F0),
    pressedSurface: Color(0xFFE8E8E8),
    selectedSurface: Color(0xFFD4AF3714),
    disabled: Color(0xFFB0B0B0),
    borderFocus: _goldPrimary,
    shimmerBase: Color(0xFFE8E8E8),
    shimmerHighlight: Color(0xFFF8F8F8),
  );

  // Typography style methods for better hierarchy
  TextStyle get titleStyle => TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 17,
        height: 1.3,
        letterSpacing: -0.35,
        color: title,
      );

  TextStyle get subtitleStyle => TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        height: 1.3,
        letterSpacing: -0.2,
        color: subtitle,
      );

  TextStyle get summaryStyle => TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        height: 1.4,
        color: summary,
      );

  TextStyle get metaStyle => TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        height: 1.2,
        letterSpacing: 0.1,
        color: meta,
      );

  TextStyle get cardTitleStyle => TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 16,
        height: 1.25,
        letterSpacing: -0.2,
        color: title,
      );

  TextStyle get cardSubtitleStyle => TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        height: 1.3,
        color: subtitle,
      );

  // Enhanced category gradients with modern design
  static (String emoji, List<Color> gradient) categoryGradientEnhanced(String name) {
    final n = name.toLowerCase();
    if (n.contains('polit')) {
      return ('🏛️', [_purplePrimary, _purpleSecondary]);
    }
    if (n.contains('sport')) {
      return ('⚽', [_tealPrimary, _tealSecondary]);
    }
    if (n.contains('entert')) {
      return ('🎬', [Color(0xFFFF6B6B), Color(0xFFFF8E53)]);
    }
    if (n.contains('tech')) {
      return ('💻', [_indigoPrimary, _indigoSecondary]);
    }
    if (n.contains('business')) {
      return ('💼', [Color(0xFF00B4D8), Color(0xFF0077B6)]);
    }
    if (n.contains('health')) {
      return ('🏥', [Color(0xFF52B788), Color(0xFF2D6A4F)]);
    }
    if (n.contains('education')) {
      return ('📚', [Color(0xFFF72585), Color(0xFFB5179E)]);
    }
    if (n.contains('crime')) {
      return ('🚔', [Color(0xFFFB8500), Color(0xFFFFB700)]);
    }
    if (n.contains('agriculture')) {
      return ('🌾', [Color(0xFF90E0EF), Color(0xFF0077B6)]);
    }
    if (n.contains('jobs')) {
      return ('💼', [Color(0xFF7209B7), Color(0xFF560BAD)]);
    }
    if (n.contains('local')) {
      return ('🏙️', [Color(0xFF4CC9F0), Color(0xFF4361EE)]);
    }
    return ('📰', [_goldPrimary, _goldSecondary]);
  }

  // Modern glass morphism widget builder
  BoxDecoration get glassBox => BoxDecoration(
        color: glassSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: glassBorder.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      );

  // Enhanced gradient builder
  LinearGradient get brandGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [brandGradientStart, brandGradientEnd],
      );

  @override
  FeedXpressoPaletteEnhanced copyWith() => this;

  @override
  FeedXpressoPaletteEnhanced lerp(
      ThemeExtension<FeedXpressoPaletteEnhanced>? other, double t) {
    if (other is! FeedXpressoPaletteEnhanced) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return FeedXpressoPaletteEnhanced(
      background: l(background, other.background),
      chrome: l(chrome, other.chrome),
      surface: l(surface, other.surface),
      surfaceElevated: l(surfaceElevated, other.surfaceElevated),
      sheet: l(sheet, other.sheet),
      cardSurface: l(cardSurface, other.cardSurface),
      divider: l(divider, other.divider),
      imagePlaceholder: l(imagePlaceholder, other.imagePlaceholder),
      title: l(title, other.title),
      subtitle: l(subtitle, other.subtitle),
      summary: l(summary, other.summary),
      meta: l(meta, other.meta),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      iconSurface: l(iconSurface, other.iconSurface),
      iconFg: l(iconFg, other.iconFg),
      iconFgMuted: l(iconFgMuted, other.iconFgMuted),
      actionMuted: l(actionMuted, other.actionMuted),
      actionActive: l(actionActive, other.actionActive),
      actionHover: l(actionHover, other.actionHover),
      chipInactive: l(chipInactive, other.chipInactive),
      chipActive: l(chipActive, other.chipActive),
      chipInactiveBg: l(chipInactiveBg, other.chipInactiveBg),
      chipInactiveBorder: l(chipInactiveBorder, other.chipInactiveBorder),
      chipActiveBg: l(chipActiveBg, other.chipActiveBg),
      chipActiveBorder: l(chipActiveBorder, other.chipActiveBorder),
      glassSurface: l(glassSurface, other.glassSurface),
      glassSurfaceBright: l(glassSurfaceBright, other.glassSurfaceBright),
      glassBorder: l(glassBorder, other.glassBorder),
      glassBorderBright: l(glassBorderBright, other.glassBorderBright),
      glassOverlay: l(glassOverlay, other.glassOverlay),
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
      live: l(live, other.live),
      verifiedBadge: l(verifiedBadge, other.verifiedBadge),
      shareAccent: l(shareAccent, other.shareAccent),
      liked: l(liked, other.liked),
      favorite: l(favorite, other.favorite),
      navBackground: l(navBackground, other.navBackground),
      navActiveIcon: l(navActiveIcon, other.navActiveIcon),
      navActiveLabel: l(navActiveLabel, other.navActiveLabel),
      navInactiveIcon: l(navInactiveIcon, other.navInactiveIcon),
      navInactiveLabel: l(navInactiveLabel, other.navInactiveLabel),
      navActiveIndicator: l(navActiveIndicator, other.navActiveIndicator),
      brandGradientStart: l(brandGradientStart, other.brandGradientStart),
      brandGradientEnd: l(brandGradientEnd, other.brandGradientEnd),
      heroShadow: l(heroShadow, other.heroShadow),
      heroOverlay: l(heroOverlay, other.heroOverlay),
      overlayScrim: l(overlayScrim, other.overlayScrim),
      overlayFg: l(overlayFg, other.overlayFg),
      overlayFgMuted: l(overlayFgMuted, other.overlayFgMuted),
      backdropScrim: l(backdropScrim, other.backdropScrim),
      shimmerBase: l(shimmerBase, other.shimmerBase),
      shimmerHighlight: l(shimmerHighlight, other.shimmerHighlight),
      onImage: l(onImage, other.onImage),
      onImageMuted: l(onImageMuted, other.onImageMuted),
      onVideo: l(onVideo, other.onVideo),
      onVideoMuted: l(onVideoMuted, other.onVideoMuted),
      mediaViewerBackground: l(mediaViewerBackground, other.mediaViewerBackground),
      hoverSurface: l(hoverSurface, other.hoverSurface),
      pressedSurface: l(pressedSurface, other.pressedSurface),
      selectedSurface: l(selectedSurface, other.selectedSurface),
      disabled: l(disabled, other.disabled),
      borderFocus: l(borderFocus, other.borderFocus),
    );
  }
}