import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants.dart';

/// Dark glassmorphism tokens so controls stay readable on light or dark hero media.
class ShortsChrome {
  ShortsChrome._();

  static Color panelFill(BuildContext _) =>
      Colors.black.withValues(alpha: 0.52);

  static Color borderSubtle(BuildContext _) =>
      Colors.white.withValues(alpha: 0.22);

  static const Color onPanel = Colors.white;
}

/// Top row: profile, centered logo/title, notifications (Dailyhunt Shorts style).
class ShortsTopBar extends StatelessWidget {
  const ShortsTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: Row(
          children: [
            ShortsGlassIconButton(
              icon: Icons.person_rounded,
              tooltip: 'Profile',
              onTap: () => context.push('/settings'),
            ),
            Expanded(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: ShortsChrome.panelFill(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: ShortsChrome.borderSubtle(context),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded,
                              color: context.palette.primary, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              AppConstants.appName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ShortsChrome.onPanel,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ShortsGlassIconButton(
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

class ShortsGlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  const ShortsGlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final child = ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: ShortsChrome.panelFill(context),
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(icon, color: ShortsChrome.onPanel, size: 22),
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}
