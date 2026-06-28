import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../utils/i18n.dart';
import '../../theme/app_palette.dart';
import 'feed_xpresso_theme.dart';

/// Persistent breaking news banner at the top of the feed
/// Shows breaking headlines with auto-scrolling ticker
class BreakingBanner extends StatefulWidget {
  final List<NewsPost> breakingPosts;
  final void Function(NewsPost)? onTap;

  const BreakingBanner({
    super.key,
    required this.breakingPosts,
    this.onTap,
  });

  @override
  State<BreakingBanner> createState() => _BreakingBannerState();
}

class _BreakingBannerState extends State<BreakingBanner>
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
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
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
  void didUpdateWidget(BreakingBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.breakingPosts.length != oldWidget.breakingPosts.length) {
      _timer?.cancel();
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

    final fx = FeedXpressoTheme.fx(context);
    final breakingColor = context.palette.breaking;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: breakingColor.withValues(alpha: 0.12),
        border: Border(
          bottom: BorderSide(
            color: breakingColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Live indicator
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: breakingColor,
            ),
          ),
          const SizedBox(width: 12),
          // Breaking label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: breakingColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  I18n.t(context, 'feed_breaking'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                _LiveIndicator(color: Colors.white),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Headlines ticker
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemCount: widget.breakingPosts.length,
              itemBuilder: (context, index) {
                final post = widget.breakingPosts[index];
                return InkWell(
                  onTap: () => widget.onTap?.call(post),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      post.title,
                      style: TextStyle(
                        color: fx.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  widget.breakingPosts.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: _currentIndex == i ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: breakingColor.withValues(
                        alpha: _currentIndex == i ? 1.0 : 0.4,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pulsing live indicator dot
class _LiveIndicator extends StatefulWidget {
  final Color color;

  const _LiveIndicator({required this.color});

  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator>
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
