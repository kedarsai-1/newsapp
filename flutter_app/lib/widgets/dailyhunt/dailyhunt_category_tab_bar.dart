import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/feed/feed_xpresso_theme.dart';

/// Horizontal category strip — redesigned with modern glass morphism.
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

  static const double stripHeight = 40;

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);

    return SizedBox(
      height: stripHeight,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final isSelected = i == selectedIndex;
          return _CategoryChip(
            label: categories[i],
            isSelected: isSelected,
            onTap: () => onSelected(i),
            fx: fx,
          );
        },
      ),
    );
  }
}

/// Modern glass morphism category chip
class _CategoryChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final dynamic fx;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.fx,
  });

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _pressed ? 0.95 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: widget.isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.fx.accent,
                      widget.fx.accent.withValues(alpha: 0.8),
                    ],
                  )
                : null,
            color: widget.isSelected
                ? null
                : widget.fx.glassSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? widget.fx.accent
                  : widget.fx.glassBorder,
              width: widget.isSelected ? 1.5 : 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.fx.accent.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.notoSans(
              fontSize: 13,
              fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w600,
              color: widget.isSelected
                  ? Colors.white
                  : widget.fx.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
