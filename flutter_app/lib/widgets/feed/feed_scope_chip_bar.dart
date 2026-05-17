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
    return ColoredBox(
      color: FeedXpressoTheme.chrome,
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
                  label: opt.$1,
                  selected: selected,
                  onTap: () => onSelected(opt.$2),
                );
              },
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: FeedXpressoTheme.divider),
        ],
      ),
    );
  }
}

class _ScopePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ScopePill({
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
        color: selected ? FeedXpressoTheme.scopePillActive : FeedXpressoTheme.scopePillIdle,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? FeedXpressoTheme.scopePillBorderActive : FeedXpressoTheme.scopePillBorderIdle,
          width: 1,
        ),
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
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.15,
                color: selected ? FeedXpressoTheme.scopePillTextActive : FeedXpressoTheme.scopePillTextIdle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
