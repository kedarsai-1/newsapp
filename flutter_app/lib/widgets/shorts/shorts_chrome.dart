import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants.dart';
import '../dailyhunt/xpresso_side_menu.dart';

/// Thin segment progress for RSS shorts (bottom of screen, above nav).
class ShortsFeedProgress extends StatelessWidget {
  final int total;
  final int index;

  const ShortsFeedProgress({
    super.key,
    required this.total,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = total <= 0 ? 0.0 : (index + 1).clamp(1, total) / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: t,
        minHeight: 3,
        backgroundColor: Colors.white.withValues(alpha: 0.22),
        color: p.primary,
      ),
    );
  }
}

/// Profile · logo · notifications — flat dark buttons (no blur / glass).
class DailyhuntShortsTopBar extends StatelessWidget {
  const DailyhuntShortsTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        child: Row(
          children: [
            _TopIconButton(
              icon: Icons.person_outline_rounded,
              tooltip: 'Menu',
              onTap: () => XpressoSideMenu.open(context),
            ),
            Expanded(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.article_rounded, color: context.palette.primary, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        AppConstants.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _TopIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifications',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No new notifications'),
                    behavior: SnackBarBehavior.floating,
                    width: 300,
                    duration: Duration(milliseconds: 1200),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _TopIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.black.withValues(alpha: 0.42),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}
