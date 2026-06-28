import 'package:flutter/material.dart';

import '../../widgets/feed/feed_xpresso_theme.dart';

/// Discovery category cell — emoji in pastel circle (Way2News-style grid).
class DailyhuntCategoryCard extends StatelessWidget {
  final String title;
  final String emoji;
  final List<Color> accentColors;
  final VoidCallback onTap;

  const DailyhuntCategoryCard({
    super.key,
    required this.title,
    required this.emoji,
    required this.accentColors,
    required this.onTap,
  });

  factory DailyhuntCategoryCard.fromSlug({
    required String slug,
    required String title,
    String? emoji,
    required VoidCallback onTap,
  }) {
    final style = FeedXpressoPalette.categoryGradient(slug);
    return DailyhuntCategoryCard(
      title: title,
      emoji: (emoji != null && emoji.trim().isNotEmpty) ? emoji.trim() : style.$1,
      accentColors: style.$2,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final accent = accentColors.isNotEmpty ? accentColors.first : fx.accent;
    return Material(
      color: fx.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: fx.divider, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: accent.withValues(alpha: 0.08),
        highlightColor: accent.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 18, height: 1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.15,
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
