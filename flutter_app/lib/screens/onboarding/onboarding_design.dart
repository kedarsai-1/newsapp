import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/feed/feed_xpresso_theme.dart';

/// Onboarding & auth styling — follows app light/dark theme.
abstract final class OnboardingDesign {
  static const double radiusCard = 14;
  static const double radiusButton = 14;

  static Color background(BuildContext c) => FeedXpressoTheme.fx(c).background;
  static Color accent(BuildContext c) => FeedXpressoTheme.fx(c).accent;
  static Color accentDark(BuildContext c) => FeedXpressoTheme.fx(c).accent;
  static Color titleColor(BuildContext c) => FeedXpressoTheme.fx(c).title;
  static Color subtitleColor(BuildContext c) => FeedXpressoTheme.fx(c).summary;
  static Color outline(BuildContext c) => FeedXpressoTheme.fx(c).divider;

  static TextStyle titleStyle(BuildContext c) => GoogleFonts.notoSans(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: titleColor(c),
        height: 1.2,
        letterSpacing: -0.6,
      );

  static TextStyle subtitleStyle(BuildContext c) => GoogleFonts.notoSans(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: subtitleColor(c),
        height: 1.45,
      );

  static TextStyle buttonLabel(BuildContext c) => GoogleFonts.notoSans(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        letterSpacing: 0.2,
      );

  static TextStyle languageNative(BuildContext c) => GoogleFonts.notoSans(
        fontWeight: FontWeight.w700,
        fontSize: 17,
        color: titleColor(c),
      );

  static TextStyle languageEn(BuildContext c) => GoogleFonts.notoSans(
        fontWeight: FontWeight.w500,
        fontSize: 13,
        color: subtitleColor(c),
      );
}
