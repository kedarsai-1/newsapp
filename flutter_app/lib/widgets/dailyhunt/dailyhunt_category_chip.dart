import 'package:flutter/material.dart';

import '../feed/feed_xpresso_theme.dart';

/// Compact category tab — underline active state.
class DailyhuntCategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dark;

  const DailyhuntCategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dark = false,
  });

  static const Color inactiveColorLight = Color(0xFF6B6B6B);
  static const Color activeColor = Color(0xFF0A8F57);

  @override
  Widget build(BuildContext context) {
    final inactive = dark ? FeedXpressoTheme.chipInactive : inactiveColorLight;
    final active = dark ? FeedXpressoTheme.chipActive : activeColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(dark ? 16 : 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(
            dark ? 12 : 5,
            dark ? 6 : 4,
            dark ? 12 : 5,
            dark ? 6 : 5,
          ),
          decoration: BoxDecoration(
            color: dark && selected ? FeedXpressoTheme.scopePillIdle : Colors.transparent,
            borderRadius: dark ? BorderRadius.circular(16) : null,
            border: dark
                ? Border.all(
                    color: selected
                        ? FeedXpressoTheme.scopePillBorderActive
                        : Colors.transparent,
                    width: 1,
                  )
                : Border(
                    bottom: BorderSide(
                      color: selected ? active : Colors.transparent,
                      width: 2,
                    ),
                  ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FeedXpressoTheme.chipStyle.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? active : inactive,
            ),
          ),
        ),
      ),
    );
  }
}
