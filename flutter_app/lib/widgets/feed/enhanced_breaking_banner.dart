import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/models.dart';
import '../../widgets/feed/feed_xpresso_palette_enhanced.dart';
import 'breaking_banner_shared.dart';

/// Enhanced breaking news banner with modern design, smooth animations, and glass morphism effects.
class EnhancedBreakingBanner extends StatefulWidget {
  final List<NewsPost> breakingPosts;
  final void Function(NewsPost) onTap;
  final FeedXpressoPaletteEnhanced palette;

  const EnhancedBreakingBanner({
    super.key,
    required this.breakingPosts,
    required this.onTap,
    required this.palette,
  });

  @override
  State<EnhancedBreakingBanner> createState() => _EnhancedBreakingBannerState();
}

class _EnhancedBreakingBannerState extends State<EnhancedBreakingBanner>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.breakingPosts.isEmpty) return const SizedBox.shrink();

    final posts = widget.breakingPosts;

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Animated background
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final gradient = BreakingGradients.forIndex(index);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradient,
                    ),
                  ),
                );
              },
            ),

            // Content overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.black.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),

            // Breaking news indicator
            Positioned(
              left: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: _BreakingBadge(palette: widget.palette),
              ),
            ),

            // Scrolling news items
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return GestureDetector(
                  onTap: () => widget.onTap(post),
                  child: Container(
                    padding: const EdgeInsets.only(left: 100, right: 16),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            post.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.notoSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Page indicators
            if (posts.length > 1)
              Positioned(
                right: 16,
                bottom: 8,
                child: Row(
                  children: List.generate(posts.length, (index) {
                    final isActive = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(left: 4),
                      width: isActive ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Color> _getGradientForIndex(int index) {
    return BreakingGradients.forIndex(index);
  }
}

class _BreakingBadge extends StatefulWidget {
  final FeedXpressoPaletteEnhanced palette;

  const _BreakingBadge({required this.palette});

  @override
  State<_BreakingBadge> createState() => _BreakingBadgeState();
}

class _BreakingBadgeState extends State<_BreakingBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
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
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.palette.error,
                  widget.palette.error.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: widget.palette.error.withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flash_on_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  'BREAKING',
                  style: GoogleFonts.notoSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Enhanced highlights rail with horizontal scrolling cards
class EnhancedHighlightsRail extends StatelessWidget {
  final List<NewsPost> breaking;
  final List<NewsPost> trending;
  final bool loading;
  final void Function(NewsPost) onOpen;
  final FeedXpressoPaletteEnhanced palette;

  const EnhancedHighlightsRail({
    super.key,
    required this.breaking,
    required this.trending,
    this.loading = false,
    required this.onOpen,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _LoadingRail(palette: palette);
    }

    final hasBreaking = breaking.isNotEmpty;
    final hasTrending = trending.isNotEmpty;

    if (!hasBreaking && !hasTrending) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasTrending) ...[
                _SectionHeader(
                  icon: Icons.trending_up_rounded,
                  label: 'Trending Now',
                  palette: palette,
                ),
                const SizedBox(height: 12),
                _TrendingRail(
                  posts: trending,
                  onOpen: onOpen,
                  palette: palette,
                ),
              ],
              if (hasBreaking && hasTrending) const SizedBox(height: 24),
              if (hasBreaking) ...[
                _SectionHeader(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Breaking Stories',
                  palette: palette,
                ),
                const SizedBox(height: 12),
                _BreakingRail(
                  posts: breaking,
                  onOpen: onOpen,
                  palette: palette,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final FeedXpressoPaletteEnhanced palette;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                palette.brandGradientStart,
                palette.brandGradientEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.notoSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: palette.glassSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.glassBorder),
          ),
          child: Text(
            'See all',
            style: GoogleFonts.notoSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.brandGradientStart,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendingRail extends StatelessWidget {
  final List<NewsPost> posts;
  final void Function(NewsPost) onOpen;
  final FeedXpressoPaletteEnhanced palette;

  const _TrendingRail({
    required this.posts,
    required this.onOpen,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(right: 16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final gradient = _getGradientForIndex(index);

          return _TrendingCard(
            post: post,
            gradient: gradient,
            onTap: () => onOpen(post),
            palette: palette,
          );
        },
      ),
    );
  }

  List<Color> _getGradientForIndex(int index) {
    return BreakingGradients.trendingForIndex(index);
  }
}

class _TrendingCard extends StatelessWidget {
  final NewsPost post;
  final List<Color> gradient;
  final VoidCallback onTap;
  final FeedXpressoPaletteEnhanced palette;

  const _TrendingCard({
    required this.post,
    required this.gradient,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient[0].withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trending icon
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.trending_up_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const Spacer(),
                  // Title
                  Text(
                    post.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Source
                  Row(
                    children: [
                      Icon(
                        Icons.source_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          post.displaySourceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.notoSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Index badge
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '#',
                    style: GoogleFonts.notoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakingRail extends StatelessWidget {
  final List<NewsPost> posts;
  final void Function(NewsPost) onOpen;
  final FeedXpressoPaletteEnhanced palette;

  const _BreakingRail({
    required this.posts,
    required this.onOpen,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(right: 16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];

          return _BreakingCard(
            post: post,
            index: index + 1,
            onTap: () => onOpen(post),
            palette: palette,
          );
        },
      ),
    );
  }
}

class _BreakingCard extends StatelessWidget {
  final NewsPost post;
  final int index;
  final VoidCallback onTap;
  final FeedXpressoPaletteEnhanced palette;

  const _BreakingCard({
    required this.post,
    required this.index,
    required this.onTap,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: palette.error.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: palette.heroShadow,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Breaking indicator
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: palette.error,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    post.displaySourceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: palette.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingRail extends StatelessWidget {
  final FeedXpressoPaletteEnhanced palette;

  const _LoadingRail({required this.palette});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: palette.shimmerBase,
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }
}