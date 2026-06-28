import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../../providers/shorts_provider.dart';
import '../../providers/shorts_playback_controller.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../services/video_playlist.dart';
import '../../utils/i18n.dart';
import '../../utils/post_share.dart';
import '../../widgets/shorts/shorts_card_shimmer.dart';
import '../../widgets/shorts/shorts_feed_theme.dart';
import '../../widgets/premium_news_ui.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';
import '../../widgets/shorts/dailyhunt_shorts_page.dart';
import '../../widgets/shorts/shorts_chrome.dart';
import '../../widgets/shorts/shorts_feed_tuning.dart';
import '../../widgets/shorts/shorts_language_bar.dart';

/// YouTube-backed vertical shorts: [PageView.builder], official iframe embeds.
class ShortsNewsScreen extends StatefulWidget {
  const ShortsNewsScreen({super.key});

  @override
  State<ShortsNewsScreen> createState() => _ShortsNewsScreenState();
}

class _ShortsNewsScreenState extends State<ShortsNewsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final PageController _pageController;
  late final NewsProvider _news;
  late final ShortsProvider _shorts;
  late final ShortsPlaybackController _playback;
  bool _wasShortsRefreshing = false;
  bool _shortsBoundToNews = false;
  final ValueNotifier<int> _pageIndex = ValueNotifier(0);
  final Map<String, bool> _liked = {};
  final Map<String, bool> _saved = {};
  final Map<String, String?> _translated = {};
  final Map<String, bool> _translating = {};

  @override
  void initState() {
    super.initState();
    _news = context.read<NewsProvider>();
    _shorts = context.read<ShortsProvider>();
    _playback = context.read<ShortsPlaybackController>();
    _shorts.addListener(_onShortsRefreshTick);
    _shorts.addListener(_syncActivePlayback);
    _pageController = PageController();
    _bindShortsToFeedLanguage();
  }

  void _syncActivePlayback() {
    final posts = _shorts.posts;
    if (!mounted || posts.isEmpty) return;
    final i = _pageIndex.value.clamp(0, posts.length - 1);
    final id = posts[i].id;
    if (_playback.isActivePost(id)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = _shorts.posts;
      if (current.isEmpty) return;
      final j = _pageIndex.value.clamp(0, current.length - 1);
      _playback.setActivePost(current[j].id, immediate: true);
    });
  }

  void _bindShortsToFeedLanguage() {
    if (_shortsBoundToNews) return;
    _shortsBoundToNews = true;
    _news.addListener(_syncShortsToFeedLanguage);
    _syncShortsToFeedLanguage();
  }

  void _syncShortsToFeedLanguage() {
    if (!mounted || !_news.prefsLoaded) return;
    final lang = _news.shortsFeedLanguage;
    _shorts.ensureForLanguage(lang).then((_) {
      if (!mounted) return;
      final posts = _shorts.posts;
      if (posts.isNotEmpty) {
        ShortsFeedTuning.precacheInitialBatch(context, posts);
        _playback.setActivePost(posts.first.id, immediate: true);
      }
    });
  }

  /// After each reload, show the newest video first (page 0).
  void _onShortsRefreshTick() {
    final s = _shorts;
    if (_wasShortsRefreshing && !s.refreshing && s.posts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
        _pageIndex.value = 0;
        if (s.posts.isNotEmpty) {
          _playback.setActivePost(s.posts.first.id, immediate: true);
        }
      });
    }
    _wasShortsRefreshing = s.refreshing;
  }

  @override
  void dispose() {
    _news.removeListener(_syncShortsToFeedLanguage);
    _shorts.removeListener(_onShortsRefreshTick);
    _shorts.removeListener(_syncActivePlayback);
    _pageIndex.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _maybeLoadMore(int index, ShortsProvider shorts, String? lang) {
    if (index >= shorts.posts.length - 4 &&
        shorts.posts.isNotEmpty &&
        shorts.hasMore &&
        !shorts.loading) {
      shorts.loadMore(language: lang);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Could not update')),
      );
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
      // Also save YouTube videos to playlist
      if (post.isYoutube && saved) {
        await VideoPlaylistService.add(post);
      } else if (post.isYoutube && !saved) {
        await VideoPlaylistService.remove(id);
      }
      return true;
    }
    final res = await ApiService.toggleBookmark(id);
    if (!mounted) return false;
    if (res['success'] != true) {
      _saved[id] = prev;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Could not save')),
      );
      return false;
    }
    _saved[id] = res['bookmarked'] == true;
    // Also save YouTube videos to playlist
    if (post.isYoutube) {
      final isBookmarked = res['bookmarked'] == true;
      if (isBookmarked) {
        await VideoPlaylistService.add(post);
      } else {
        await VideoPlaylistService.remove(id);
      }
    }
    return true;
  }

  Future<void> _share(NewsPost post) async {
    await PostShare.sharePost(post, context: context);
  }

  Future<void> _translate(NewsPost post) async {
    final id = post.id;
    if (_translating[id] == true) return;
    if (_translated[id] != null) {
      setState(() => _translated.remove(id));
      return;
    }
    setState(() => _translating[id] = true);
    final lang = context.read<NewsProvider>().selectedLanguage;
    final target = lang == 'all' ? 'te' : lang;
    final res = await ApiService.translateText(
      text: premiumSnippet(post, maxLength: 220),
      targetLanguage: target,
    );
    if (!mounted) return;
    setState(() {
      _translating[id] = false;
      if (res['success'] == true) {
        final t = res['translatedText']?.toString().trim();
        if (t != null && t.isNotEmpty) _translated[id] = t;
      }
    });
  }

  void _openArticle(NewsPost post) {
    if (post.isYoutube) {
      final url = post.youtubeWatchUrl;
      if (url != null && url.isNotEmpty) {
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      return;
    }
    context.push('/article/${post.id}');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final lang = context.select<NewsProvider, String?>(
      (n) => n.shortsFeedLanguage,
    );
    final posts = context.select<ShortsProvider, List<NewsPost>>(
      (s) => s.posts,
    );
    final shortsError = context.select<ShortsProvider, String?>(
      (s) => s.error,
    );
    final shortsRefreshing = context.select<ShortsProvider, bool>(
      (s) => s.refreshing,
    );
    final shortsLoading = context.select<ShortsProvider, bool>(
      (s) => s.loading,
    );

    final bottomPad = FeedXpressoTheme.feedBottomInset(context) + 28;
    final pageHeight = MediaQuery.sizeOf(context).height;

    final st = ShortsFeedTheme.fx(context);

    if (shortsError != null && posts.isEmpty && !shortsRefreshing) {
      return Scaffold(
        backgroundColor: st.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shortsError,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: st.body),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      context.read<ShortsProvider>().refresh(language: lang),
                  child: Text(I18n.t(context, 'action_try_again')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (posts.isEmpty && shortsRefreshing) {
      return Scaffold(
        backgroundColor: st.background,
        body: Column(
          children: [
            const SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DailyhuntShortsTopBar(),
                  ShortsLanguageBar(),
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
            const SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DailyhuntShortsTopBar(),
                  ShortsLanguageBar(),
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
                        I18n.t(context, 'shorts_empty_title'),
                        style: TextStyle(
                          color: st.title,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        I18n.t(context, 'shorts_empty_subtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: st.meta,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context
                            .read<ShortsProvider>()
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
          _ShortsFeedPager(
            pageController: _pageController,
            pageHeight: pageHeight,
            bottomPad: bottomPad,
            posts: posts,
            liked: _liked,
            saved: _saved,
            translating: _translating,
            translated: _translated,
            onIndexChanged: (i) {
              _pageIndex.value = i;
              _playback.setActivePost(posts[i].id, immediate: true);
              _maybeLoadMore(i, context.read<ShortsProvider>(), lang);
              ShortsFeedTuning.precacheThumbnails(context, posts, i);
            },
            onLike: _toggleLike,
            onSave: _toggleSave,
            onShare: _share,
            onTranslate: _translate,
            onOpenArticle: _openArticle,
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DailyhuntShortsTopBar(),
                ShortsLanguageBar(),
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
          if (shortsRefreshing && posts.isNotEmpty)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 72,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: st.scrim.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: st.meta,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        I18n.t(context, 'shorts_refreshing'),
                        style: TextStyle(color: st.meta, fontSize: 11),
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
}

/// Vertical [PageView] — owns active index so parent does not rebuild on every swipe.
class _ShortsFeedPager extends StatefulWidget {
  final PageController pageController;
  final double pageHeight;
  final double bottomPad;
  final List<NewsPost> posts;
  final Map<String, bool> liked;
  final Map<String, bool> saved;
  final Map<String, bool> translating;
  final Map<String, String?> translated;
  final ValueChanged<int> onIndexChanged;
  final Future<bool> Function(NewsPost) onLike;
  final Future<bool> Function(NewsPost) onSave;
  final void Function(NewsPost) onShare;
  final void Function(NewsPost) onTranslate;
  final void Function(NewsPost) onOpenArticle;

  const _ShortsFeedPager({
    required this.pageController,
    required this.pageHeight,
    required this.bottomPad,
    required this.posts,
    required this.liked,
    required this.saved,
    required this.translating,
    required this.translated,
    required this.onIndexChanged,
    required this.onLike,
    required this.onSave,
    required this.onShare,
    required this.onTranslate,
    required this.onOpenArticle,
  });

  @override
  State<_ShortsFeedPager> createState() => _ShortsFeedPagerState();
}

class _ShortsFeedPagerState extends State<_ShortsFeedPager> {
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
              translating: widget.translating[post.id] ?? false,
              translatedSummary: widget.translated[post.id],
              onLike: () => widget.onLike(post),
              onSave: () => widget.onSave(post),
              onShare: () => widget.onShare(post),
              onTranslate: () => widget.onTranslate(post),
              onOpenArticle: () => widget.onOpenArticle(post),
              bottomContentPadding: widget.bottomPad,
            ),
          ),
        );
      },
    );
  }
}
