import 'package:flutter/material.dart';

import '../feed/feed_xpresso_theme.dart';

/// Compact category tab — accent underline + glow (light & dark).
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(
            isDark ? 12 : 8,
            isDark ? 6 : 5,
            isDark ? 12 : 8,
            isDark ? 8 : 7,
          ),
          decoration: BoxDecoration(
            color: selected
                ? (isDark
                    ? fx.chipInactiveBg
                    : fx.chipInactiveBg.withValues(alpha: 0.9))
                : Colors.transparent,
            borderRadius: isDark ? BorderRadius.circular(16) : BorderRadius.circular(4),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: fx.accent.withValues(alpha: isDark ? 0.12 : 0.2),
                      blurRadius: isDark ? 8 : 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: fx.chipStyle.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? fx.accent : fx.chipInactive,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 2.5,
                width: selected ? 22 : 0,
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
