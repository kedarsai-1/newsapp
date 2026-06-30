import 'package:flutter/material.dart';

/// Shared gradient palettes for breaking/trending banners.
class BreakingGradients {
  BreakingGradients._();

  /// Rotating gradient for enhanced breaking banner backgrounds.
  static List<Color> forIndex(int index) {
    const gradients = [
      [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
      [Color(0xFF8B5CF6), Color(0xFF6366F1)],
      [Color(0xFF14B8A6), Color(0xFF06B6D4)],
      [Color(0xFFF59E0B), Color(0xFFEF4444)],
      [Color(0xFF10B981), Color(0xFF3B82F6)],
    ];
    return gradients[index % gradients.length];
  }

  /// Trending card gradients for highlights rail.
  static List<Color> trendingForIndex(int index) {
    const gradients = [
      [Color(0xFF8B5CF6), Color(0xFF6366F1)],
      [Color(0xFF14B8A6), Color(0xFF06B6D4)],
      [Color(0xFFF59E0B), Color(0xFFEF4444)],
      [Color(0xFF10B981), Color(0xFF3B82F6)],
      [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
    ];
    return gradients[index % gradients.length];
  }
}

/// Pulsing live indicator dot — uses AnimatedBuilder replacement (AnimatedWidget).
class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingDot({
    super.key,
    required this.color,
    this.size = 8,
  });

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
