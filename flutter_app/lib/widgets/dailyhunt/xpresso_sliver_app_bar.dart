import 'package:flutter/material.dart';

import '../feed/feed_xpresso_theme.dart';

/// Pinned screen header — black bar, bold white title.
class XpressoSliverAppBar extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final double toolbarHeight;

  const XpressoSliverAppBar({
    super.key,
    required this.title,
    this.actions,
    this.toolbarHeight = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      toolbarHeight: toolbarHeight,
      backgroundColor: FeedXpressoTheme.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      title: Text(title, style: FeedXpressoTheme.screenTitleStyle),
      actions: actions,
    );
  }
}
