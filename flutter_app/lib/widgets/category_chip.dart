import 'package:flutter/material.dart';

import 'dailyhunt/dailyhunt_category_chip.dart';

/// Legacy alias — compact Dailyhunt-style category chip.
class CategoryChip extends StatelessWidget {
  final String label;
  final String? icon;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final text = icon == null || icon!.trim().isEmpty ? label : '${icon!} $label';
    return DailyhuntCategoryChip(
      label: text,
      selected: selected,
      onTap: onTap,
    );
  }
}
