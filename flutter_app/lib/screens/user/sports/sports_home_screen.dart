import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../models/models.dart';
import '../../../models/sports_models.dart';
import '../../../services/auth_provider.dart';
import '../../../providers/news_provider.dart';
import '../../../providers/sports_provider.dart';
import '../../../services/api_service.dart';
import '../../../utils/i18n.dart';
import '../../../utils/post_share.dart';
import '../../../widgets/dailyhunt/xpresso_sliver_app_bar.dart';
import '../../../widgets/feed/dailyhunt_feed_article_card.dart';
import '../../../widgets/feed/feed_image_cache.dart';
import '../../../widgets/feed/feed_list_tuning.dart';
import '../../../widgets/feed/feed_xpresso_theme.dart';
import '../../../widgets/premium_news_ui.dart';
import '../../../widgets/sports/sports_live_card.dart';

/// Cricket / sports hub — live scores + sports feed (language-aware RSS).
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

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/feed');
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
    await PostShare.sharePost(post, context: context);
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

    final fx = FeedXpressoTheme.fx(context);
    final bottom = FeedXpressoTheme.feedBottomInset(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
      backgroundColor: fx.background,
      body: RefreshIndicator(
        color: fx.accent,
        onRefresh: () => context.read<SportsProvider>().refreshAll(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: [
            XpressoSliverAppBar(
              title: I18n.t(context, 'sports_title_cricket'),
              showBack: true,
              onBack: _handleBack,
              actions: [
                IconButton(
                  tooltip: I18n.t(context, 'sports_leaderboard_tooltip'),
                  onPressed: () => context.push('/sports/leaderboard'),
                  icon: const Icon(Icons.emoji_events_outlined),
                ),
              ],
            ),
            SliverToBoxAdapter(child: _LiveSection(onMatchTap: _openMatch)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
                child: Text(
                  I18n.t(context, 'sports_news_section'),
                  style: fx.screenTitleStyle.copyWith(fontSize: 16),
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
    ),
    );
  }
}

class _LiveSection extends StatelessWidget {
  final void Function(SportsMatch) onMatchTap;

  const _LiveSection({required this.onMatchTap});

  Widget _sectionHeader(
    FeedXpressoPalette fx, {
    required String title,
    String? badge,
    Color? badgeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: fx.title,
            ),
          ),
          if (badge != null) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (badgeColor ?? fx.accent).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badgeColor ?? fx.accent,
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
        separatorBuilder: (_, __) => SizedBox(width: 10),
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
    final fx = FeedXpressoTheme.fx(context);
    return Selector<SportsProvider, (List<SportsMatch>, List<SportsMatch>, List<SportsMatch>, String, String?)>(
      selector: (_, p) => (p.live, p.upcoming, p.ipl, p.iplSectionTitle, p.liveError),
      builder: (context, data, _) {
        final live = data.$1;
        final upcoming = data.$2;
        final ipl = data.$3;
        final iplTitle = data.$4;
        final err = data.$5;
        if (live.isEmpty && upcoming.isEmpty && ipl.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Text(
              err?.trim().isNotEmpty == true
                  ? err!
                  : 'No live or upcoming matches right now. Pull to refresh.',
              style: TextStyle(color: fx.meta, fontSize: 13, height: 1.35),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (live.isNotEmpty) ...[
              _sectionHeader(
                fx,
                title: 'Live now',
                badge: '${live.length} live',
                badgeColor: fx.live,
              ),
              _matchRow(live, height: 118),
            ],
            if (upcoming.isNotEmpty) ...[
              _sectionHeader(
                fx,
                title: 'Upcoming',
                badge: upcoming.length > 1 ? '${upcoming.length} matches' : null,
              ),
              _matchRow(upcoming, height: 108),
            ],
            if (ipl.isNotEmpty) ...[
              _sectionHeader(
                fx,
                title: iplTitle,
                badge: ipl.every((m) => m.status == SportsMatchStatus.finished)
                    ? 'Recent'
                    : '${ipl.length} matches',
              ),
              _matchRow(ipl, height: 118),
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
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }

        if (posts.isEmpty && err != null) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                err,
                style: TextStyle(color: FeedXpressoTheme.fx(context).meta),
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
                  color: FeedXpressoTheme.fx(context).meta,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          final controller = PrimaryScrollController.maybeOf(context);
          if (controller != null && controller.hasClients) {
            FeedImagePrecache.onScroll(context, posts, controller.position);
          }
        });

        final itemCount = posts.length + (loadingMore ? 1 : 0);
        return SliverPadding(
          padding: EdgeInsets.only(bottom: widget.bottom),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= posts.length) {
                  return const FeedListLoadingFooter();
                }
                final post = posts[index];
                return DailyhuntFeedArticleCard(
                  key: ValueKey(post.id),
                  post: post,
                  liked: widget.likedByPostId[post.id] ?? false,
                  saved: widget.bookmarkedByPostId[post.id] ?? false,
                  onOpen: () => widget.onOpen(post),
                  onLike: () => widget.onLike(post),
                  onShare: () => widget.onShare(post),
                  onBookmark: () => widget.onBookmark(post),
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
