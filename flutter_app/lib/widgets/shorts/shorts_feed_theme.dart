import 'package:flutter/material.dart';

/// Dailyhunt / YouTube Shorts–inspired tokens for the video feed.
abstract final class ShortsFeedTheme {
  static const Color background = Color(0xFF050505);
  static const Color card = Color(0xFF121212);
  static const Color cardBorder = Color(0xFF252525);
  static const Color surfaceMuted = Color(0xFF1A1A1A);

  static const Color title = Color(0xFFF5F5F5);
  static const Color body = Color(0xFFB8B8B8);
  static const Color meta = Color(0xFF8A8A8A);
  static const Color accent = Color(0xFFFF3B30);

  static const double cardRadius = 16;
  static const double videoRadius = 14;
  static const double pageHPad = 12;

  static const TextStyle titleStyle = TextStyle(
    color: title,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.28,
    letterSpacing: -0.25,
  );

  static const TextStyle metaStyle = TextStyle(
    color: meta,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  static const TextStyle actionLabelStyle = TextStyle(
    color: body,
    fontSize: 11,
    fontWeight: FontWeight.w600,
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
}
