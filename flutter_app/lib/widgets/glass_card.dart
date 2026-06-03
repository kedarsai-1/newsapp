import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:news_app/widgets/premium_animations.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final List<BoxShadow>? boxShadow;
  final double radius;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final bool enableAnimation;

  const GlassCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.margin,
    this.color,
    this.boxShadow,
    this.borderColor,
    this.enableAnimation = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface.withOpacity(0.25);
    final card = Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? surface,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: borderColor ?? Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: boxShadow,
            ),
            child: child,
          ),
        ),
      ),
    );
    if (!enableAnimation) return card;
    return PremiumAnimatedWrapper(
      child: card,
      // Default animation values are suitable for most cards.
    );
  }
}
