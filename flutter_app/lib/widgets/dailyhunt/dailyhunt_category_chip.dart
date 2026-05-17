import 'package:flutter/material.dart';

import '../feed/feed_xpresso_theme.dart';

/// Compact category tab — accent underline (no partial-border assert).
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

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final isDark = dark || FeedXpressoTheme.isDark(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isDark ? 16 : 4),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isDark ? 12 : 10,
            6,
            isDark ? 12 : 10,
            8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: fx.chipStyle.copyWith(
                  fontSize: isDark ? 13 : 12.5,
                  height: 1.15,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? fx.accent : fx.chipInactive,
                ),
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 2.5,
                width: selected ? 20 : 0,
                decoration: BoxDecoration(
                  color: selected ? fx.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
