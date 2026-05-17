import 'package:flutter/material.dart';

import '../feed/feed_xpresso_theme.dart';

/// Discovery category cell — accent icon, theme-aware surfaces.
class DailyhuntCategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const DailyhuntCategoryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Material(
      color: fx.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: fx.divider, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: fx.accent.withValues(alpha: 0.08),
        highlightColor: fx.accent.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      fx.accent.withValues(alpha: 0.2),
                      fx.iconSurface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: fx.accent.withValues(alpha: 0.35),
                    width: 0.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: fx.accent, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.12,
                    letterSpacing: -0.15,
                    color: fx.title,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
