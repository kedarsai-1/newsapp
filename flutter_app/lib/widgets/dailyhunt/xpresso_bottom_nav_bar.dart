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
    return ColoredBox(
      color: FeedXpressoTheme.navBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(
            height: 1,
            thickness: 0.5,
            color: FeedXpressoTheme.divider,
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
  final XpressoNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _XpressoNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = selected
        ? FeedXpressoTheme.navActiveIcon
        : FeedXpressoTheme.navInactiveIcon;
    final labelColor = selected
        ? FeedXpressoTheme.navActiveLabel
        : FeedXpressoTheme.navInactiveLabel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white10,
        highlightColor: Colors.white10,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            if (selected)
              const Positioned(
                top: 0,
                child: _NavActiveIndicator(),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    size: FeedXpressoTheme.navIconSize,
                    color: iconColor,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: FeedXpressoTheme.navLabelSize,
                      height: 1.0,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: labelColor,
                      letterSpacing: 0.05,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin top mark for the active tab — not a Material pill.
class _NavActiveIndicator extends StatelessWidget {
  const _NavActiveIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: FeedXpressoTheme.navIndicatorWidth,
      height: FeedXpressoTheme.navIndicatorHeight,
      decoration: BoxDecoration(
        color: FeedXpressoTheme.navActiveIndicator,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
