import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/news_shimmer_loader.dart';
import '../../widgets/premium_news_ui.dart';
import '../../widgets/shorts/shorts_chrome.dart';
import '../../widgets/shorts/shorts_reel_page.dart';

/// Vertical Shorts-style reel (Dailyhunt-inspired): full-screen cards + glass actions.
class ShortsNewsScreen extends StatefulWidget {
  const ShortsNewsScreen({super.key});

  static const double _navBarHeight = 66;

  @override
  State<ShortsNewsScreen> createState() => _ShortsNewsScreenState();
}

class _ShortsNewsScreenState extends State<ShortsNewsScreen> {
  late final PageController _pageController;
  int _index = 0;
  final Map<String, bool> _liked = {};
  final Map<String, bool> _saved = {};
  final Map<String, String?> _translated = {};
  final Map<String, bool> _translating = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final news = context.read<NewsProvider>();
      if (news.posts.isEmpty && !news.refreshing) news.refresh();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isDemoPost(NewsPost p) => p.id.startsWith('demo-shorts-');

  List<NewsPost> _effectivePosts(NewsProvider news) {
    if (news.posts.isNotEmpty) return news.posts;
    return _demoPosts();
  }

  List<NewsPost> _demoPosts() {
    return List<NewsPost>.generate(8, (i) {
      final seed = 'shorts_demo_$i';
      return NewsPost(
        id: 'demo-shorts-$i',
        title: i.isEven
            ? 'షార్ట్స్ డెమో: నిలువుగా స్వైప్ చేసి తదుపరి కథనానికి వెళ్లండి'
            : 'Shorts demo: swipe up for the next story in your feed',
        body: 'Body text for preview card ${i + 1}.',
        summary:
            'Two or three lines of summary copy so the layout matches production Shorts cards with readable contrast over imagery.',
        status: 'published',
        createdAt: DateTime.now().subtract(Duration(minutes: i * 7 + 2)),
        sourceName: i % 2 == 0 ? 'Local Bureau' : 'Wire Desk',
        media: [
          MediaItem(
            id: 'm-$i',
            type: 'image',
            url: 'https://picsum.photos/seed/$seed/1080/1920',
          ),
        ],
      );
    });
  }

  void _maybeLoadMore(int index, NewsProvider news) {
    if (index >= news.posts.length - 2 &&
        news.posts.isNotEmpty &&
        news.hasMore &&
        !news.loading) {
      news.loadMore();
    }
  }

  Future<void> _toggleLike(NewsPost post) async {
    final id = post.id;
    final prev = _liked[id] ?? false;
    setState(() => _liked[id] = !prev);

    if (_isDemoPost(post)) return;

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

    if (_isDemoPost(post)) return;

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
    if (_isDemoPost(post)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in and load the feed for full articles'),
          behavior: SnackBarBehavior.floating,
          width: 320,
        ),
      );
      return;
    }
    context.push('/article/${post.id}');
  }

  @override
  Widget build(BuildContext context) {
    final news = context.watch<NewsProvider>();
    final posts = _effectivePosts(news);

    if (news.error != null && news.posts.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  news.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => news.refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (news.posts.isEmpty && news.refreshing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(child: NewsShimmerLoader(count: 4)),
      );
    }

    if (posts.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'No stories yet',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final bottomPad =
        MediaQuery.of(context).padding.bottom + ShortsNewsScreen._navBarHeight + 12;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            allowImplicitScrolling: false,
            itemCount: posts.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _maybeLoadMore(i, news);
            },
            itemBuilder: (context, i) {
              final post = posts[i];
              return RepaintBoundary(
                child: ShortsReelPage(
                  post: post,
                  pageController: _pageController,
                  pageIndex: i,
                  liked: _liked[post.id] ?? false,
                  saved: _saved[post.id] ?? false,
                  translatedSummary: _translated[post.id],
                  onLike: () => _toggleLike(post),
                  onSave: () => _toggleSave(post),
                  onShare: () => _share(post),
                  onTranslate: () => _translate(post),
                  onOpenArticle: () => _openArticle(post),
                ),
              );
            },
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ShortsTopBar(),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomPad,
            child: StoryProgressDots(
              total: posts.length,
              index: _index,
            ),
          ),
        ],
      ),
    );
  }
}
