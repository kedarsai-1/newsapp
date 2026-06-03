import 'package:flutter/material.dart';

import '../feed/feed_xpresso_theme.dart';
import '../../constants.dart';

/// Premium floating glassmorphic navigation dock — detaches bottom bar
/// and animates active states inside soft glowing capsules.
class XpressoBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<XpressoNavDestination> destinations;

  const XpressoBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14), // Floating margins
        child: GlassCard(
          radius: 24,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          color: GlassColors.surfaceWhite,
          borderColor: GlassColors.borderWhite,
          boxShadow: [
            BoxShadow(
              color: GlassColors.isLightMode
                  ? Colors.black.withOpacity(0.06)
                  : Colors.black.withOpacity(0.20),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _XpressoNavItem(
                    destination: destinations[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class XpressoNavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const XpressoNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class _XpressoNavItem extends StatefulWidget {
  final XpressoNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _XpressoNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_XpressoNavItem> createState() => _XpressoNavItemState();
}

class _XpressoNavItemState extends State<_XpressoNavItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = GlassColors.accentGreen;
    final activeColorLight = GlassColors.accentGreenLight;
    final isLight = GlassColors.isLightMode;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.00,
        duration: const Duration(milliseconds: 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing capsule backdrop behind the active tab icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: widget.selected
                    ? activeColor.withOpacity(isLight ? 0.12 : 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.selected
                      ? activeColor.withOpacity(isLight ? 0.28 : 0.40)
                      : Colors.transparent,
                  width: 0.8,
                ),
              ),
              child: Icon(
                widget.selected ? widget.destination.selectedIcon : widget.destination.icon,
                size: 19,
                color: widget.selected
                    ? (isLight ? activeColor : activeColorLight)
                    : GlassColors.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              widget.destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600,
                color: widget.selected ? GlassColors.textPrimary : GlassColors.textHint,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
