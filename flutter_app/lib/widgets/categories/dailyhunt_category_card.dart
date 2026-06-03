import 'package:flutter/material.dart';

import '../feed/feed_xpresso_theme.dart';

/// Discovery category cell — accent icon, theme-aware surfaces.
class DailyhuntCategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String slug;
  final VoidCallback onTap;

  const DailyhuntCategoryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.slug,
    required this.onTap,
  });

  static (String emoji, List<Color> colors) _categoryStyle(String slug) {
    switch (slug.toLowerCase()) {
      case 'politics':
        return ('🏛️', [const Color(0xFFC084FC), const Color(0xFF8B5CF6)]); // Purple
      case 'sports':
        return ('⚽', [const Color(0xFF34D399), const Color(0xFF059669)]); // Green
      case 'entertainment':
        return ('🎬', [const Color(0xFFFBBF24), const Color(0xFFD97706)]); // Amber/Yellow
      case 'technology':
        return ('💻', [const Color(0xFF38BDF8), const Color(0xFF0284C7)]); // Blue
      case 'business':
        return ('📈', [const Color(0xFF2DD4BF), const Color(0xFF0D9488)]); // Teal
      case 'health':
        return ('🏥', [const Color(0xFFF87171), const Color(0xFFDC2626)]); // Red
      case 'education':
        return ('🎓', [const Color(0xFF818CF8), const Color(0xFF4F46E5)]); // Indigo
      case 'local':
        return ('📍', [const Color(0xFFF97316), const Color(0xFFEA580C)]); // Orange
      default:
        return ('📰', [const Color(0xFF9E9E9E), const Color(0xFF6E6E6E)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final style = _categoryStyle(slug);
    final catColor = style.$2[0];

    return Material(
      color: fx.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: fx.divider, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: catColor.withOpacity(0.08),
        highlightColor: catColor.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      catColor.withOpacity(0.22),
                      fx.iconSurface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: catColor.withOpacity(0.45),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: catColor.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: catColor, size: 16),
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
