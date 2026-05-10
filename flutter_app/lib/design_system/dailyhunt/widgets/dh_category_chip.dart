import 'package:flutter/material.dart';

import '../dailyhunt_tokens.dart';

/// Compact topic filter chip with green selection (Dailyhunt-style).
class DhCategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final bool showLeadingIcon;
  final IconData? leadingIcon;

  const DhCategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.showLeadingIcon = false,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLeadingIcon && leadingIcon != null) ...[
            Icon(
              leadingIcon,
              size: 16,
              color: selected ? Colors.white : cs.onSurface.withValues(alpha: 0.65),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: selected ? Colors.white : cs.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      selectedColor: DhTokens.accent,
      backgroundColor: cs.surface,
      side: BorderSide(
        color: selected ? DhTokens.accent : cs.outline.withValues(alpha: 0.45),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DhTokens.radiusChip),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    );
  }
}
