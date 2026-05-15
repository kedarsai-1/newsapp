import 'package:flutter/material.dart';

import '../../theme/dailyhunt_theme.dart';

/// Compact category tab — text + subtle bottom indicator (not a pill).
class DailyhuntCategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const DailyhuntCategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const Color inactiveColor = Color(0xFF6B6B6B);
  static const Color activeColor = DailyhuntTheme.accentGreen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? activeColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.1,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? activeColor : inactiveColor,
              letterSpacing: -0.05,
            ),
          ),
        ),
      ),
    );
  }
}
