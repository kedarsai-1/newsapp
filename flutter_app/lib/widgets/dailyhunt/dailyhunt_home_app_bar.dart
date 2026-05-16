import 'package:flutter/material.dart';

import '../../constants.dart';
import '../feed/feed_xpresso_theme.dart';

/// Top bar: profile (left), logo/title (center), notifications (right).
class DailyhuntHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationTap;
  final bool dark;

  const DailyhuntHomeAppBar({
    super.key,
    this.onProfileTap,
    this.onNotificationTap,
    this.dark = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final fg = dark ? FeedXpressoTheme.title : Theme.of(context).colorScheme.onSurface;
    final iconBg = dark ? FeedXpressoTheme.iconSurface : const Color(0xFFF0F0F0);
    final iconFg = dark ? FeedXpressoTheme.iconFg : fg;
    final logoBg = dark ? FeedXpressoTheme.iconSurface : const Color(0xFF0A8F57);
    final logoIcon = dark ? FeedXpressoTheme.iconFg : Colors.white;

    return ColoredBox(
      color: dark ? FeedXpressoTheme.background : Colors.white,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                _IconCircleButton(
                  tooltip: 'Profile',
                  onTap: onProfileTap,
                  backgroundColor: iconBg,
                  child: Icon(Icons.person_rounded, color: iconFg, size: 22),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: logoBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.article_rounded,
                          color: logoIcon,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          AppConstants.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.6,
                                    color: fg,
                                    fontSize: 20,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                _IconCircleButton(
                  tooltip: 'Notifications',
                  onTap: onNotificationTap,
                  backgroundColor: iconBg,
                  child: Icon(Icons.notifications_none_rounded, color: iconFg, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  final Widget child;
  final String? tooltip;
  final VoidCallback? onTap;
  final Color backgroundColor;

  const _IconCircleButton({
    required this.child,
    required this.backgroundColor,
    this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: 40, height: 40, child: Center(child: child)),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
