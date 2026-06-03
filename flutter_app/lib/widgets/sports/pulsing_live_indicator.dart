import 'package:flutter/material.dart';

/// A small pulsating red dot used to indicate a live match.
///
/// The widget continuously scales between its base size and a slightly larger
/// size, creating a subtle pulse effect. The animation runs indefinitely and
/// respects the provided `color` and `size` parameters.
class PulsingLiveIndicator extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingLiveIndicator({
    Key? key,
    required this.color,
    this.size = 7.0,
  }) : super(key: key);

  @override
  State<PulsingLiveIndicator> createState() => _PulsingLiveIndicatorState();
}

class _PulsingLiveIndicatorState extends State<PulsingLiveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  late final Animation<double> _scale = Tween(begin: 1.0, end: 1.5).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
