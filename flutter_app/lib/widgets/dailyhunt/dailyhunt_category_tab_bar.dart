import 'package:flutter/material.dart';

import '../../widgets/feed/feed_xpresso_theme.dart';
import 'dailyhunt_category_chip.dart';

/// Horizontal category strip — light or Xpresso dark feed.
class DailyhuntCategoryTabBar extends StatelessWidget {
  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool dark;

  const DailyhuntCategoryTabBar({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
    this.dark = false,
  });

  /// Room for label + underline + vertical padding (avoids bottom overflow).
  static const double stripHeight = 36;
  static const double stripHeightDark = 48;

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final isDark = dark || FeedXpressoTheme.isDark(context);
    final barHeight = isDark ? stripHeightDark : stripHeight;

    return ColoredBox(
      color: fx.chrome,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: barHeight,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: isDark ? 6 : 8),
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: categories.length,
              separatorBuilder: (_, __) => SizedBox(width: isDark ? 6 : 4),
              itemBuilder: (context, i) {
                return Align(
                  alignment: Alignment.center,
                  child: DailyhuntCategoryChip(
                    label: categories[i],
                    selected: i == selectedIndex,
                    dark: isDark,
                    onTap: () => onSelected(i),
                  ),
                );
              },
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: fx.divider,
          ),
        ],
      ),
    );
  }
}
