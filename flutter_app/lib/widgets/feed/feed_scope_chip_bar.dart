import 'package:flutter/material.dart';

import 'feed_xpresso_theme.dart';

/// Horizontal scope pills (Politics: India/International, Local: Andhra/Telangana).
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

  /// Inner list height — fits pill label + border without clipping.
  static const double _rowHeight = 36;

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return ColoredBox(
      color: fx.chrome,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
            child: SizedBox(
              height: _rowHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                physics: const BouncingScrollPhysics(),
                itemCount: options.length,
                separatorBuilder: (_, __) => SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final opt = options[i];
                  final selected = selectedScope == opt.$2;
                  return Align(
                    alignment: Alignment.center,
                    child: _ScopePill(
                      fx: fx,
                      label: opt.$1,
                      selected: selected,
                      onTap: () => onSelected(opt.$2),
                    ),
                  );
                },
              ),
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
    final fx = context.fx;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? fx.scopePillActive : fx.scopePillIdle,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? fx.scopePillBorderActive : fx.scopePillBorderIdle,
              width: selected ? 1.2 : 1,
            ),
            boxShadow: selected && fx.background.computeLuminance() < 0.2
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.1,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: 0.1,
              color: selected ? fx.scopePillTextActive : fx.scopePillTextIdle,
            ),
          ),
        ),
      ),
    );
  }
}
