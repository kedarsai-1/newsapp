import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../helpers/widgets/news_card.dart';
import '../../providers/news_provider.dart';
import '../../utils/i18n.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// Trending topics page showing all trending stories with modern glass morphism design.
class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    setState(() => _loading = true);
    await context.read<NewsProvider>().loadTrendingFeed();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsProvider>();
    final trendingPosts = provider.trendingPosts;
    final fx = FeedXpressoTheme.fx(context);

    return Scaffold(
      backgroundColor: fx.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ─────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            toolbarHeight: 52,
            backgroundColor: fx.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            expandedHeight: 0,
            foregroundColor: fx.title,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: fx.iconFg),
              onPressed: () => context.pop(),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        fx.accent,
                        fx.accent.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: fx.accent.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.trending_up_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Trending',
                  style: GoogleFonts.notoSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: fx.title,
                  ),
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: fx.divider),
            ),
          ),

          // ── Hero Banner ────────────────────────────────────────
          if (!_loading && trendingPosts.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      fx.accent,
                      fx.accent.withValues(alpha: 0.65),
                      fx.accentTertiary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: fx.accent.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        size: 120,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    Positioned(
                      left: -10,
                      top: -10,
                      child: Icon(
                        Icons.whatshot_rounded,
                        size: 80,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.local_fire_department_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hot Stories',
                                  style: GoogleFonts.notoSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${trendingPosts.length} trending topics',
                                  style: GoogleFonts.notoSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'LIVE',
                                  style: GoogleFonts.notoSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Loading State ──────────────────────────────────────
          if (_loading && trendingPosts.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: fx.accent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading trending stories...',
                        style: GoogleFonts.notoSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: fx.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Empty State ────────────────────────────────────────
          if (!_loading && trendingPosts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              fx.accent.withValues(alpha: 0.15),
                              fx.accentTertiary.withValues(alpha: 0.15),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.trending_up_rounded,
                          size: 48,
                          color: fx.accent.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No trending stories yet',
                        style: GoogleFonts.notoSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: fx.title,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Check back later for what\'s\ntrending in your feed.',
                        style: GoogleFonts.notoSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: fx.textSecondary,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      GestureDetector(
                        onTap: _loadTrending,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                fx.accent,
                                fx.accentTertiary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: fx.accent.withValues(alpha: 0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Refresh',
                                style: GoogleFonts.notoSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Trending List ──────────────────────────────────────
          if (trendingPosts.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TrendingCard(
                      rank: index + 1,
                      child: NewsCard(post: trendingPosts[index]),
                    ),
                  ),
                  childCount: trendingPosts.length,
                ),
              ),
            ),

          // Bottom padding
          SliverToBoxAdapter(
            child: SizedBox(
              height: FeedXpressoTheme.feedBottomInset(context) + 20,
            ),
          ),
        ],
      ),
    );
  }
}

/// Trending card with rank badge
class _TrendingCard extends StatelessWidget {
  final int rank;
  final Widget child;

  const _TrendingCard({required this.rank, required this.child});

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final isHot = rank <= 3;

    return Stack(
      children: [
        child,
        if (isHot)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: rank == 1
                      ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
                      : rank == 2
                          ? [const Color(0xFFC0C0C0), const Color(0xFFA8A8A8)]
                          : [const Color(0xFFCD7F32), const Color(0xFFB87333)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: (rank == 1
                            ? const Color(0xFFFFD700)
                            : rank == 2
                                ? const Color(0xFFC0C0C0)
                                : const Color(0xFFCD7F32))
                        .withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    rank == 1
                        ? Icons.emoji_events_rounded
                        : rank == 2
                            ? Icons.workspace_premium_rounded
                            : Icons.military_tech_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '#$rank',
                    style: GoogleFonts.notoSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: fx.glassSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: fx.glassBorder),
              ),
              child: Text(
                '#$rank',
                style: GoogleFonts.notoSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: fx.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
