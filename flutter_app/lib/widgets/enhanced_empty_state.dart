import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'feed/feed_xpresso_palette_enhanced.dart';

/// Enhanced empty state widget with modern design, illustrations, and actions.
class EnhancedEmptyState extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonTap;
  final FeedXpressoPaletteEnhanced palette;
  final bool showAnimation;

  const EnhancedEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onButtonTap,
    required this.palette,
    this.showAnimation = true,
  });

  @override
  State<EnhancedEmptyState> createState() => _EnhancedEmptyStateState();
}

class _EnhancedEmptyStateState extends State<EnhancedEmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    if (widget.showAnimation) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon container with gradient
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            widget.palette.brandGradientStart,
                            widget.palette.brandGradientEnd,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.palette.brandGradientStart
                                .withValues(alpha: 0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.icon,
                        size: 56,
                        color: widget.palette.onAccent,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Title
                    Text(
                      widget.title,
                      style: GoogleFonts.notoSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: widget.palette.textPrimary,
                        letterSpacing: -0.3,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // Subtitle
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.notoSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: widget.palette.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.buttonLabel != null && widget.onButtonTap != null) ...[
                      const SizedBox(height: 32),
                      // Action button
                      _EnhancedActionButton(
                        label: widget.buttonLabel!,
                        onTap: widget.onButtonTap!,
                        palette: widget.palette,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EnhancedActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final FeedXpressoPaletteEnhanced palette;

  const _EnhancedActionButton({
    required this.label,
    required this.onTap,
    required this.palette,
  });

  @override
  State<_EnhancedActionButton> createState() => _EnhancedActionButtonState();
}

class _EnhancedActionButtonState extends State<_EnhancedActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.palette.brandGradientStart,
                    widget.palette.brandGradientEnd,
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: widget.palette.brandGradientStart
                        .withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.label,
                  style: GoogleFonts.notoSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: widget.palette.onAccent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Enhanced loading shimmer for better perceived performance
class EnhancedLoadingShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final FeedXpressoPaletteEnhanced palette;

  const EnhancedLoadingShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 100,
    this.borderRadius = 16,
    required this.palette,
  });

  @override
  State<EnhancedLoadingShimmer> createState() => _EnhancedLoadingShimmerState();
}

class _EnhancedLoadingShimmerState extends State<EnhancedLoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + _animation.value, 0),
              end: Alignment(_animation.value, 0),
              colors: [
                widget.palette.glassSurface,
                widget.palette.glassSurfaceBright,
                widget.palette.glassSurface,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Enhanced error state with retry functionality
class EnhancedErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final FeedXpressoPaletteEnhanced palette;

  const EnhancedErrorState({
    super.key,
    required this.message,
    this.onRetry,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error icon with gradient
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: palette.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.error.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: palette.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: GoogleFonts.notoSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.notoSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: palette.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              _EnhancedActionButton(
                label: 'Try Again',
                onTap: onRetry!,
                palette: palette,
              ),
            ],
          ],
        ),
      ),
    );
  }
}