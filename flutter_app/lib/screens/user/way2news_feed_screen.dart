import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../constants.dart';
import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../utils/feed_image_url.dart';
import '../../utils/post_share.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';
import '../../widgets/feed/story_page_card.dart';
import '../../widgets/feed/story_skeleton_card.dart';

/// Full-screen vertical story feed — Way2News interaction model.
///
/// Architecture:
///  • Single PageView (vertical) renders one StoryPageCard per story.
///  • PageStorageKey per category preserves scroll position when switching.
///  • Two overlaid PageViews (image layer + content layer) replaced by one
///    unified StoryPageCard that composites both — halves the widget tree depth.
///  • Single standard feed mode (no category strip / layout modes).
///  • Image prefetch for adjacent pages, RepaintBoundary on hero images.

class Way2NewsFeedScreen extends StatefulWidget {
  const Way2NewsFeedScreen({super.key});

  @override
  State<Way2NewsFeedScreen> createState() => _Way2NewsFeedScreenState();
}

class _Way2NewsFeedScreenState extends State<Way2NewsFeedScreen> {
  // ── Controllers & scroll position ───────────────────────────────────────
  late final PageController _storyPageController;

  // Per-category scroll positions (keyed by category slug).
  final Map<String, double> _scrollPositions = {};


  // ── State ────────────────────────────────────────────────────────────────
  int _currentCategoryIndex = 0;
  int _currentStoryIndex = 0;
  bool _storyLoading = true;
  String? _error;

  final List<NewsPost> _stories = [];
  final Map<String, bool> _liked = {};
  final Map<String, bool> _bookmarked = {};

  // ── Feed mode (single standard stream) ──────────────────────────────────
  static const List<_CategoryConfig> _categories = [
    _CategoryConfig(
      slug: null,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _storyPageController = PageController();
    _loadCategoryStories(_currentCategoryIndex);
  }

  @override
  void dispose() {
    _storyPageController.dispose();
    super.dispose();
  }

  // ── Persistence key per category ─────────────────────────────────────────

  PageStorageKey<String> _storyStorageKey(String? slug) {
    final key = 'way2news_${slug ?? 'foryou'}';
    return PageStorageKey(key);
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  Future<void> _loadCategoryStories(int index) async {
    final slug = _categories[index].slug;

    // Save current scroll position.
    if (_storyPageController.hasClients) {
      final currentSlug = _categories[_currentCategoryIndex].slug;
      _scrollPositions['way2news_${currentSlug ?? 'foryou'}'] =
          _storyPageController.position.pixels;
    }

    setState(() {
      _currentCategoryIndex = index;
      _currentStoryIndex = 0;
      _storyLoading = true;
      _error = null;
    });

    // Reset PageView to 0 before loading so there's no flash at old position.
    if (_storyPageController.hasClients) {
      _storyPageController.jumpToPage(0);
    }

    try {
      final news = context.read<NewsProvider>();
      List<NewsPost> posts;

      if (slug == null) {
        if (news.posts.isEmpty) await news.refresh();
        posts = List.from(news.posts);
      } else {
        final target = slug.toLowerCase();
        Category? cat;
        for (final c in news.categories) {
          if (c.slug.toLowerCase() == target) { cat = c; break; }
        }
        if (cat != null && news.selectedCategoryId != cat.id) {
          await news.selectCategory(cat.id);
        }
        posts = cat != null
            ? news.posts.where((p) => p.category?.id == cat!.id).toList()
            : <NewsPost>[];
      }

      if (mounted) {
        setState(() {
          _stories
            ..clear()
            ..addAll(posts);
          _storyLoading = false;
        });

        // Restore previous scroll position for this category.
        final storedPos = _scrollPositions[_categories[index].slug ?? 'way2news_foryou'];
        if (storedPos != null && storedPos > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_storyPageController.hasClients) {
              _storyPageController.jumpTo(storedPos);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _storyLoading = false;
          _error = e.toString().replaceFirst('Exception: ', '').trim();
        });
      }
    }
  }

  void _onStoryPageChanged(int index) {
    setState(() => _currentStoryIndex = index);
    HapticFeedback.lightImpact();
    _prefetchAdjacent(index);
  }

  void _prefetchAdjacent(int current) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memH = (size.height * dpr).round().clamp(600, 1400);

    for (final offset in [-1, 1]) {
      final idx = current + offset;
      if (idx < 0 || idx >= _stories.length) continue;
      final url = feedImageUrlForPost(_stories[idx]);
      if (url.isEmpty) continue;
      precacheImage(
        ResizeImage(CachedNetworkImageProvider(url), height: memH),
        context,
      );
    }
  }

    // Use shared utility for image selection logic

  // ── Actions ──────────────────────────────────────────────────────────────

