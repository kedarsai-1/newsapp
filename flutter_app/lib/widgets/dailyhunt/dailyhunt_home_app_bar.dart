import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// Top bar: profile (left), logo/title (center), notifications (right).
class DailyhuntHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationTap;

  const DailyhuntHomeAppBar({
    super.key,
    this.onProfileTap,
    this.onNotificationTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return ColoredBox(
      color: fx.background,
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
                  backgroundColor: fx.iconSurface,
                  child: Icon(Icons.person_rounded, color: fx.iconFg, size: 22),
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
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              fx.accent.withValues(alpha: 0.35),
                              fx.iconSurface,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: fx.accent.withValues(alpha: 0.45),
                            width: 0.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.article_rounded,
                          color: fx.accent,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          AppConstants.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: fx.screenTitleStyle.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
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
                  backgroundColor: fx.iconSurface,
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: fx.iconFg,
                    size: 22,
                  ),
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
