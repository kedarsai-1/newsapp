import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/feed/feed_xpresso_palette_enhanced.dart';

/// Enhanced bottom navigation bar with modern glass morphism design and smooth animations.
class EnhancedXpressoBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final FeedXpressoPaletteEnhanced palette;

  const EnhancedXpressoBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: palette.navBackground.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: palette.glassBorder.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 74 + bottomPadding,
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _EnhancedNavItem(
                icon: Icons.dynamic_feed_rounded,
                label: 'Feed',
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
                palette: palette,
              ),
              _EnhancedNavItem(
                icon: Icons.view_stream_rounded,
                label: 'Shorts',
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
                palette: palette,
              ),
              _EnhancedNavItem(
                icon: Icons.grid_view_rounded,
                label: 'Categories',
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
                palette: palette,
              ),
              _EnhancedNavItem(
                icon: Icons.bookmark_rounded,
                label: 'Saved',
                isSelected: currentIndex == 3,
                onTap: () => onTap(3),
                palette: palette,
              ),
              _EnhancedNavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                isSelected: currentIndex == 4,
                onTap: () => onTap(4),
                palette: palette,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnhancedNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final FeedXpressoPaletteEnhanced palette;

  const _EnhancedNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.palette,
  });

  @override
  State<_EnhancedNavItem> createState() => _EnhancedNavItemState();
}

class _EnhancedNavItemState extends State<_EnhancedNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? widget.palette.brandGradientStart.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: widget.isSelected ? 24 : 0,
                    height: 3,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      gradient: widget.isSelected
                          ? LinearGradient(
                              colors: [
                                widget.palette.brandGradientStart,
                                widget.palette.brandGradientEnd,
                              ],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: widget.isSelected
                          ? [
                              BoxShadow(
                                color: widget.palette.brandGradientStart
                                    .withValues(alpha: 0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  ),
                  // Icon with animated color and scale
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: 32,
                    height: 32,
                    decoration: widget.isSelected
                        ? BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                widget.palette.brandGradientStart,
                                widget.palette.brandGradientEnd,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: widget.palette.brandGradientStart
                                    .withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          )
                        : null,
                    child: Icon(
                      widget.isSelected
                          ? _filledIcon(widget.icon)
                          : _outlinedIcon(widget.icon),
                      size: 22,
                      color: widget.isSelected
                          ? widget.palette.onAccent
                          : widget.palette.navInactiveIcon,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Label
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    style: GoogleFonts.notoSans(
                      fontSize: 10,
                      fontWeight:
                          widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: widget.isSelected
                          ? widget.palette.brandGradientStart
                          : widget.palette.navInactiveLabel,
                    ),
                    child: Text(widget.label),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _filledIcon(IconData outlined) {
    if (outlined == Icons.dynamic_feed_outlined) return Icons.dynamic_feed_rounded;
    if (outlined == Icons.view_stream_outlined) return Icons.view_stream_rounded;
    if (outlined == Icons.grid_view_outlined) return Icons.grid_view_rounded;
    if (outlined == Icons.bookmark_outline) return Icons.bookmark_rounded;
    if (outlined == Icons.person_outline) return Icons.person_rounded;
    return outlined;
  }

  IconData _outlinedIcon(IconData filled) {
    if (filled == Icons.dynamic_feed_rounded) return Icons.dynamic_feed_outlined;
    if (filled == Icons.view_stream_rounded) return Icons.view_stream_outlined;
    if (filled == Icons.grid_view_rounded) return Icons.grid_view_outlined;
    if (filled == Icons.bookmark_rounded) return Icons.bookmark_outline;
    if (filled == Icons.person_rounded) return Icons.person_outline;
    return filled;
  }
}

/// Modern glass effect card for content sections
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? width;
  final double? height;
  final double borderRadius;
  final FeedXpressoPaletteEnhanced palette;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.borderRadius = 20,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.glassSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: palette.glassBorder.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Gradient button with modern design
class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isDisabled;
  final FeedXpressoPaletteEnhanced palette;
  final double height;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isDisabled = false,
    required this.palette,
    this.height = 52,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:
          widget.isDisabled || widget.isLoading ? null : (_) => _controller.forward(),
      onTapUp:
          widget.isDisabled || widget.isLoading ? null : (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.isDisabled || widget.isLoading ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: widget.height,
              decoration: BoxDecoration(
                gradient: widget.isDisabled
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.palette.brandGradientStart,
                          widget.palette.brandGradientEnd,
                        ],
                      ),
                color: widget.isDisabled
                    ? widget.palette.disabled
                    : null,
                borderRadius: BorderRadius.circular(26),
                boxShadow: widget.isDisabled
                    ? null
                    : [
                        BoxShadow(
                          color: widget.palette.brandGradientStart
                              .withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Center(
                child: widget.isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.palette.onAccent,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(
                              widget.icon,
                              color: widget.palette.onAccent,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                          ],
                          Text(
                            widget.label,
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: widget.isDisabled
                                  ? widget.palette.textTertiary
                                  : widget.palette.onAccent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}