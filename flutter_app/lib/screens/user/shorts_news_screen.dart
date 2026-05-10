import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../../providers/shorts_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/news_shimmer_loader.dart';
import '../../widgets/premium_news_ui.dart';
import '../../widgets/shorts/dailyhunt_shorts_page.dart';
import '../../widgets/shorts/shorts_chrome.dart';

/// RSS-backed vertical shorts: [PageView.builder], Dailyhunt-style layout, light motion.
class ShortsNewsScreen extends StatefulWidget {
  const ShortsNewsScreen({super.key});

  static const double _navBarHeight = 66;

  @override
  State<ShortsNewsScreen> createState() => _ShortsNewsScreenState();
}

class _ShortsNewsScreenState extends State<ShortsNewsScreen> {
  late final PageController _pageController;
  late final NewsProvider _news;
  int _index = 0;
  final Map<String, bool> _liked = {};
  final Map<String, bool> _saved = {};
  final Map<String, String?> _translated = {};
  final Map<String, bool> _translating = {};

  @override
  void initState() {
    super.initState();
    _news = context.read<NewsProvider>();
    _news.addListener(_onNewsLanguageChanged);
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lang = _apiLanguage(_news);
      final shorts = context.read<ShortsProvider>();
      if (!shorts.hasContentFor(lang)) {
        shorts.refresh(language: lang);
      }
    });
  }

  void _onNewsLanguageChanged() {
    final lang = _apiLanguage(_news);
    final shorts = context.read<ShortsProvider>();
    if (!shorts.languageMatches(lang)) {
      shorts.refresh(language: lang);
    }
  }

  String? _apiLanguage(NewsProvider news) {
    final l = news.selectedLanguage;
    return l == 'all' ? null : l;
  }

  @override
  void dispose() {
    _news.removeListener(_onNewsLanguageChanged);
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

  Future<void> _toggleLike(NewsPost post) async {
    final id = post.id;
    final prev = _liked[id] ?? false;
    setState(() => _liked[id] = !prev);

    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (!loggedIn) {
      final liked = await ApiService.toggleGuestLike(id);
      if (mounted) setState(() => _liked[id] = liked);
      return;
    }
    final res = await ApiService.toggleLike(id);
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() => _liked[id] = prev);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Could not update')),
      );
      return;
    }
    setState(() => _liked[id] = res['liked'] == true);
  }

  Future<void> _toggleSave(NewsPost post) async {
    final id = post.id;
    final prev = _saved[id] ?? false;
    setState(() => _saved[id] = !prev);

    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (!loggedIn) {
      final saved = await ApiService.toggleGuestBookmark(post);
      if (mounted) setState(() => _saved[id] = saved);
      return;
    }
    final res = await ApiService.toggleBookmark(id);
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() => _saved[id] = prev);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Could not save')),
      );
      return;
    }
    setState(() => _saved[id] = res['bookmarked'] == true);
  }

  Future<void> _share(NewsPost post) async {
    final text =
        '${post.title}\n\n${premiumSnippet(post, maxLength: 260)}\n\n${post.sourceUrl ?? ''}';
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
    context.push('/article/${post.id}');
  }

  @override
  Widget build(BuildContext context) {
    final shorts = context.watch<ShortsProvider>();
    final lang = _apiLanguage(context.watch<NewsProvider>());
    final posts = shorts.posts;

    final bottomPad =
        MediaQuery.paddingOf(context).bottom + ShortsNewsScreen._navBarHeight + 20;

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
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (posts.isEmpty && shorts.refreshing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: NewsShimmerLoader(
            count: 6,
            backgroundColor: Colors.black,
          ),
        ),
      );
    }

    if (posts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No RSS video shorts yet',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Shorts shows RSS items that include a video file. Try again after ingestion.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => shorts.refresh(language: lang),
                  child: const Text('Refresh'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            allowImplicitScrolling: false,
            itemCount: posts.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _maybeLoadMore(i, shorts, lang);
            },
            itemBuilder: (context, i) {
              final post = posts[i];
              return RepaintBoundary(
                child: DailyhuntShortsPage(
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
              );
            },
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DailyhuntShortsTopBar(),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: MediaQuery.paddingOf(context).bottom + ShortsNewsScreen._navBarHeight + 6,
            child: ShortsFeedProgress(
              total: posts.length,
              index: _index,
            ),
          ),
          if (shorts.loading && posts.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 72,
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
