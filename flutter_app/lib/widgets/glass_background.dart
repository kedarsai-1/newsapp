import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;

/// A state-of-the-art premium glass‑morphism background that features
/// slow-drifting glowing color blobs under a deep backdrop filter.
/// High performance is achieved using a CustomPainter driven by a single
/// continuous AnimationController, avoiding widget rebuilds.
class GlassBackground extends StatefulWidget {
  final Widget child;
  const GlassBackground({Key? key, required this.child}) : super(key: key);

  @override
  State<GlassBackground> createState() => _GlassBackgroundState();
}

class _GlassBackgroundState extends State<GlassBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Slow, seamless loop for fluid ambient motion (15 seconds)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    // Solid deep background color to anchor the blobs
    final baseColor = isLight
        ? const Color(0xFFF0F4F8)
        : const Color(0xFF070A12); // Deep premium indigo space

    return Stack(
      children: [
        // 1. Solid deep background
        Positioned.fill(
          child: Container(color: baseColor),
        ),
        // 2. Animated Glowing Blobs Layer
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _AmbientBlobsPainter(
                  progress: _controller.value,
                  isLight: isLight,
                ),
              );
            },
          ),
        ),
        // 3. Backdrop Filter (High Blur Glassmorphism)
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isLight
                      ? [
                          Colors.white.withOpacity(0.55),
                          Colors.white.withOpacity(0.20),
                        ]
                      : [
                          const Color(0xFF0D1527).withOpacity(0.60),
                          const Color(0xFF070A12).withOpacity(0.40),
                        ],
                ),
              ),
            ),
          ),
        ),
        // 4. Foreground Content
        widget.child,
      ],
    );
  }
}

class _AmbientBlobsPainter extends CustomPainter {
  final double progress;
  final bool isLight;

  _AmbientBlobsPainter({required this.progress, required this.isLight});

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * math.pi;

    // Define premium curated blob colors with customized opacity
    final double opacity = isLight ? 0.35 : 0.40;
    
    // Blob 1: Emerald/Mint Green
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF34D399).withOpacity(opacity),
          const Color(0xFF34D399).withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: Offset.zero, radius: size.width * 0.45),
      );

    // Blob 2: Royal Indigo/Vibrant Purple
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF8B5CF6).withOpacity(opacity),
          const Color(0xFF8B5CF6).withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: Offset.zero, radius: size.width * 0.55),
      );

    // Blob 3: Amber/Neon Orange
    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFF97316).withOpacity(isLight ? 0.25 : 0.30),
          const Color(0xFFF97316).withOpacity(0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: Offset.zero, radius: size.width * 0.40),
      );

    canvas.save();

    // 1. Paint Blob 1 (Mint) - Top Left drifting
    final x1 = size.width * (0.28 + 0.15 * math.sin(t));
    final y1 = size.height * (0.25 + 0.10 * math.cos(t));
    canvas.save();
    canvas.translate(x1, y1);
    canvas.drawCircle(Offset.zero, size.width * 0.45, paint1);
    canvas.restore();

    // 2. Paint Blob 2 (Purple) - Center Right drifting
    final x2 = size.width * (0.72 + 0.12 * math.cos(t * 0.8));
    final y2 = size.height * (0.50 + 0.15 * math.sin(t * 0.8));
    canvas.save();
    canvas.translate(x2, y2);
    canvas.drawCircle(Offset.zero, size.width * 0.55, paint2);
    canvas.restore();

    // 3. Paint Blob 3 (Orange) - Bottom Left drifting
    final x3 = size.width * (0.35 + 0.18 * math.sin(t * 0.6));
    final y3 = size.height * (0.78 + 0.12 * math.cos(t * 0.6));
    canvas.save();
    canvas.translate(x3, y3);
    canvas.drawCircle(Offset.zero, size.width * 0.40, paint3);
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AmbientBlobsPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isLight != isLight;
  }
}
