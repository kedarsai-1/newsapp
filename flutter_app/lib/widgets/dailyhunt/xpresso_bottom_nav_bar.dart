import 'package:flutter/material.dart';

import '../feed/feed_xpresso_theme.dart';

/// Dailyhunt Xpresso bottom bar — matte, compact, top-dash active state.
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
    final fx = FeedXpressoTheme.fx(context);
    final isDark = fx.background.computeLuminance() < 0.2;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fx.navBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: isDark ? 12 : 16,
            offset: const Offset(0, -4),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(
            height: 1,
            thickness: 0.5,
            color: fx.divider,
          ),
          SafeArea(
            top: false,
            child: SizedBox(
              height: FeedXpressoTheme.navBarHeight,
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: _XpressoNavItem(
                        fx: fx,
                        destination: destinations[i],
                        selected: i == selectedIndex,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
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

class _XpressoNavItem extends StatelessWidget {
  final FeedXpressoPalette fx;
  final XpressoNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _XpressoNavItem({
    required this.fx,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        selected ? fx.navActiveIcon : fx.navInactiveIcon;
    final labelColor =
        selected ? fx.navActiveLabel : fx.navInactiveLabel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected)
              Container(
                width: FeedXpressoTheme.navIndicatorWidth,
                height: FeedXpressoTheme.navIndicatorHeight,
                margin: const EdgeInsets.only(bottom: 3),
                decoration: BoxDecoration(
                  color: fx.navActiveIndicator,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 5),
            Icon(
              selected ? destination.selectedIcon : destination.icon,
              size: FeedXpressoTheme.navIconSize,
              color: iconColor,
            ),
            const SizedBox(height: 2),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: FeedXpressoTheme.navLabelSize,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: labelColor,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
