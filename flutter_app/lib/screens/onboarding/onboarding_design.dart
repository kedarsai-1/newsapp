import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../design_system/dailyhunt/dailyhunt_tokens.dart';

/// Minimal Dailyhunt-adjacent styling for the lightweight onboarding flow (no glass).
abstract final class OnboardingDesign {
  static const Color background = Color(0xFFFFFFFF);
  static const Color accent = DhTokens.accent;
  static const Color accentDark = DhTokens.accentDark;
  static const Color titleColor = Color(0xFF111827);
  static const Color subtitleColor = Color(0xFF6B7280);
  static const Color outline = Color(0xFFE5E7EB);
  static const double radiusCard = 14;
  static const double radiusButton = 14;

  static TextStyle titleStyle() => GoogleFonts.notoSans(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: titleColor,
        height: 1.2,
        letterSpacing: -0.6,
      );

  static TextStyle subtitleStyle() => GoogleFonts.notoSans(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: subtitleColor,
        height: 1.45,
      );

  static TextStyle buttonLabel() => GoogleFonts.notoSans(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        letterSpacing: 0.2,
      );

  static TextStyle languageNative() => GoogleFonts.notoSans(
        fontWeight: FontWeight.w700,
        fontSize: 17,
      );

  static TextStyle languageEn() => GoogleFonts.notoSans(
        fontWeight: FontWeight.w500,
        fontSize: 13,
        color: subtitleColor,
      );
}
