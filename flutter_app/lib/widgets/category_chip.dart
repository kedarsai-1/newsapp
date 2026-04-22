import 'package:flutter/material.dart';
import '../constants.dart';
import '../theme/app_spacing.dart';

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
    final p = context.palette;

    final radius = BorderRadius.circular(24);
    final bg = selected
        ? null
        : (Theme.of(context).brightness == Brightness.dark
            ? p.surface
            : p.categoryChipBg);

    final gradient = selected
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              p.accentGreenLight,
              p.primaryDark,
            ],
          )
        : null;

    final fg = selected ? Colors.white : p.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedScale(
          scale: selected ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: bg,
              gradient: gradient,
              borderRadius: radius,
              border: selected
                  ? null
                  : Border.all(color: p.cardBorder, width: 1),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: fg,
                height: 1.15,
              ),
              child: Text(
                icon == null || icon!.trim().isEmpty ? label : '${icon!} $label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

