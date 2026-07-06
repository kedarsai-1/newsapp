import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_palette.dart';
import '../../theme/design_tokens.dart';

/// Premium category chip with smooth animations
///
/// Features:
/// - Icon + label combination
/// - Smooth selection animation
/// - Ripple effect on tap
/// - Haptic feedback
/// - Rounded capsule shape
/// - Active/inactive state differentiation
class CategoryChip extends StatefulWidget {
  final String label;
  final String? icon;
  final bool selected;
  final VoidCallback onTap;
  final AppPalette? palette;
  final Color? accentColor;

  const CategoryChip({
    super.key,
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
    this.palette,
    this.accentColor,
  });

  @override
  State<CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<CategoryChip>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _colorController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;
  bool _isHovered = false;


  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: DesignTokens.durationFast,
      vsync: this,
    );

    _colorController = AnimationController(
      duration: DesignTokens.durationNormal,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    final palette = widget.palette ?? context.palette;
    final accentColor = widget.accentColor ?? palette.primary;

    _colorAnimation = ColorTween(
      begin: widget.selected
        ? accentColor.withValues(alpha: 0.1)
        : Colors.transparent,
      end: widget.selected
        ? accentColor.withValues(alpha: 0.15)
        : Colors.transparent,
    ).animate(CurvedAnimation(
      parent: _colorController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CategoryChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _colorController.forward();
      _colorController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette ?? context.palette;
    final accentColor = widget.accentColor ?? palette.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: _colorAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleTap,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.icon != null
                      ? DesignTokens.space12
                      : DesignTokens.space8,
                    vertical: DesignTokens.space6,
                  ),
                  decoration: BoxDecoration(
                    color: _colorAnimation.value,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: widget.selected
                        ? accentColor
                        : palette.divider.withValues(alpha: 0.3),
                      width: widget.selected ? 1.5 : 1,
                    ),
                    boxShadow: widget.selected ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.2),
                        blurRadius: DesignTokens.elevationMD,
                        offset: const Offset(0, 2),
                      ),
                    ] : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          _getIconData(widget.icon!),
                          size: DesignTokens.iconSizeMD,
                          color: widget.selected
                            ? accentColor
                            : palette.textPrimary,
                        ),
                        const SizedBox(width: DesignTokens.space6),
                      ],
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: DesignTokens.fontSizeLabel,
                          fontWeight: widget.selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                          height: DesignTokens.lineHeightLabel,
                          color: widget.selected
                            ? accentColor
                            : palette.textPrimary,
                          letterSpacing: widget.selected ? 0.1 : 0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleTap() {
    widget.onTap();
    HapticFeedback.lightImpact();

    // Visual feedback animation
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
  }

  IconData _getIconData(String icon) {
    switch (icon) {
      case '🔥':
        return Icons.local_fire_department;
      case '📍':
        return Icons.location_on;
      case '🏛️':
        return Icons.account_balance;
      case '💼':
        return Icons.business_center;
      case '💻':
        return Icons.computer;
      case '⚽':
        return Icons.sports_soccer;
      case '🎬':
        return Icons.movie;
      case '🏥':
        return Icons.local_hospital;
      case '🎓':
        return Icons.school;
      case '🌎':
        return Icons.public;
      case '🚗':
        return Icons.directions_car;
      case '🔬':
        return Icons.science;
      default:
        return Icons.category;
    }
  }
}

/// Category chip widget for horizontal scrolling category bar
class CategoryBar extends StatelessWidget {
  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final AppPalette? palette;

  const CategoryBar({
    super.key,
    required this.categories,
    this.selectedCategory,
    required this.onCategorySelected,
    this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final palette = this.palette ?? context.palette;

    return Container(
      height: DesignTokens.categoryBarHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space16,
        vertical: DesignTokens.space4,
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Padding(
            padding: EdgeInsets.only(
              right: index < categories.length - 1
                ? DesignTokens.space8
                : 0,
            ),
            child: CategoryChip(
              label: category,
              icon: _getCategoryIcon(category),
              selected: selectedCategory == category,
              onTap: () => onCategorySelected(category),
              palette: palette,
            ),
          );
        },
      ),
    );
  }

  String? _getCategoryIcon(String category) {
    switch (category) {
      case 'Top':
        return '🔥';
      case 'Local':
        return '📍';
      case 'Politics':
        return '🏛️';
      case 'Business':
        return '💼';
      case 'Technology':
        return '💻';
      case 'Sports':
        return '⚽';
      case 'Cinema':
        return '🎬';
      case 'Health':
        return '🏥';
      case 'Education':
        return '🎓';
      case 'Jobs':
        return '💼';
      case 'World':
        return '🌎';
      case 'Auto':
        return '🚗';
      case 'Science':
        return '🔬';
      default:
        return null;
    }
  }
}