import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';
import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../../providers/political_videos_provider.dart';
import '../../providers/shorts_playback_controller.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../utils/i18n.dart';
import '../../utils/post_share.dart';
import '../../widgets/dailyhunt/xpresso_side_menu.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';
import '../../widgets/shorts/dailyhunt_shorts_page.dart';
import '../../widgets/shorts/shorts_card_shimmer.dart';
import '../../widgets/shorts/shorts_chrome.dart';
import '../../widgets/shorts/shorts_feed_theme.dart';
import '../../widgets/shorts/shorts_feed_tuning.dart';
import '../../widgets/shorts/shorts_language_bar.dart';

/// Classified political interviews / debates / press meets (YouTube embed only).
class PoliticalReelsScreen extends StatefulWidget {
  const PoliticalReelsScreen({super.key});

  @override
  State<PoliticalReelsScreen> createState() => _PoliticalReelsScreenState();
}

class _PoliticalReelsScreenState extends State<PoliticalReelsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final PageController _pageController;
  late final NewsProvider _news;
  late final PoliticalVideosProvider _political;
  late final ShortsPlaybackController _playback;
  bool _wasRefreshing = false;
  bool _boundToNews = false;
  final ValueNotifier<int> _pageIndex = ValueNotifier(0);
  final Map<String, bool> _liked = {};
  final Map<String, bool> _saved = {};

  @override
  void initState() {
    super.initState();
    _news = context.read<NewsProvider>();
    _political = context.read<PoliticalVideosProvider>();
    _playback = context.read<ShortsPlaybackController>();
    _political.addListener(_onRefreshTick);
    _political.addListener(_syncActivePlayback);
    _pageController = PageController();
    _bindToFeedLanguage();
  }

  void _syncActivePlayback() {
    final posts = _political.posts;
    if (!mounted || posts.isEmpty) return;
    final i = _pageIndex.value.clamp(0, posts.length - 1);
    final id = posts[i].id;
    if (_playback.isActivePost(id)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = _political.posts;
      if (current.isEmpty) return;
      final j = _pageIndex.value.clamp(0, current.length - 1);
      _playback.setActivePost(current[j].id, immediate: true);
    });
  }

  void _bindToFeedLanguage() {
    if (_boundToNews) return;
    _boundToNews = true;
    _news.addListener(_syncToFeedLanguage);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncToFeedLanguage());
  }

  void _syncToFeedLanguage() {
    if (!mounted || !_news.prefsLoaded) return;
    _political.ensureForLanguage(_news.shortsFeedLanguage);
  }

  void _onRefreshTick() {
    final p = _political;
    if (_wasRefreshing && !p.refreshing && p.posts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pageController.hasClients) _pageController.jumpToPage(0);
        _pageIndex.value = 0;
        if (p.posts.isNotEmpty) {
          _playback.setActivePost(p.posts.first.id, immediate: true);
        }
      });
    }
    _wasRefreshing = p.refreshing;
  }

  @override
  void dispose() {
    _news.removeListener(_syncToFeedLanguage);
    _political.removeListener(_onRefreshTick);
    _political.removeListener(_syncActivePlayback);
    _pageIndex.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _maybeLoadMore(int index, PoliticalVideosProvider provider, String? lang) {
    if (index >= provider.posts.length - 4 &&
        provider.posts.isNotEmpty &&
        provider.hasMore &&
        !provider.loading) {
      provider.loadMore(language: lang);
    }
  }

  Future<bool> _toggleLike(NewsPost post) async {
    final id = post.id;
    final prev = _liked[id] ?? false;
    _liked[id] = !prev;

    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (!loggedIn) {
      final liked = await ApiService.toggleGuestLike(id);
      if (!mounted) return false;
      _liked[id] = liked;
      return true;
    }
    final res = await ApiService.toggleLike(id);
    if (!mounted) return false;
    if (res['success'] != true) {
      _liked[id] = prev;
      return false;
    }
    _liked[id] = res['liked'] == true;
    return true;
  }

  Future<bool> _toggleSave(NewsPost post) async {
    final id = post.id;
    final prev = _saved[id] ?? false;
    _saved[id] = !prev;

    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (!loggedIn) {
      final saved = await ApiService.toggleGuestBookmark(post);
      if (!mounted) return false;
      _saved[id] = saved;
      return true;
    }
    final res = await ApiService.toggleBookmark(id);
    if (!mounted) return false;
    if (res['success'] != true) {
      _saved[id] = prev;
      return false;
    }
    _saved[id] = res['bookmarked'] == true;
    return true;
  }

  Future<void> _share(NewsPost post) async {
    await PostShare.sharePost(post, context: context);
  }

  void _openArticle(NewsPost post) {
    final url = post.youtubeWatchUrl;
    if (url != null && url.isNotEmpty) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang = context.select<NewsProvider, String?>(
      (n) => n.shortsFeedLanguage,
    );
    final posts = context.select<PoliticalVideosProvider, List<NewsPost>>(
      (p) => p.posts,
    );
    final error = context.select<PoliticalVideosProvider, String?>(
      (p) => p.error,
    );
    final refreshing = context.select<PoliticalVideosProvider, bool>(
      (p) => p.refreshing,
    );
    final loading = context.select<PoliticalVideosProvider, bool>(
      (p) => p.loading,
    );

    final bottomPad = FeedXpressoTheme.feedBottomInset(context) + 28;
    final pageHeight = MediaQuery.sizeOf(context).height;
    final st = ShortsFeedTheme.fx(context);

    if (error != null && posts.isEmpty && !refreshing) {
      return Scaffold(
        backgroundColor: st.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error, textAlign: TextAlign.center, style: TextStyle(color: st.body)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      context.read<PoliticalVideosProvider>().refresh(language: lang),
                  child: Text(I18n.t(context, 'action_try_again')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (posts.isEmpty && refreshing) {
      return Scaffold(
        backgroundColor: st.background,
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PoliticalReelsTopBar(st: st),
                  const ShortsLanguageBar(),
                ],
              ),
            ),
            Expanded(child: ShortsCardShimmer(topInset: 8)),
          ],
        ),
      );
    }

    if (posts.isEmpty) {
      return Scaffold(
        backgroundColor: st.background,
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PoliticalReelsTopBar(st: st),
                  const ShortsLanguageBar(),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No political videos yet',
                        style: TextStyle(color: st.title, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Interviews, debates, and press meets appear here after the server ingests YouTube channels.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: st.meta, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context
                            .read<PoliticalVideosProvider>()
                            .refresh(language: lang),
                        child: Text(I18n.t(context, 'action_refresh')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: st.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _PoliticalFeedPager(
            pageController: _pageController,
            pageHeight: pageHeight,
            bottomPad: bottomPad,
            posts: posts,
            liked: _liked,
            saved: _saved,
            onIndexChanged: (i) {
              _pageIndex.value = i;
              _playback.setActivePost(posts[i].id, immediate: true);
              _maybeLoadMore(i, context.read<PoliticalVideosProvider>(), lang);
              ShortsFeedTuning.precacheThumbnails(context, posts, i);
            },
            onLike: _toggleLike,
            onSave: _toggleSave,
            onShare: _share,
            onOpenArticle: _openArticle,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PoliticalReelsTopBar(st: st),
                const ShortsLanguageBar(),
              ],
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: FeedXpressoTheme.feedBottomInset(context) + 6,
            child: ValueListenableBuilder<int>(
              valueListenable: _pageIndex,
              builder: (_, index, __) => ShortsFeedProgress(
                total: posts.length,
                index: index,
              ),
            ),
          ),
          if (loading && posts.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: FeedXpressoTheme.feedBottomInset(context),
              child: SafeArea(
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: st.meta,
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

class _PoliticalReelsTopBar extends StatelessWidget {
  final ShortsFeedPalette st;

  const _PoliticalReelsTopBar({required this.st});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            st.background.withValues(alpha: 0.95),
            st.background.withValues(alpha: 0.72),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: st.iconOnChrome),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/feed');
                  }
                },
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Political Reels',
                      style: GoogleFonts.notoSans(
                        color: st.chromeFg,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      AppConstants.appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSans(
                        color: st.chromeFgMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.menu_rounded, color: st.iconOnChrome),
                onPressed: () => XpressoSideMenu.open(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PoliticalFeedPager extends StatefulWidget {
  final PageController pageController;
  final double pageHeight;
  final double bottomPad;
  final List<NewsPost> posts;
  final Map<String, bool> liked;
  final Map<String, bool> saved;
  final ValueChanged<int> onIndexChanged;
  final Future<bool> Function(NewsPost) onLike;
  final Future<bool> Function(NewsPost) onSave;
  final void Function(NewsPost) onShare;
  final void Function(NewsPost) onOpenArticle;

  const _PoliticalFeedPager({
    required this.pageController,
    required this.pageHeight,
    required this.bottomPad,
    required this.posts,
    required this.liked,
    required this.saved,
    required this.onIndexChanged,
    required this.onLike,
    required this.onSave,
    required this.onShare,
    required this.onOpenArticle,
  });

  @override
  State<_PoliticalFeedPager> createState() => _PoliticalFeedPagerState();
}

class _PoliticalFeedPagerState extends State<_PoliticalFeedPager> {
  int _activeIndex = 0;

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: widget.pageController,
      scrollDirection: Axis.vertical,
      physics: ShortsFeedTuning.scrollPhysics,
      pageSnapping: true,
      allowImplicitScrolling: ShortsFeedTuning.allowImplicitScrolling,
      itemCount: widget.posts.length,
      onPageChanged: (i) {
        setState(() => _activeIndex = i);
        widget.onIndexChanged(i);
      },
      itemBuilder: (context, i) {
        final post = widget.posts[i];
        return SizedBox(
          height: widget.pageHeight,
          child: RepaintBoundary(
            child: DailyhuntShortsPage(
              key: ValueKey(post.id),
              post: post,
              isActive: i == _activeIndex,
              liked: widget.liked[post.id] ?? false,
              saved: widget.saved[post.id] ?? false,
              translating: false,
              onLike: () => widget.onLike(post),
              onSave: () => widget.onSave(post),
              onShare: () => widget.onShare(post),
              onTranslate: () {},
              onOpenArticle: () => widget.onOpenArticle(post),
              bottomContentPadding: widget.bottomPad,
            ),
          ),
        );
      },
    );
  }
}
