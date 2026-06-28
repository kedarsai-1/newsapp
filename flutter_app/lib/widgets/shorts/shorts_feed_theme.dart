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

  static final dark = ShortsFeedPalette(
    background: FeedXpressoPalette.dark.background,
    card: FeedXpressoPalette.dark.surfaceElevated,
    cardBorder: FeedXpressoPalette.dark.divider,
    surfaceMuted: FeedXpressoPalette.dark.iconSurface,
    scrim: FeedXpressoPalette.dark.overlayScrim,
    title: FeedXpressoPalette.dark.title,
    body: FeedXpressoPalette.dark.summary,
    meta: FeedXpressoPalette.dark.meta,
    accent: FeedXpressoPalette.dark.liked,
    onVideo: FeedXpressoPalette.dark.onVideo,
    onVideoMuted: FeedXpressoPalette.dark.onVideoMuted,
    chromeFg: FeedXpressoPalette.dark.title,
    chromeFgMuted: FeedXpressoPalette.dark.meta,
    iconOnChrome: FeedXpressoPalette.dark.onImage,
    chipBg: FeedXpressoPalette.dark.surface,
    chipBorder: FeedXpressoPalette.dark.chipInactiveBorder,
    chipFg: FeedXpressoPalette.dark.chipInactive,
    chipFgActive: FeedXpressoPalette.dark.onAccent,
    shimmerBase: FeedXpressoPalette.dark.shimmerBase,
    shimmerHighlight: FeedXpressoPalette.dark.shimmerHighlight,
  );

  static ShortsFeedPalette fromFeed(FeedXpressoPalette fx, {required bool isDark}) {
    if (isDark) return dark;
    return ShortsFeedPalette(
      background: fx.background,
      card: fx.surfaceElevated,
      cardBorder: fx.divider,
      surfaceMuted: fx.iconSurface,
      scrim: fx.overlayScrim,
      title: fx.title,
      body: fx.summary,
      meta: fx.meta,
      accent: fx.accent,
      onVideo: fx.onVideo,
      onVideoMuted: fx.onVideoMuted,
      chromeFg: fx.title,
      chromeFgMuted: fx.meta,
      iconOnChrome: fx.iconFg,
      chipBg: fx.surface,
      chipBorder: fx.chipInactiveBorder,
      chipFg: fx.chipInactive,
      chipFgActive: fx.onVideo,
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

  static Color get background => ShortsFeedPalette.dark.background;
  static Color get card => ShortsFeedPalette.dark.card;
  static Color get cardBorder => ShortsFeedPalette.dark.cardBorder;
  static Color get surfaceMuted => ShortsFeedPalette.dark.surfaceMuted;
  static Color get scrim => ShortsFeedPalette.dark.scrim;
  static Color get title => ShortsFeedPalette.dark.title;
  static Color get body => ShortsFeedPalette.dark.body;
  static Color get meta => ShortsFeedPalette.dark.meta;
  static Color get accent => ShortsFeedPalette.dark.accent;

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
