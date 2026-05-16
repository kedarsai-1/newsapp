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
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: EdgeInsets.fromLTRB(5, dark ? 2 : 4, 5, dark ? 3 : 5),
          decoration: BoxDecoration(
            border: Border(
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
