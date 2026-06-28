import 'package:flutter/material.dart';

import '../../../widgets/dailyhunt/dailyhunt_category_chip.dart';
import '../../../widgets/feed/feed_xpresso_theme.dart';

/// Topic filter chip — same compact style as feed category tabs.
class DhCategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final bool showLeadingIcon;
  final IconData? leadingIcon;

  const DhCategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.showLeadingIcon = false,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (showLeadingIcon && leadingIcon != null) {
      final fx = FeedXpressoTheme.fx(context);
      final active = fx.accent;
      final inactive = fx.chipInactive;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelected(!selected),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? active : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  leadingIcon,
                  size: 13,
                  color: selected ? active : inactive,
                ),
                SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? active : inactive,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return DailyhuntCategoryChip(
      label: label,
      selected: selected,
      onTap: () => onSelected(!selected),
    );
  }
}
