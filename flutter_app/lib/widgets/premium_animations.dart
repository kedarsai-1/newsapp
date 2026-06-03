import 'package:flutter/material.dart';

/// A reusable wrapper that adds premium‑grade hover and press animations to its child.
///
/// The wrapper works on desktop/web (via [MouseRegion]) and on mobile (via
/// [GestureDetector]) to provide consistent feedback. It uses an [AnimatedScale]
/// to smoothly transition between three states:
///   * Normal (scale = 1.0)
///   * Hovered (scale = [hoverScale])
///   * Pressed (scale = [pressScale])
///
/// All parameters have sensible defaults that match the existing motion
/// elsewhere in the app, but they can be overridden per‑widget.
class PremiumAnimatedWrapper extends StatefulWidget {
  /// The widget that should receive the animation.
  final Widget child;

  /// Scale factor when the widget is hovered. Defaults to 1.015.
  final double hoverScale;

  /// Scale factor when the widget is pressed. Defaults to 0.97.
  final double pressScale;

  /// Duration of the animation. Defaults to 140 ms.
  final Duration duration;

  /// Curve of the animation. Defaults to [Curves.easeOutCubic].
  final Curve curve;

  /// If true, the animation is disabled (useful for platforms that do not
  /// support hover). Defaults to false.
  final bool disableAnimation;

  const PremiumAnimatedWrapper({
    Key? key,
    required this.child,
    this.hoverScale = 1.015,
    this.pressScale = 0.97,
    this.duration = const Duration(milliseconds: 140),
    this.curve = Curves.easeOutCubic,
    this.disableAnimation = false,
  }) : super(key: key);

  @override
  State<PremiumAnimatedWrapper> createState() => _PremiumAnimatedWrapperState();
}

class _PremiumAnimatedWrapperState extends State<PremiumAnimatedWrapper> {
  bool _isHovered = false;
  bool _isPressed = false;

  void _setHover(bool value) {
    if (widget.disableAnimation) return;
    setState(() => _isHovered = value);
  }

  void _setPress(bool value) {
    if (widget.disableAnimation) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    // Determine the effective scale based on the current interaction state.
    final double scale = _isPressed
        ? widget.pressScale
        : (_isHovered ? widget.hoverScale : 1.0);

    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _setPress(true),
        onPointerUp: (_) => _setPress(false),
        onPointerCancel: (_) => _setPress(false),
        child: AnimatedScale(
          scale: scale,
          duration: widget.duration,
          curve: widget.curve,
          child: widget.child,
        ),
      ),
    );
  }
}

/// A premium entrance animation that fades in and slides up its child,
/// staggered based on its index.
class StaggeredEntranceAnimation extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration delayStep;
  final Duration duration;
  final double slideOffset;

  const StaggeredEntranceAnimation({
    Key? key,
    required this.index,
    required this.child,
    this.delayStep = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 375),
    this.slideOffset = 24.0,
  }) : super(key: key);

  @override
  State<StaggeredEntranceAnimation> createState() =>
      _StaggeredEntranceAnimationState();
}

class _StaggeredEntranceAnimationState extends State<StaggeredEntranceAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0.0, widget.slideOffset),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    final delay = widget.delayStep * widget.index;
    await Future.delayed(delay);
    if (mounted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: _slideAnimation.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
