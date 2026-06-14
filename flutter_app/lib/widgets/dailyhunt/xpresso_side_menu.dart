import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants.dart';
import '../feed/feed_xpresso_theme.dart';
import 'xpresso_menu_scope.dart';

/// Dailyhunt Xpresso slide-out menu — flat black, bold labels, grouped sections.
class XpressoSideMenu extends StatelessWidget {
  const XpressoSideMenu({super.key});

  static const double _minWidth = 280;
  static const double _maxWidth = 340;
  static const double _widthFactor = 0.78;

  static void open(BuildContext context) => XpressoMenuScope.open(context);

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final screenW = MediaQuery.sizeOf(context).width;
    final width = (screenW * _widthFactor).clamp(_minWidth, _maxWidth);

    return Drawer(
      width: width,
      elevation: 0,
      backgroundColor: fx.background,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text(
                AppConstants.appName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fx.iconFgMuted,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  _SectionLabel(label: 'DISCOVER', fx: fx),
                  _XpressoMenuTile(
                    label: 'Discovery',
                    icon: Icons.explore_outlined,
                    onTap: () => _go(context, '/categories'),
                  ),
                  _XpressoMenuTile(
                    label: 'Political Reels',
                    icon: Icons.account_balance_outlined,
                    onTap: () => _go(context, '/political-reels'),
                  ),
                  _XpressoMenuTile(
                    label: 'Home of Sports',
                    icon: Icons.sports_cricket_outlined,
                    onTap: () => _go(context, '/sports'),
                  ),
                  _XpressoMenuTile(
                    label: 'Leaderboard',
                    icon: Icons.emoji_events_outlined,
                    onTap: () => _go(context, '/sports/leaderboard'),
                  ),
                  const SizedBox(height: 8),
                  _SectionLabel(label: 'ACCOUNT', fx: fx),
                  _XpressoMenuTile(
                    label: 'Profile',
                    icon: Icons.person_outline_rounded,
                    onTap: () => _go(context, '/settings'),
                  ),
                  _XpressoMenuTile(
                    label: 'Settings',
                    icon: Icons.settings_outlined,
                    onTap: () => _go(context, '/settings'),
                  ),
                  _XpressoMenuTile(
                    label: 'Saved',
                    icon: Icons.bookmark_outline_rounded,
                    onTap: () => _go(context, '/bookmarks'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _close(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  static void _go(BuildContext context, String route) {
    _close(context);
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc != route) {
      context.go(route);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final FeedXpressoPalette fx;

  const _SectionLabel({required this.label, required this.fx});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fx.iconFgMuted,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _XpressoMenuTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? accent;

  const _XpressoMenuTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final iconColor = accent ?? fx.iconFg;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: fx.accent.withValues(alpha: 0.08),
        highlightColor: fx.accent.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              Icon(icon, size: 24, color: iconColor),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 19,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                    color: fx.title,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
