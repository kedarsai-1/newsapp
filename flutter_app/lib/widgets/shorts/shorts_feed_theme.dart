import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dailyhunt / YouTube Shorts–inspired tokens for the video feed.
abstract final class ShortsFeedTheme {
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

  /// Card width cap on tablets / web for a phone-first Shorts feel.
  static const double maxCardWidth = 440;

  static TextStyle get titleStyle => GoogleFonts.notoSans(
        color: title,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.28,
        letterSpacing: -0.25,
      );

  static TextStyle get metaStyle => GoogleFonts.notoSans(
        color: meta,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.2,
      );

  static TextStyle get actionLabelStyle => GoogleFonts.notoSans(
        color: body,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get verticalActionCountStyle => GoogleFonts.notoSans(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.1,
      );

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

  /// Channel meta: "12K views · 2h ago"
  static String channelMeta({required int views, required String timeLabel}) {
    final parts = <String>[
      if (views > 0) formatViews(views),
      timeLabel,
    ];
    return parts.join(' · ');
  }
}
