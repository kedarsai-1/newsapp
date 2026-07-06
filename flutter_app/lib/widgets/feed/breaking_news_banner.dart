import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../utils/i18n.dart';
import '../../theme/app_palette.dart';

/// Premium breaking news banner with smooth page transitions.
///
/// Features:
/// - Animated live indicator with pulse effect
/// - Smooth page carousel for multiple breaking stories
/// - Compact horizontal layout
/// - Subtle accent-colored border on top
/// - Tap expands to full article
class BreakingNewsBanner extends StatefulWidget {
  final List<NewsPost> breakingPosts;
  final void Function(NewsPost post) onTap;
  final AppPalette? palette;

  const BreakingNewsBanner({
    super.key,
    required this.breakingPosts,
    required this.onTap,
    this.palette,
  });

  @override
  State<BreakingNewsBanner> createState() => _BreakingNewsBannerState();
}

class _BreakingNewsBannerState extends State<BreakingNewsBanner>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.breakingPosts.length > 1) {
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (_pageController.hasClients && mounted) {
        final nextIndex = (_currentIndex + 1) % widget.breakingPosts.length;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void didUpdateWidget(BreakingNewsBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.breakingPosts.length != oldWidget.breakingPosts.length) {
      _timer?.cancel();
      _pageController.jumpToPage(0);
      _currentIndex = 0;
      if (widget.breakingPosts.length > 1) {
        _startAutoScroll();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.breakingPosts.isEmpty) {
      return const SizedBox.shrink();
    }

    final palette = widget.palette ?? context.palette;
    final accentColor = palette.primary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.08),
          border: Border(
            top: BorderSide(color: accentColor, width: 1.5),
            bottom: BorderSide(
              color: palette.divider.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Live indicator
            _buildLiveIndicator(accentColor),

            const SizedBox(width: 12),

            // Breaking badge
            _buildBreakingBadge(accentColor),

            const SizedBox(width: 12),

            // Headlines carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                  HapticFeedback.lightImpact();
                },
                itemCount: widget.breakingPosts.length,
                itemBuilder: (context, index) {
                  final post = widget.breakingPosts[index];
                  return InkWell(
                    onTap: () => widget.onTap(post),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        post.title,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Page indicators
            if (widget.breakingPosts.length > 1)
              _buildPageIndicators(palette, accentColor),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveIndicator(Color accentColor) {
    return Container(
      width: 4,
      height: 52,
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(2),
          bottomRight: Radius.circular(2),
        ),
      ),
    );
  }

  Widget _buildBreakingBadge(Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            I18n.t(context, 'feed_breaking'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 6),
          // Animated pulse dot
          _PulsingDot(color: Colors.white, size: 6),
        ],
      ),
    );
  }

  Widget _buildPageIndicators(AppPalette palette, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          widget.breakingPosts.length,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: _currentIndex == i ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: accentColor.withValues(
                alpha: _currentIndex == i ? 1.0 : 0.4,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated pulsing indicator for live news
class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const _PulsingDot({
    required this.color,
    required this.size,
  });

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(
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
    return ScaleTransition(
      scale: _animation,
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