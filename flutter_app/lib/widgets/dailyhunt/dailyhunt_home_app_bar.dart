import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../theme/dailyhunt_theme.dart';

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
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.white,
      elevation: 0,
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
                  child:
                      Icon(Icons.person_rounded, color: cs.onSurface, size: 22),
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
                          color: DailyhuntTheme.accentGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.article_rounded,
                          color: Colors.white,
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
                                    color: cs.onSurface,
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
                  child: Icon(Icons.notifications_none_rounded,
                      color: cs.onSurface, size: 22),
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

  const _IconCircleButton({
    required this.child,
    this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: const Color(0xFFF0F0F0),
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
