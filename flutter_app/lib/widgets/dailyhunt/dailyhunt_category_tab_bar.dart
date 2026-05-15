import 'package:flutter/material.dart';

import 'dailyhunt_category_chip.dart';

/// Horizontal category strip — compact chips, tight spacing (Dailyhunt-style).
class DailyhuntCategoryTabBar extends StatelessWidget {
  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const DailyhuntCategoryTabBar({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const double stripHeight = 32;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SizedBox(
        height: stripHeight,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 4),
          itemBuilder: (context, i) {
            return Center(
              child: DailyhuntCategoryChip(
                label: categories[i],
                selected: i == selectedIndex,
                onTap: () => onSelected(i),
              ),
            );
          },
        ),
      ),
    );
  }
}
