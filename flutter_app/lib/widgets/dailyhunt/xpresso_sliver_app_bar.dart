import 'package:flutter/material.dart';

import '../feed/feed_xpresso_theme.dart';

/// Pinned screen header — theme-aware title + hairline.
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
    final fx = FeedXpressoTheme.fx(context);
    return SliverAppBar(
      pinned: true,
      toolbarHeight: toolbarHeight,
      backgroundColor: fx.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      foregroundColor: fx.title,
      iconTheme: IconThemeData(color: fx.iconFg),
      title: Text(
        title,
        style: fx.screenTitleStyle.copyWith(fontSize: 18),
      ),
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: fx.divider),
      ),
    );
  }
}
