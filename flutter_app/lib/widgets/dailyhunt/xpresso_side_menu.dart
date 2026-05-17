import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants.dart';
import '../feed/feed_xpresso_theme.dart';
import 'xpresso_menu_scope.dart';

/// Dailyhunt Xpresso slide-out menu — flat black, bold labels, no cards.
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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
            _XpressoMenuTile(
              label: 'Discovery',
              icon: Icons.explore_outlined,
              onTap: () => _go(context, '/categories'),
            ),
            _XpressoMenuTile(
              label: 'Cricket',
              icon: Icons.sports_cricket_outlined,
              onTap: () => _go(context, '/sports'),
            ),
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
              label: 'Notifications',
              icon: Icons.notifications_none_rounded,
              onTap: () => _placeholder(context, 'No new notifications'),
            ),
            _XpressoMenuTile(
              label: 'Follow',
              icon: Icons.rss_feed_rounded,
              onTap: () => _placeholder(context, 'Follow — coming soon'),
            ),
            _XpressoMenuTile(
              label: 'Premium',
              icon: Icons.workspace_premium_outlined,
              onTap: () => _placeholder(context, 'Premium — coming soon'),
            ),
            const Spacer(),
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

  static void _placeholder(BuildContext context, String message) {
    _close(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
        width: 300,
        backgroundColor: const Color(0xFF1A1A1A),
      ),
    );
  }
}

class _XpressoMenuTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _XpressoMenuTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: fx.accent.withValues(alpha: 0.08),
        highlightColor: fx.accent.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 13, 20, 13),
          child: Row(
            children: [
              Icon(icon, size: 24, color: fx.iconFg),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 20,
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
