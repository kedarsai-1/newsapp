import 'package:flutter/material.dart';

import '../feed/feed_xpresso_theme.dart';
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

  static const double stripHeight = 32;
  static const double stripHeightDark = 36;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: dark ? FeedXpressoTheme.chrome : Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: dark ? stripHeightDark : stripHeight,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: dark ? 6 : 8),
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (context, i) {
                return Center(
                  child: DailyhuntCategoryChip(
                    label: categories[i],
                    selected: i == selectedIndex,
                    dark: dark,
                    onTap: () => onSelected(i),
                  ),
                );
              },
            ),
          ),
          if (dark)
            const Divider(height: 1, thickness: 0.5, color: FeedXpressoTheme.divider),
        ],
      ),
    );
  }
}
