import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// Top bar: profile (left), logo/title (center), notifications (right).
/// Redesigned with modern glass morphism effects.
class DailyhuntHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onNotificationTap;

  const DailyhuntHomeAppBar({
    super.key,
    this.onProfileTap,
    this.onNotificationTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _GlassIconButton(
                  tooltip: 'Profile',
                  onTap: onProfileTap,
                  icon: Icons.person_rounded,
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // App logo with gradient
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              fx.accent,
                              fx.accent.withValues(alpha: 0.7),
                              fx.accentTertiary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: fx.accent.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.newspaper_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // App title
                      Text(
                        AppConstants.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: fx.title,
                        ),
                      ),
                    ],
                  ),
                ),
                _GlassIconButton(
                  tooltip: 'Notifications',
                  onTap: onNotificationTap,
                  icon: Icons.notifications_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass morphism icon button with modern press animation
class _GlassIconButton extends StatefulWidget {
  final Widget child;
  final String? tooltip;
  final VoidCallback? onTap;
  final IconData icon;

  const _GlassIconButton({
    required this.icon,
    this.tooltip,
    this.onTap,
  }) : child = const SizedBox.shrink();

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);

    final button = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _pressed ? 0.92 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _pressed
                ? fx.accent.withValues(alpha: 0.15)
                : fx.glassSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _pressed
                  ? fx.accent.withValues(alpha: 0.4)
                  : fx.glassBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: fx.accent.withValues(alpha: _pressed ? 0.15 : 0.05),
                blurRadius: _pressed ? 8 : 4,
                offset: Offset(0, _pressed ? 4 : 2),
              ),
            ],
          ),
          child: Icon(
            widget.icon,
            color: _pressed ? fx.accent : fx.iconFg,
            size: 22,
          ),
        ),
      ),
    );

    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}
