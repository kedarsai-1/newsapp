import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../../providers/shorts_provider.dart';
import '../../providers/shorts_playback_controller.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../utils/i18n.dart';
import '../../widgets/shorts/shorts_card_shimmer.dart';
import '../../widgets/shorts/shorts_feed_theme.dart';
import '../../widgets/premium_news_ui.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';
import '../../widgets/shorts/dailyhunt_shorts_page.dart';
import '../../widgets/shorts/shorts_chrome.dart';
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
  int _index = 0;
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
    _pageController = PageController();
    _bindShortsToFeedLanguage();
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
    _shorts.ensureForLanguage(lang);
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
        setState(() => _index = 0);
        if (s.posts.isNotEmpty) {
          _playback.setActivePost(s.posts.first.id);
        }
      });
    }
    _wasShortsRefreshing = s.refreshing;
  }

  @override
  void dispose() {
    _news.removeListener(_syncShortsToFeedLanguage);
    _shorts.removeListener(_onShortsRefreshTick);
    _pageController.dispose();
    super.dispose();
  }

  void _maybeLoadMore(int index, ShortsProvider shorts, String? lang) {
    if (index >= shorts.posts.length - 2 &&
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
    return true;
  }

  Future<void> _share(NewsPost post) async {
    final link = post.isYoutube
        ? (post.youtubeWatchUrl ?? post.sourceUrl ?? '')
        : (post.sourceUrl ?? '');
    final text = post.isYoutube
        ? '${post.title}\n\n$link'
        : '${post.title}\n\n${premiumSnippet(post, maxLength: 260)}\n\n$link';
    await Share.share(text, subject: post.title);
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
    final shorts = context.watch<ShortsProvider>();
    final news = context.watch<NewsProvider>();
    final lang = news.shortsFeedLanguage;
    final posts = shorts.posts;
    if (posts.isNotEmpty) {
      final wantId = posts[_index.clamp(0, posts.length - 1)].id;
      if (!_playback.isActivePost(wantId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final current = shorts.posts;
          if (current.isEmpty) return;
          final id = current[_index.clamp(0, current.length - 1)].id;
          _playback.setActivePost(id);
        });
      }
    }

    final bottomPad = FeedXpressoTheme.feedBottomInset(context) + 28;
    final pageHeight = MediaQuery.sizeOf(context).height;

    if (shorts.error != null && posts.isEmpty && !shorts.refreshing) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shorts.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => shorts.refresh(language: lang),
                  child: Text(I18n.t(context, 'action_try_again')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (posts.isEmpty && shorts.refreshing) {
      return Scaffold(
        backgroundColor: ShortsFeedTheme.background,
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
        backgroundColor: Colors.black,
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
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        I18n.t(context, 'shorts_empty_subtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => shorts.refresh(language: lang),
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
      backgroundColor: ShortsFeedTheme.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const _ShortsSnapScrollPhysics(),
            pageSnapping: true,
            allowImplicitScrolling: true,
            itemCount: posts.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _playback.setActivePost(posts[i].id);
              _maybeLoadMore(i, shorts, lang);
            },
            itemBuilder: (context, i) {
              final post = posts[i];
              return SizedBox(
                height: pageHeight,
                child: RepaintBoundary(
                  child: DailyhuntShortsPage(
                    key: ValueKey(post.id),
                    post: post,
                    isActive: i == _index,
                    liked: _liked[post.id] ?? false,
                    saved: _saved[post.id] ?? false,
                    translating: _translating[post.id] ?? false,
                    translatedSummary: _translated[post.id],
                    onLike: () => _toggleLike(post),
                    onSave: () => _toggleSave(post),
                    onShare: () => _share(post),
                    onTranslate: () => _translate(post),
                    onOpenArticle: () => _openArticle(post),
                    bottomContentPadding: bottomPad,
                  ),
                ),
              );
            },
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
            child: ShortsFeedProgress(
              total: posts.length,
              index: _index,
            ),
          ),
          if (shorts.loading && posts.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: FeedXpressoTheme.feedBottomInset(context),
              child: const SafeArea(
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
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

/// Full-viewport vertical snap between Shorts pages.
class _ShortsSnapScrollPhysics extends ScrollPhysics {
  const _ShortsSnapScrollPhysics({super.parent});

  @override
  _ShortsSnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _ShortsSnapScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.5,
        stiffness: 320,
        damping: 34,
      );

  @override
  double get minFlingVelocity => 280;

  @override
  double get maxFlingVelocity => 4200;

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final page = position.pixels / position.viewportDimension;
    final target = velocity.abs() < 350
        ? page.round()
        : (velocity > 0 ? page.ceil() : page.floor());
    final clamped = target.clamp(0, (position.maxScrollExtent / position.viewportDimension).round());
    final to = clamped * position.viewportDimension;
    if ((to - position.pixels).abs() < 0.5) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      to,
      velocity,
      tolerance: toleranceFor(position),
    );
  }
}
