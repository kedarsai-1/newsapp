import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/feed/feed_xpresso_theme.dart';

/// Global Dailyhunt Xpresso — light and dark platform themes.
abstract final class XpressoAppTheme {
  static ThemeData light() => FeedXpressoTheme.lightTheme();

  static ThemeData dark() => FeedXpressoTheme.darkTheme();

  static SystemUiOverlayStyle overlayFor(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: isLight
          ? FeedXpressoPalette.light.navBackground
          : FeedXpressoPalette.dark.navBackground,
      systemNavigationBarIconBrightness:
          isLight ? Brightness.dark : Brightness.light,
    );
  }
}
