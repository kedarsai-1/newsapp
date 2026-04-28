import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';
import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/news_shimmer_loader.dart';
import '../../widgets/premium_news_ui.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;
  final Map<String, String?> _translatedByPostId = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<NewsProvider>();
      if (provider.posts.isEmpty && !provider.refreshing) provider.refresh();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _maybeLoadMore(int index) {
    final provider = context.read<NewsProvider>();
    if (index >= provider.posts.length - 3 &&
        provider.hasMore &&
        !provider.loading) {
      provider.loadMore();
    }
  }

  Future<void> _openArticleSheet(NewsPost post) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ArticlePreviewSheet(post: post),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsProvider>();
    final p = context.palette;

    return PremiumScaffold(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (provider.error != null)
            SafeArea(
              child: ErrorState(
                message: provider.error!,
                onRetry: provider.refresh,
              ),
            )
          else if (provider.posts.isEmpty && provider.refreshing)
            const SafeArea(child: NewsShimmerLoader(count: 5))
          else if (provider.posts.isEmpty)
            const SafeArea(
              child: EmptyState(
                icon: AppIcons.categories,
                title: 'No stories yet',
                subtitle: 'Pull down or adjust filters to load fresh news.',
              ),
            )
          else
            RefreshIndicator(
              color: p.primary,
              backgroundColor: p.surface,
              onRefresh: provider.refresh,
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(),
                itemCount: provider.posts.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                  _maybeLoadMore(index);
                },
                itemBuilder: (context, index) {
                  return RepaintBoundary(
                    child: _NewsReelCard(
                      post: provider.posts[index],
                      index: index,
                      total: provider.posts.length,
                      controller: _pageController,
                      initialTranslatedSummary:
                          _translatedByPostId[provider.posts[index].id],
                      onTranslatedSummaryChanged: (value) {
                        if (!mounted) return;
                        setState(() {
                          _translatedByPostId[provider.posts[index].id] = value;
                        });
                      },
                      onReadMore: () =>
                          _openArticleSheet(provider.posts[index]),
                    ),
                  );
                },
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      PremiumIconButton(
                        icon: AppIcons.profile,
                        onTap: () => context.push('/settings'),
                      ),
                      FrostedPanel(
                        radius: 18,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        color: Colors.black.withValues(alpha: 0.22),
                        boxShadow: const [],
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppIcons.home,
                              size: 18,
                              color: p.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppConstants.appName,
                              style: TextStyle(
                                color: p.textPrimary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PremiumIconButton(
                        icon: AppIcons.notification,
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No new notifications'),
                            duration: Duration(milliseconds: 1200),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (provider.posts.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
              child: StoryProgressDots(
                total: provider.posts.length,
                index: _currentIndex,
              ),
            ),
        ],
      ),
    );
  }
}

class _NewsReelCard extends StatefulWidget {
  final NewsPost post;
  final int index;
  final int total;
  final PageController controller;
  final String? initialTranslatedSummary;
  final ValueChanged<String?> onTranslatedSummaryChanged;
  final VoidCallback onReadMore;

  const _NewsReelCard({
    required this.post,
    required this.index,
    required this.total,
    required this.controller,
    required this.initialTranslatedSummary,
    required this.onTranslatedSummaryChanged,
    required this.onReadMore,
  });

  @override
  State<_NewsReelCard> createState() => _NewsReelCardState();
}

