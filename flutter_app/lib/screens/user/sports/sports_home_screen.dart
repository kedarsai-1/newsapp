import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/models.dart';
import '../../../models/sports_models.dart';
import '../../../services/auth_provider.dart';
import '../../../providers/news_provider.dart';
import '../../../providers/sports_provider.dart';
import '../../../services/api_service.dart';
import '../../../constants.dart';
import '../../../widgets/premium_utils.dart';
import '../../../widgets/sports/sports_live_card.dart';
import '../../../widgets/sports/glass_sports_article_card.dart';
import '../../../widgets/premium_animations.dart';
import '../../../widgets/feed/feed_xpresso_theme.dart';

/// Cricket / sports hub — premium glassmorphic live scores + sports feed.
class SportsHomeScreen extends StatefulWidget {
  const SportsHomeScreen({super.key});

  @override
  State<SportsHomeScreen> createState() => _SportsHomeScreenState();
}

class _SportsHomeScreenState extends State<SportsHomeScreen> {
  final _scrollController = ScrollController();
  late final SportsProvider _sports;
  final Map<String, bool> _likedByPostId = {};
  final Map<String, bool> _bookmarkedByPostId = {};
  String? _lastLanguage;

  @override
  void initState() {
    super.initState();
    _sports = context.read<SportsProvider>();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lang = context.read<NewsProvider>().selectedLanguage;
      _lastLanguage = lang;
      _sports.startLivePolling();
      if (_sports.live.isEmpty && _sports.posts.isEmpty) {
        _sports.bootstrap(language: lang);
      } else if (_sports.language != lang) {
        _sports.setLanguage(lang);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _sports.stopLivePolling();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (_scrollController.offset < max - 280) return;
    context.read<SportsProvider>().loadMoreNews();
  }

  void _openMatch(SportsMatch match) {
    if (match.id.isEmpty) return;
    context.push('/sports/match/${match.id}', extra: match);
  }

  Future<bool> _toggleLike(NewsPost post) async {
    final id = post.id;
    final prev = _likedByPostId[id] ?? false;
    _likedByPostId[id] = !prev;
    setState(() {});

    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (!loggedIn) {
      final liked = await ApiService.toggleGuestLike(id);
      if (!mounted) return false;
      _likedByPostId[id] = liked;
      return true;
    }
    final res = await ApiService.toggleLike(id);
    if (!mounted) return false;
    if (res['success'] != true) {
      _likedByPostId[id] = prev;
      setState(() {});
      return false;
    }
    _likedByPostId[id] = res['liked'] == true;
    setState(() {});
    return true;
  }

  Future<bool> _toggleBookmark(NewsPost post) async {
    final id = post.id;
    final prev = _bookmarkedByPostId[id] ?? false;
    _bookmarkedByPostId[id] = !prev;
    setState(() {});

    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (!loggedIn) {
      final saved = await ApiService.toggleGuestBookmark(post);
      if (!mounted) return false;
      _bookmarkedByPostId[id] = saved;
      return true;
    }
    final res = await ApiService.toggleBookmark(id);
    if (!mounted) return false;
    if (res['success'] != true) {
      _bookmarkedByPostId[id] = prev;
      setState(() {});
      return false;
    }
    _bookmarkedByPostId[id] = res['bookmarked'] == true;
    setState(() {});
    return true;
  }

  Future<void> _share(NewsPost post) async {
    final text =
        '${post.title}\n\n${premiumSnippet(post, maxLength: 260)}\n\n${post.sourceUrl ?? ''}';
    await Share.share(text, subject: post.title);
  }

  void _openArticle(NewsPost post) {
    context.push('/article/${post.id}');
  }

  @override
  Widget build(BuildContext context) {
    final news = context.watch<NewsProvider>();
    final lang = news.selectedLanguage;
    if (_lastLanguage != lang) {
      _lastLanguage = lang;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<SportsProvider>().setLanguage(lang);
      });
    }

