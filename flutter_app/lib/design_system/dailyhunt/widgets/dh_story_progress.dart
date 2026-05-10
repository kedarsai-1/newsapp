import 'package:flutter/material.dart';

import '../dailyhunt_tokens.dart';

/// Horizontal story / reel progress (caps visible segments for clarity).
class DhStoryProgress extends StatelessWidget {
  final int total;
  final int index;
  final int maxVisible;

  /// When true, inactive segments are light (for use over dark media). When false,
  /// inactive uses [ColorScheme.onSurface] for light app backgrounds.
  final bool onDarkMedia;

  const DhStoryProgress({
    super.key,
    required this.total,
    required this.index,
    this.maxVisible = 12,
    this.onDarkMedia = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inactive = onDarkMedia
        ? Colors.white.withValues(alpha: 0.22)
        : cs.onSurface.withValues(alpha: 0.14);
    final visible = total.clamp(1, maxVisible);
    return Row(
      children: List.generate(visible, (i) {
        final selected = i == index % visible;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            height: 3,
            margin: EdgeInsets.only(right: i == visible - 1 ? 0 : 5),
            decoration: BoxDecoration(
              color: selected ? DhTokens.accent : inactive,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}