  void _handleOpen(NewsPost post) {
    context.read<NewsProvider>().markPostAsSeen(post.id);
    HapticFeedback.selectionClick();
  }

  Future<void> _handleLike(NewsPost post) async {
    final id = post.id;
    final prev = _liked[id] ?? false;
    _liked[id] = !prev;
    if (mounted) setState(() {});

    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (!loggedIn) {
      final liked = await ApiService.toggleGuestLike(id);
      if (mounted) { _liked[id] = liked; setState(() {}); }
      return;
    }
    final res = await ApiService.toggleLike(id);
    if (!mounted) return;
    if (res['success'] != true) {
      _liked[id] = prev;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Could not update')),
      );
    } else {
      _liked[id] = res['liked'] == true;
    }
    setState(() {});
  }

  Future<void> _handleBookmark(NewsPost post) async {
    final id = post.id;
    final prev = _bookmarked[id] ?? false;
    _bookmarked[id] = !prev;
    if (mounted) setState(() {});

    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (!loggedIn) {
      final saved = await ApiService.toggleGuestBookmark(post);
      if (mounted) { _bookmarked[id] = saved; setState(() {}); }
      return;
    }
    final res = await ApiService.toggleBookmark(id);
    if (!mounted) return;
    if (res['success'] != true) {
      _bookmarked[id] = prev;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Could not save')),
      );
    } else {
      _bookmarked[id] = res['bookmarked'] == true;
    }
    setState(() {});
  }

  void _handleShare(NewsPost post) {
    PostShare.sharePost(post, context: context);
    HapticFeedback.lightImpact();
  }

  void _showMoreMenu(NewsPost post) {
    final fx = FeedXpressoTheme.fx(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: fx.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.share_rounded, color: fx.iconFg),
              title: Text('Share', style: TextStyle(color: fx.title)),
              onTap: () {
                Navigator.pop(ctx);
                _handleShare(post);
              },
            ),
            ListTile(
              leading: Icon(Icons.report_outlined, color: fx.actionMuted),
              title: Text('Report', style: TextStyle(color: fx.title)),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Main story PageView ─────────────────────────────────────────
          _buildStoryView(),

          // ── UI chrome (above story view, rendered on top) ──────────────
          _buildChrome(),

          // ── Story counter ──────────────────────────────────────────────
          if (!_storyLoading && _stories.isNotEmpty) _buildCounter(),
        ],
      ),
    );
  }

  Widget _buildStoryView() {
    final slug = _categories[_currentCategoryIndex].slug;

    if (_storyLoading) {
      return const StorySkeletonCard();
    }

    if (_stories.isEmpty) {
      return _buildEmptyState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return PageView.builder(
      key: _storyStorageKey(slug),
      controller: _storyPageController,
      scrollDirection: Axis.vertical,
      physics: const PageScrollPhysics(),
      onPageChanged: _onStoryPageChanged,
      itemCount: _stories.length,
      itemBuilder: (context, index) {
        final post = _stories[index];
        return AnimatedBuilder(
          animation: _storyPageController,
          builder: (context, child) {
            var page = _currentStoryIndex.toDouble();
            if (_storyPageController.hasClients &&
                _storyPageController.position.hasContentDimensions) {
              page = _storyPageController.page ?? page;
            }
            final delta = (page - index).clamp(-1.0, 1.0);
            return StoryPageCard(
              post: post,
              liked: _liked[post.id] ?? false,
              bookmarked: _bookmarked[post.id] ?? false,
              pageDelta: delta,
              onTap: () => _handleOpen(post),
              onLike: () => _handleLike(post),
              onBookmark: () => _handleBookmark(post),
              onShare: () => _handleShare(post),
              onMore: () => _showMoreMenu(post),
            );
          },
        );
      },
    );
  }

  Widget _buildChrome() {
    return _buildAppBar();
  }

  Widget _buildAppBar() {
    return Container(
      height: 56 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 20,
        right: 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.72),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          Text(
            AppConstants.appName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white70, size: 22),
            onPressed: () => context.push('/ai-chat'),
            tooltip: 'AI Chat',
          ),
        ],
      ),
    );
  }

  Widget _buildCounter() {
    return Positioned(
      right: 14,
      top: MediaQuery.of(context).padding.top + 52,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_currentStoryIndex + 1}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.1,
              ),
            ),
            Text(
              ' / ${_stories.length}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.5,
              ),
            ),
            child: Icon(
              Icons.article_outlined,
              size: 34,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No stories yet',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pull to refresh or try another category',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => _loadCategoryStories(_currentCategoryIndex),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => _loadCategoryStories(_currentCategoryIndex),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category config ───────────────────────────────────────────────────────────

class _CategoryConfig {
  const _CategoryConfig({
    required this.slug,
  });

  final String? slug;
}