    final bottom = FeedXpressoTheme.feedBottomInset(context);

    return GlassScaffold(
      child: RefreshIndicator(
        color: GlassColors.accentGreen,
        backgroundColor: const Color(0xFF0F172A),
        onRefresh: () => context.read<SportsProvider>().refreshAll(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(), // Bouncy overscroll for physical glass feel
          ),
          slivers: [
            // Custom premium frosted glass sliver app bar
            SliverAppBar(
              pinned: true,
              toolbarHeight: 52,
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Colors.white70),
                onPressed: () => context.pop(),
              ),
              title: const Text(
                'Cricket Arena',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              flexibleSpace: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF070A12).withOpacity(0.40),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.08),
                          width: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _scrollController,
                builder: (context, child) {
                  double offset = 0.0;
                  if (_scrollController.hasClients) {
                    offset = _scrollController.offset;
                  }
                  final collapseProgress = (offset / 160.0).clamp(0.0, 1.0);
                  final double heightFactor = 1.0 - collapseProgress;
                  final double opacity = 1.0 - collapseProgress;
                  final double translateY = -20.0 * collapseProgress;

                  return ClipRect(
                    child: Opacity(
                      opacity: opacity,
                      child: Align(
                        heightFactor: heightFactor,
                        alignment: Alignment.topCenter,
                        child: Transform.translate(
                          offset: Offset(0.0, translateY),
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
                child: _LiveSection(onMatchTap: _openMatch),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 24, 14, 8),
                child: Row(
                  children: [
                    // Premium neon capsule bullet
                    Container(
                      width: 4,
                      height: 15,
                      decoration: BoxDecoration(
                        color: GlassColors.accentGreen,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: GlassColors.accentGreen.withOpacity(0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Sports Feed',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _SportsPostsSection(
              bottom: bottom,
              likedByPostId: _likedByPostId,
              bookmarkedByPostId: _bookmarkedByPostId,
              onLike: _toggleLike,
              onBookmark: _toggleBookmark,
              onShare: _share,
              onOpen: _openArticle,
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveSection extends StatelessWidget {
  final void Function(SportsMatch) onMatchTap;

  const _LiveSection({required this.onMatchTap});

  Widget _sectionHeader({
    required String title,
    String? badge,
    Color? badgeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              color: Colors.white70,
              letterSpacing: -0.1,
            ),
          ),
          if (badge != null) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (badgeColor ?? GlassColors.accentGreen).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (badgeColor ?? GlassColors.accentGreen).withOpacity(0.30),
                  width: 0.8,
                ),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: badgeColor ?? GlassColors.accentGreenLight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _matchRow(
    List<SportsMatch> matches, {
    required double height,
  }) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: matches.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SportsLiveCard(
          match: matches[i],
          compact: true,
          onTap: () => onMatchTap(matches[i]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Selector<SportsProvider, (List<SportsMatch>, List<SportsMatch>, List<SportsMatch>, String, String?)>(
      selector: (_, p) => (p.live, p.upcoming, p.ipl, p.iplSectionTitle, p.liveError),
      builder: (context, data, _) {
        final live = data.$1;
        final upcoming = data.$2;
        final ipl = data.$3;
        final iplTitle = data.$4;
        final err = data.$5;
        if (live.isEmpty && upcoming.isEmpty && ipl.isEmpty) {
          return StaggeredEntranceAnimation(
            index: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 20, 14, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.8),
                ),
                child: Text(
                  err?.trim().isNotEmpty == true
                      ? err!
                      : 'No live matches currently. Pull to refresh.',
                  style: TextStyle(color: Colors.white.withOpacity(0.50), fontSize: 13, height: 1.35),
                ),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (live.isNotEmpty) ...[
              StaggeredEntranceAnimation(
                index: 0,
                child: _sectionHeader(
                  title: 'LIVE MATCHES',
                  badge: '${live.length} LIVE NOW',
                  badgeColor: Colors.redAccent,
                ),
              ),
              StaggeredEntranceAnimation(
                index: 1,
                child: _matchRow(live, height: 124),
              ),
            ],
            if (upcoming.isNotEmpty) ...[
              StaggeredEntranceAnimation(
                index: live.isNotEmpty ? 2 : 0,
                child: _sectionHeader(
                  title: 'UPCOMING FIXTURES',
                  badge: upcoming.length > 1 ? '${upcoming.length} Matches' : null,
                ),
              ),
              StaggeredEntranceAnimation(
                index: live.isNotEmpty ? 3 : 1,
                child: _matchRow(upcoming, height: 114),
              ),
            ],
            if (ipl.isNotEmpty) ...[
              StaggeredEntranceAnimation(
                index: live.isNotEmpty ? 4 : (upcoming.isNotEmpty ? 2 : 0),
                child: _sectionHeader(
                  title: iplTitle.toUpperCase(),
                  badge: ipl.every((m) => m.status == SportsMatchStatus.finished)
                      ? 'RECENT'
                      : '${ipl.length} MATCHES',
                ),
              ),
              StaggeredEntranceAnimation(
                index: live.isNotEmpty ? 5 : (upcoming.isNotEmpty ? 3 : 1),
                child: _matchRow(ipl, height: 124),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SportsPostsSection extends StatefulWidget {
  final double bottom;
  final Map<String, bool> likedByPostId;
  final Map<String, bool> bookmarkedByPostId;
  final Future<bool> Function(NewsPost) onLike;
  final Future<bool> Function(NewsPost) onBookmark;
  final void Function(NewsPost) onShare;
  final void Function(NewsPost) onOpen;

  const _SportsPostsSection({
    required this.bottom,
    required this.likedByPostId,
    required this.bookmarkedByPostId,
    required this.onLike,
    required this.onBookmark,
    required this.onShare,
    required this.onOpen,
  });

  @override
  State<_SportsPostsSection> createState() => _SportsPostsSectionState();
}

class _SportsPostsSectionState extends State<_SportsPostsSection> {
  @override
  Widget build(BuildContext context) {
    return Selector<SportsProvider, (List<NewsPost>, bool, bool, String?)>(
      selector: (_, p) =>
          (p.posts, p.loadingNews, p.loadingMoreNews, p.newsError),
      builder: (context, data, _) {
        final posts = data.$1;
        final loading = data.$2;
        final loadingMore = data.$3;
        final err = data.$4;

        if (loading && posts.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: GlassColors.accentGreen,
                ),
              ),
            ),
          );
        }

        if (posts.isEmpty && err != null) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                err,
                style: TextStyle(color: Colors.white.withOpacity(0.50)),
              ),
            ),
          );
        }

        if (posts.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No sports stories for your language yet. Pull to refresh.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.50),
                  fontSize: 13,
                ),
              ),
            ),
          );
        }

        final itemCount = posts.length + (loadingMore ? 1 : 0);
        return SliverPadding(
          padding: EdgeInsets.only(bottom: widget.bottom),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= posts.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: GlassColors.accentGreen,
                        ),
                      ),
                    ),
                  );
                }
                final post = posts[index];
                return StaggeredEntranceAnimation(
                  index: index.clamp(0, 7), // Cap staggered delay multiplier for infinite scroll items
                  child: GlassSportsArticleCard(
                    key: ValueKey(post.id),
                    post: post,
                    liked: widget.likedByPostId[post.id] ?? false,
                    saved: widget.bookmarkedByPostId[post.id] ?? false,
                    onOpen: () => widget.onOpen(post),
                    onLike: () => widget.onLike(post),
                    onShare: () => widget.onShare(post),
                    onBookmark: () => widget.onBookmark(post),
                  ),
                );
              },
              childCount: itemCount,
            ),
          ),
        );
      },
    );
  }
}
