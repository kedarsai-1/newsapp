import 'package:flutter/material.dart';

import 'feed_xpresso_theme.dart';

/// Premium horizontal scope pills (Politics: India/International, Local: regions).
class FeedScopeChipBar extends StatelessWidget {
  final String selectedScope;
  final List<(String label, String scope)> options;
  final Future<void> Function(String scope) onSelected;

  const FeedScopeChipBar({
    super.key,
    required this.selectedScope,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return ColoredBox(
      color: fx.chrome,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              physics: const BouncingScrollPhysics(),
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final opt = options[i];
                final selected = selectedScope == opt.$2;
                return _ScopePill(
                  fx: fx,
                  label: opt.$1,
                  selected: selected,
                  onTap: () => onSelected(opt.$2),
                );
              },
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: fx.divider),
        ],
      ),
    );
  }
}

class _ScopePill extends StatelessWidget {
  final FeedXpressoPalette fx;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ScopePill({
    required this.fx,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? fx.scopePillActive : fx.scopePillIdle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? fx.scopePillBorderActive : fx.scopePillBorderIdle,
          width: selected ? 1.2 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: fx.accent.withValues(
                    alpha: fx.background.computeLuminance() < 0.2 ? 0.15 : 0.22,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.1,
                color: selected ? fx.scopePillTextActive : fx.scopePillTextIdle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