class _NewsReelCardState extends State<_NewsReelCard>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final AnimationController _likePop;
  late final AnimationController _savePop;
  final FlutterTts _tts = FlutterTts();
  bool _liked = false;
  bool _saved = false;
  bool _likeSyncing = false;
  bool _translating = false;
  String? _translatedSummary;

  NewsPost get post => widget.post;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    )..forward();
    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic));
    _likePop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _savePop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _translatedSummary = widget.initialTranslatedSummary;
    _configureTts();
    _hydrateInteractionState();
  }

  @override
  void didUpdateWidget(covariant _NewsReelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _translatedSummary = widget.initialTranslatedSummary;
      _hydrateInteractionState();
      return;
    }
    if (oldWidget.initialTranslatedSummary != widget.initialTranslatedSummary &&
        widget.initialTranslatedSummary != _translatedSummary) {
      _translatedSummary = widget.initialTranslatedSummary;
    }
  }

  Future<void> _configureTts() async {
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  Future<void> _hydrateInteractionState() async {
    final liked = await ApiService.isGuestLiked(post.id);
    final saved = await ApiService.isGuestBookmarked(post.id);
    if (!mounted) return;
    setState(() {
      _liked = liked;
      _saved = saved;
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _likePop.dispose();
    _savePop.dispose();
    _entry.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_likeSyncing) return;
    setState(() => _likeSyncing = true);
    final liked = await ApiService.toggleGuestLike(post.id);
    if (!mounted) return;
    setState(() {
      _liked = liked;
      _likeSyncing = false;
    });
    _likePop.forward(from: 0);
  }

  Future<void> _toggleSave() async {
    final saved = await ApiService.toggleGuestBookmark(post);
    if (mounted) {
      setState(() => _saved = saved);
      _savePop.forward(from: 0);
    }
  }

  Future<void> _share() async {
    final text = '${post.title}\n\n${premiumSnippet(post, maxLength: 260)}';
    await Share.share(text, subject: post.title);
  }

  Future<void> _translate() async {
    if (_translating) return;
    if (_translatedSummary != null) {
      setState(() => _translatedSummary = null);
      widget.onTranslatedSummaryChanged(null);
      return;
    }
    setState(() => _translating = true);
    final lang = context.read<NewsProvider>().selectedLanguage;
    final target = lang == 'all' ? 'te' : lang;
    final res = await ApiService.translateText(
      text: premiumSnippet(post, maxLength: 220),
      targetLanguage: target,
    );
    if (!mounted) return;
    setState(() {
      _translating = false;
      if (res['success'] == true) {
        _translatedSummary = res['translatedText']?.toString().trim();
        widget.onTranslatedSummaryChanged(_translatedSummary);
      }
    });
  }

  Future<void> _speak() async {
    await _tts.stop();
    await _tts.speak('${post.title}. ${premiumSnippet(post, maxLength: 220)}');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final imageUrl = premiumImageUrl(post);

    return GestureDetector(
      onTap: widget.onReadMore,
      onDoubleTap: _toggleLike,
      onLongPress: _speak,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: widget.controller,
            builder: (context, child) {
              var delta = 0.0;
              if (widget.controller.hasClients) {
                delta = (widget.controller.page ?? widget.index.toDouble()) -
                    widget.index;
              }
              delta = delta.clamp(-1.0, 1.0);
              return Transform.scale(
                scale: 1.04 - (delta.abs() * 0.04),
                child: Transform.translate(
                  offset: Offset(0, delta * 18),
                  child: child,
                ),
              );
            },
            child: imageUrl.isEmpty
                ? Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [p.gradientStart, p.gradientMid, p.gradientEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  )
                : Hero(
                    tag: 'post-hero-${post.id}',
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 1200,
                      fadeInDuration: const Duration(milliseconds: 240),
                      placeholder: (_, __) => ColoredBox(color: p.inputFill),
                      errorWidget: (_, __, ___) => ColoredBox(
                        color: p.inputFill,
                        child: Icon(Icons.image_not_supported_outlined,
                            color: p.textHint),
                      ),
                    ),
                  ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.52),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.36),
                  Colors.black.withValues(alpha: 0.92),
                ],
                stops: const [0, 0.34, 0.58, 1],
              ),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 132,
            child: Column(
              children: [
                PremiumIconButton(
                  icon: _liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: '${post.likes + (_liked ? 1 : 0)}',
                  color: _liked ? Colors.redAccent : null,
                  onTap: _toggleLike,
                  scale: Tween<double>(begin: 1, end: 1.2).animate(
                    CurvedAnimation(parent: _likePop, curve: Curves.elasticOut),
                  ),
                ),
                const SizedBox(height: 12),
                PremiumIconButton(
                  icon: _saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  label: 'Save',
                  color: _saved ? p.primary : null,
                  onTap: _toggleSave,
                  scale: Tween<double>(begin: 1, end: 1.16).animate(
                    CurvedAnimation(parent: _savePop, curve: Curves.elasticOut),
                  ),
                ),
                const SizedBox(height: 12),
                PremiumIconButton(
                  icon: AppIcons.share,
                  label: 'Share',
                  onTap: _share,
                ),
                const SizedBox(height: 12),
                PremiumIconButton(
                  icon: AppIcons.translate,
                  label: _translating
                      ? '...'
                      : (_translatedSummary == null ? 'Translate' : 'Original'),
                  onTap: _translate,
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 78,
            bottom: 100,
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: FrostedPanel(
                  radius: 22,
                  padding: const EdgeInsets.all(16),
                  color: Colors.black.withValues(alpha: 0.28),
                  boxShadow: const [],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _translatedSummary ??
                            premiumSnippet(post, maxLength: 170),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${post.sourceName ?? post.category?.name ?? 'News'} • ${timeago.format(post.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.metaText.copyWith(
                          color: Colors.white.withValues(alpha: 0.76),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _MetaPill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MetaPill({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticlePreviewSheet extends StatelessWidget {
  final NewsPost post;

  const _ArticlePreviewSheet({required this.post});

  @override
  Widget build(BuildContext context) => _ArticlePreviewSheetBody(post: post);
}

class _ArticlePreviewSheetBody extends StatefulWidget {
  final NewsPost post;

  const _ArticlePreviewSheetBody({required this.post});

  @override
  State<_ArticlePreviewSheetBody> createState() =>
      _ArticlePreviewSheetBodyState();
}

class _ArticlePreviewSheetBodyState extends State<_ArticlePreviewSheetBody> {
  final FlutterTts _tts = FlutterTts();
  bool _translated = false;
  bool _translating = false;
  String? _translatedText;
  bool _speaking = false;

  NewsPost get post => widget.post;

  String get _summary {
    final base = post.summary?.trim().isNotEmpty == true
        ? post.summary!.trim()
        : premiumSnippet(post, maxLength: 1200);
    if (_translated && _translatedText != null && _translatedText!.isNotEmpty) {
      return _translatedText!;
    }
    return base;
  }

  Future<void> _toggleSpeak() async {
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.0);
    await _tts.speak('${post.title}. $_summary');
    if (mounted) setState(() => _speaking = true);
  }

  Future<void> _openSource() async {
    final raw = post.sourceUrl?.trim();
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open source link')),
      );
    }
  }

  Future<void> _share() async {
    await Share.share(
      '${post.title}\n\n$_summary\n\n${post.sourceUrl ?? ''}',
      subject: post.title,
    );
  }

  Future<void> _toggleTranslation() async {
    if (_translating) return;
    if (_translated) {
      setState(() => _translated = false);
      return;
    }
    setState(() => _translating = true);
    final target = context.read<NewsProvider>().selectedLanguage == 'all'
        ? 'te'
        : context.read<NewsProvider>().selectedLanguage;
    final res = await ApiService.translateText(
      text: _summary,
      targetLanguage: target,
    );
    if (!mounted) return;
    setState(() {
      _translating = false;
      if (res['success'] == true) {
        _translatedText = res['translatedText']?.toString();
        _translated = true;
      }
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottom = MediaQuery.of(context).padding.bottom;
    final imageUrl = premiumImageUrl(post);
    return FrostedPanel(
      radius: 30,
      margin: const EdgeInsets.all(10),
      padding: EdgeInsets.fromLTRB(12, 10, 12, 12 + bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.50,
        maxChildSize: 0.98,
        builder: (context, controller) {
          return ListView(
            controller: controller,
            physics: const BouncingScrollPhysics(),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.textHint.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: imageUrl.isEmpty
                      ? ColoredBox(
                          color: p.inputFill,
                          child: Icon(
                            Icons.article_outlined,
                            color: p.textHint,
                            size: 42,
                          ),
                        )
                      : Hero(
                          tag: 'post-hero-${post.id}',
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                ColoredBox(color: p.inputFill),
                            errorWidget: (_, __, ___) => ColoredBox(
                              color: p.inputFill,
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: p.textHint,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                post.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w900,
                      height: 1.18,
                      letterSpacing: -0.6,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaPill(
                    label: post.category?.name ?? 'Article',
                    icon: Icons.grid_view_rounded,
                  ),
                  _MetaPill(
                    label: timeago.format(post.createdAt),
                    icon: Icons.schedule_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GradientPillButton(
                      label: _speaking ? 'Stop TTS' : 'Listen',
                      icon: _speaking
                          ? Icons.stop_rounded
                          : Icons.volume_up_rounded,
                      compact: true,
                      onPressed: _toggleSpeak,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GradientPillButton(
                      label: _translating
                          ? '...'
                          : (_translated ? 'Original' : 'Translate'),
                      icon: AppIcons.translate,
                      compact: true,
                      onPressed: _toggleTranslation,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GradientPillButton(
                      label: 'Share',
                      icon: AppIcons.share,
                      compact: true,
                      onPressed: _share,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                _summary,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: p.textSecondary,
                      height: 1.72,
                    ),
              ),
              const SizedBox(height: 16),
              if ((post.sourceUrl ?? '').trim().isNotEmpty)
                InkWell(
                  onTap: _openSource,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.link_rounded, color: p.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            post.sourceUrl!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.metaText.copyWith(
                              color: p.primary,
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        Icon(Icons.open_in_new_rounded,
                            color: p.primary, size: 16),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              GradientPillButton(
                label: 'Open full article',
                icon: Icons.open_in_full_rounded,
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/article/${post.id}');
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class FeedSearchDelegate extends SearchDelegate<String> {
  final NewsProvider provider;

  FeedSearchDelegate(this.provider);

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear_rounded),
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, ''),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
      );

  @override
  Widget buildResults(BuildContext context) =>
      _SearchResults(provider: provider, query: query);

  @override
  Widget buildSuggestions(BuildContext context) => query.isEmpty
      ? const Center(child: Text('Search news, topics, places...'))
      : _SearchResults(provider: provider, query: query);
}

class _SearchResults extends StatefulWidget {
  final NewsProvider provider;
  final String query;

  const _SearchResults({required this.provider, required this.query});

  @override
  State<_SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends State<_SearchResults> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void didUpdateWidget(covariant _SearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _run();
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    await widget.provider.search(widget.query);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (widget.provider.posts.isEmpty) {
      return const EmptyState(icon: Icons.search_off, title: 'No results');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.provider.posts.length,
      itemBuilder: (context, index) => PremiumNewsTile(
        post: widget.provider.posts[index],
        onTap: () =>
            context.push('/article/${widget.provider.posts[index].id}'),
      ),
    );
  }
}

void openFeedSearch(BuildContext context) {
  final provider = context.read<NewsProvider>();
  showSearch(context: context, delegate: FeedSearchDelegate(provider));
}
