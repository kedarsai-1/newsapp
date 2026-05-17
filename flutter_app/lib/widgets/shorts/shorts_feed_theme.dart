import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../feed/feed_xpresso_palette.dart';
import '../feed/feed_xpresso_theme.dart';

/// Shorts feed colors — light & dark; video overlays use [onVideo] for contrast.
@immutable
class ShortsFeedPalette {
  final Color background;
  final Color card;
  final Color cardBorder;
  final Color surfaceMuted;
  final Color scrim;
  final Color title;
  final Color body;
  final Color meta;
  final Color accent;
  final Color onVideo;
  final Color onVideoMuted;
  final Color chromeFg;
  final Color chromeFgMuted;
  final Color iconOnChrome;
  final Color chipBg;
  final Color chipBorder;
  final Color chipFg;
  final Color chipFgActive;
  final Color shimmerBase;
  final Color shimmerHighlight;

  const ShortsFeedPalette({
    required this.background,
    required this.card,
    required this.cardBorder,
    required this.surfaceMuted,
    required this.scrim,
    required this.title,
    required this.body,
    required this.meta,
    required this.accent,
    required this.onVideo,
    required this.onVideoMuted,
    required this.chromeFg,
    required this.chromeFgMuted,
    required this.iconOnChrome,
    required this.chipBg,
    required this.chipBorder,
    required this.chipFg,
    required this.chipFgActive,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  static const dark = ShortsFeedPalette(
    background: Color(0xFF050505),
    card: Color(0xFF121212),
    cardBorder: Color(0xFF252525),
    surfaceMuted: Color(0xFF1A1A1A),
    scrim: Color(0x99000000),
    title: Color(0xFFF5F5F5),
    body: Color(0xFFB8B8B8),
    meta: Color(0xFF8A8A8A),
    accent: Color(0xFFFF3B30),
    onVideo: Color(0xFFF5F5F5),
    onVideoMuted: Color(0xB3FFFFFF),
    chromeFg: Color(0xFFF5F5F5),
    chromeFgMuted: Color(0x80FFFFFF),
    iconOnChrome: Color(0xFFFFFFFF),
    chipBg: Color(0xFF1A1A1A),
    chipBorder: Color(0xFF333333),
    chipFg: Color(0xB3FFFFFF),
    chipFgActive: Color(0xFF050505),
    shimmerBase: Color(0xFF1A1A1A),
    shimmerHighlight: Color(0xFF2A2A2A),
  );

  static ShortsFeedPalette fromFeed(FeedXpressoPalette fx, {required bool isDark}) {
    if (isDark) return dark;
    return ShortsFeedPalette(
      background: fx.background,
      card: fx.surfaceElevated,
      cardBorder: fx.divider,
      surfaceMuted: fx.iconSurface,
      scrim: const Color(0x66000000),
      title: fx.title,
      body: fx.summary,
      meta: fx.meta,
      accent: fx.accent,
      onVideo: const Color(0xFFF5F5F5),
      onVideoMuted: const Color(0xB3FFFFFF),
      chromeFg: fx.title,
      chromeFgMuted: fx.meta,
      iconOnChrome: fx.iconFg,
      chipBg: fx.surface,
      chipBorder: fx.chipInactiveBorder,
      chipFg: fx.chipInactive,
      chipFgActive: Colors.white,
      shimmerBase: fx.shimmerBase,
      shimmerHighlight: fx.shimmerHighlight,
    );
  }

  TextStyle titleStyle() => GoogleFonts.notoSans(
        color: title,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.28,
        letterSpacing: -0.25,
      );

  TextStyle metaStyle() => GoogleFonts.notoSans(
        color: meta,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.2,
      );

  TextStyle actionLabelStyle() => GoogleFonts.notoSans(
        color: body,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      );

  TextStyle verticalActionCountStyle() => GoogleFonts.notoSans(
        color: onVideo,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.1,
      );
}

/// Dailyhunt / YouTube Shorts–inspired tokens for the video feed.
abstract final class ShortsFeedTheme {
  static ShortsFeedPalette fx(BuildContext context) {
    final feed = FeedXpressoTheme.fx(context);
    return ShortsFeedPalette.fromFeed(
      feed,
      isDark: FeedXpressoTheme.isDark(context),
    );
  }

  static const Color background = Color(0xFF050505);
  static const Color card = Color(0xFF121212);
  static const Color cardBorder = Color(0xFF252525);
  static const Color surfaceMuted = Color(0xFF1A1A1A);
  static const Color scrim = Color(0x99000000);
  static const Color title = Color(0xFFF5F5F5);
  static const Color body = Color(0xFFB8B8B8);
  static const Color meta = Color(0xFF8A8A8A);
  static const Color accent = Color(0xFFFF3B30);

  static const double cardRadius = 16;
  static const double videoRadius = 14;
  static const double pageHPad = 12;
  static const double maxCardWidth = 440;

  static TextStyle get titleStyle => ShortsFeedPalette.dark.titleStyle();
  static TextStyle get metaStyle => ShortsFeedPalette.dark.metaStyle();
  static TextStyle get actionLabelStyle => ShortsFeedPalette.dark.actionLabelStyle();
  static TextStyle get verticalActionCountStyle =>
      ShortsFeedPalette.dark.verticalActionCountStyle();

  static String formatViews(int views) {
    if (views >= 10000000) {
      return '${(views / 1000000).toStringAsFixed(1)}Cr views';
    }
    if (views >= 100000) {
      return '${(views / 100000).toStringAsFixed(1)}L views';
    }
    if (views >= 1000) {
      return '${(views / 1000).toStringAsFixed(1)}K views';
    }
    if (views > 0) return '$views views';
    return '';
  }

  static String formatCountShort(int n) {
    if (n <= 0) return '';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  static String channelMeta({required int views, required String timeLabel}) {
    final parts = <String>[
      if (views > 0) formatViews(views),
      timeLabel,
    ];
    return parts.join(' · ');
  }
}
