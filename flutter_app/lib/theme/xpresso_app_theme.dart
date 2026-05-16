import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/feed/feed_xpresso_theme.dart';

/// Global Dailyhunt Xpresso — immersive dark platform theme.
abstract final class XpressoAppTheme {
  static ThemeData theme() => FeedXpressoTheme.theme();

  static SystemUiOverlayStyle get systemOverlay => const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: FeedXpressoTheme.navBackground,
        systemNavigationBarIconBrightness: Brightness.light,
      );
}
