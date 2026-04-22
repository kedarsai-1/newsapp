import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/news_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../services/socket_service.dart';
import '../../models/models.dart';
import '../../widgets/news_card.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/news_shimmer_loader.dart';
import '../../constants.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_spacing.dart';
import '../../utils/i18n.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _refreshController = RefreshController(initialRefresh: false);
  final _scrollController = ScrollController();
  bool _showBanner = false;
  String? _bannerTitle;

  @override
  void initState() {
    super.initState();
    // Avoid triggering provider notifyListeners() during router's first build on web.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });

    _scrollController.addListener(() {
      final provider = context.read<NewsProvider>();
      // Load more slightly before reaching the end.
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 600) {
        if (!provider.loading && provider.hasMore) {
          provider.loadMore();
        }
      }
    });

    SocketService.connect();
    SocketService.onNewPost((data) {
      if (mounted) {
        setState(() {
          _showBanner = true;
          _bannerTitle = data['title'] as String?;
        });
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() => _showBanner = false);
        });
      }
    });
  }

  Future<void> _bootstrap() async {
    final p = context.read<NewsProvider>();
    // [NewsProvider.init] already ran at app start; do not call again here.
    // Avoid duplicate full refresh after language onboarding (which already refreshes).
    if (p.posts.isEmpty && !p.refreshing) {
      await p.refresh();
    }
  }

  @override
  void dispose() {
    _refreshController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsProvider>();
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.scaffoldBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Way2NewsTopBar(
                  onSearch: () => showSearch(
                    context: context,
                    delegate: FeedSearchDelegate(provider),
                  ),
                ),
                // Live update banner
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _showBanner ? 42 : 0,
                  child: _showBanner
                      ? GestureDetector(
                          onTap: () {
                            setState(() => _showBanner = false);
                            provider.refresh();
                            if (_scrollController.hasClients) {
                              _scrollController.animateTo(
                                0,
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOut,
                              );
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(AppSpacing.s12, 4, AppSpacing.s12, 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s12,
                              vertical: AppSpacing.s8,
                            ),
                            decoration: BoxDecoration(
                              color: p.breaking.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: p.breaking.withValues(alpha: 0.35)),
                            ),
                            child: Row(children: [
                              Icon(Icons.fiber_manual_record,
                                  size: 10, color: p.breaking),
                              const SizedBox(width: AppSpacing.s8),
                              Expanded(
                                child: Text(
                                  _bannerTitle != null
                                      ? 'New: $_bannerTitle'
                                      : 'New story published - tap to refresh',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: p.textSecondary,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ]),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s16, 2, AppSpacing.s16, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        I18n.t(context, 'feed_language'),
                        style: context.metaText.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: p.textHint,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      _FeedLanguageDropdown(
                        selectedCode: provider.selectedLanguage,
                        onChanged: (code) {
                          provider.selectLanguage(code);
                        },
                      ),
                    ],
                  ),
                ),

                if (provider.categoriesError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.s12, 4, AppSpacing.s12, AppSpacing.s8),
                    child: Material(
                      color: p.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => provider.loadCategories(),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: p.error, size: 20),
                              const SizedBox(width: AppSpacing.s8),
                              Expanded(
                                child: Text(
                                  provider.categoriesError!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: p.textSecondary,
                                      height: 1.35),
                                ),
                              ),
                              Text('Retry',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: p.primary,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                if (provider.categories.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.s16, 6, AppSpacing.s16, 0),
                    child: Row(
                      children: [
                        Text(
                          I18n.t(context, 'feed_categories'),
                          style: context.metaText.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: p.textHint,
                          ),
                        ),
                        const Spacer(),
                        if (provider.posts.isNotEmpty)
                          Text(
                            '${provider.posts.length} stories',
                            style: context.metaText.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: p.textHint.withValues(alpha: 0.85),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 46,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: 6,
                      ),
                      itemCount: provider.categories.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s8),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return CategoryChip(
                            label: I18n.t(context, 'feed_all'),
                            icon: '📰',
                            selected: provider.selectedCategoryId == null,
                            onTap: () => provider.selectCategory(null),
                          );
                        }
                        final cat = provider.categories[i - 1];
                        final localizedName = I18n.t(context, 'cat_${cat.slug.toLowerCase()}');
                        return CategoryChip(
                          label: localizedName == 'cat_${cat.slug.toLowerCase()}' ? cat.name : localizedName,
                          icon: cat.icon,
                          selected: provider.selectedCategoryId == cat.id,
                          onTap: () => provider.selectCategory(cat.id),
                        );
                      },
                    ),
                  ),
                ],

                Expanded(
                  child: provider.error != null
                      ? ErrorState(
                          message: provider.error!,
                          onRetry: provider.refresh)
                      : provider.posts.isEmpty
                          ? provider.refreshing
                              ? const NewsShimmerLoader(count: 6)
                              : EmptyState(
                                  icon: Icons.newspaper,
                                  title: I18n.t(context, 'feed_empty_title'),
                                  subtitle: I18n.t(context, 'feed_empty_subtitle'),
                                )
                          : SmartRefresher(
                              controller: _refreshController,
                              enablePullUp: provider.hasMore,
                              header: WaterDropMaterialHeader(
                                color: p.primary,
                                backgroundColor: p.surface,
                              ),
                              footer: CustomFooter(
                                builder: (context, mode) {
                                  if (!provider.hasMore) {
                                    return const SizedBox(height: 24);
                                  }
                                  return SizedBox(
                                    height: 56,
                                    child: Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: p.accentGreen,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              onRefresh: () {
                                final news = context.read<NewsProvider>();
                                news.refresh().then((_) {
                                  if (!mounted) return;
                                  if (news.error != null) {
                                    _refreshController.refreshFailed();
                                  } else {
                                    _refreshController.refreshCompleted();
                                  }
                                });
                              },
                              onLoading: () {
                                final news = context.read<NewsProvider>();
                                news.loadMore().then((_) {
                                  if (!mounted) return;
                                  _refreshController.loadComplete();
                                });
                              },
                              child: ListView.builder(
                                controller: _scrollController,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                                itemCount: provider.posts.length +
                                    (provider.hasMore ? 1 : 0),
                                itemBuilder: (_, i) {
                                  if (i >= provider.posts.length) {
                                    // Bottom loader spacer; real loader is in footer.
                                    return const SizedBox(height: AppSpacing.s8);
                                  }
                                  return NewsCard(
                                    post: provider.posts[i],
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Way2NewsTopBar extends StatelessWidget {
  final VoidCallback onSearch;
  const _Way2NewsTopBar({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Material(
      color: p.scaffoldBackground,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s12,
          AppSpacing.s16,
          AppSpacing.s12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NewsNow',
                    style: (t.headlineSmall ?? t.titleLarge)?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      height: 1.05,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    'Top headlines for you',
                    style: t.labelMedium?.copyWith(
                      color: p.textHint,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onSearch,
              icon: Icon(Icons.search_rounded, color: p.textPrimary),
              tooltip: 'Search',
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryReaderPage extends StatefulWidget {
  final NewsPost post;
  final int index;
  final int total;
  final PageController pageController;
  const _StoryReaderPage({
    required this.post,
    required this.index,
    required this.total,
    required this.pageController,
  });

  @override
  State<_StoryReaderPage> createState() => _StoryReaderPageState();
}

class _StoryReaderPageState extends State<_StoryReaderPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  late Animation<double> _imgScale;

  NewsPost get post => widget.post;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _slide =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
    _imgScale = Tween<double>(begin: 1.08, end: 1.0).animate(
      CurvedAnimation(
          parent: _anim,
          curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic)),
    );
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _quickLike() async {
    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (loggedIn) {
      final res = await ApiService.toggleLike(post.id);
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['liked'] == true
                  ? 'Thanks for the like!'
                  : 'Like removed',
            ),
            duration: const Duration(milliseconds: 1400),
          ),
        );
      }
    } else {
      await ApiService.toggleGuestLike(post.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to your likes on this device'),
          duration: Duration(milliseconds: 1400),
        ),
      );
    }
  }

  Future<void> _shareToWhatsApp(BuildContext context) async {
    final shareText = [
      post.title,
      '',
      post.summary?.trim().isNotEmpty == true ? post.summary! : post.body,
      if (post.sourceUrl != null && post.sourceUrl!.isNotEmpty) '',
      if (post.sourceUrl != null && post.sourceUrl!.isNotEmpty) post.sourceUrl!,
      '',
      'Shared via ${AppConstants.appName}'
    ].join('\n');

    final encoded = Uri.encodeComponent(shareText);
    final whatsappUri = Uri.parse('https://wa.me/?text=$encoded');
    final launched =
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp not available on this device')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final rawUrl = post.firstImage?.url;
    final imageUrl = rawUrl != null && rawUrl.trim().isNotEmpty
        ? AppConstants.imageUrlForDisplay(rawUrl, articleReferer: post.sourceUrl)
        : '';
    final timeLabel = timeago.format(post.createdAt, allowFromNow: true);
    final badge = post.sourceName?.trim().isNotEmpty == true
        ? post.sourceName!
        : (post.category?.name ?? '');

    return GestureDetector(
      onTap: () => context.push('/article/${post.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
        child: Column(
          children: [
            Expanded(
              flex: 46,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ScaleTransition(
                      scale: _imgScale,
                      child: AnimatedBuilder(
                        animation: widget.pageController,
                        builder: (context, child) {
                          var delta = 0.0;
                          final pc = widget.pageController;
                          if (pc.hasClients) {
                            delta =
                                (pc.page ?? widget.index.toDouble()) -
                                    widget.index;
                          }
                          delta = delta.clamp(-1.0, 1.0);
                          return Transform.translate(
                            offset: Offset(0, delta * 20),
                            child: Transform.scale(
                              scale: 1.0 + (1.0 - delta.abs()) * 0.035,
                              alignment: Alignment.center,
                              child: child,
                            ),
                          );
                        },
                        child: GestureDetector(
                          onDoubleTap: _quickLike,
                          behavior: HitTestBehavior.opaque,
                          child: imageUrl.isNotEmpty
                              ? Hero(
                                  tag: 'post-hero-${post.id}',
                                  child: Material(
                                    type: MaterialType.transparency,
                                    child: CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      memCacheWidth: 1200,
                                      fadeInDuration: const Duration(
                                          milliseconds: 280),
                                      fadeInCurve: Curves.easeOut,
                                      placeholder: (_, __) => Container(
                                        color: p.inputFill,
                                        alignment: Alignment.center,
                                        child: SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: p.primary),
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        color: p.inputFill,
                                        alignment: Alignment.center,
                                        child: Icon(
                                            Icons.image_not_supported_outlined,
                                            color: p.textHint,
                                            size: 52),
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: p.inputFill,
                                  alignment: Alignment.center,
                                  child: Icon(Icons.article_outlined,
                                      color: p.textHint, size: 56),
                                ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 100,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.55),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (badge.isNotEmpty)
                      Positioned(
                        left: 14,
                        bottom: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            badge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              flex: 54,
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: const BorderRadius.all(Radius.circular(24)),
                      border: Border.all(
                          color: p.cardBorder.withValues(alpha: 0.65)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: p.textHint.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.title,
                                  style: t.headlineSmall?.copyWith(
                                    height: 1.22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                    color: p.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  post.body,
                                  maxLines: 8,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.bodyLarge?.copyWith(
                                    height: 1.55,
                                    color: p.textSecondary,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      'Tap to read full story',
                                      style: t.labelLarge?.copyWith(
                                        color: p.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.arrow_forward_rounded,
                                        size: 18, color: p.primary),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                          decoration: BoxDecoration(
                            border: Border(
                                top: BorderSide(
                                    color:
                                        p.cardBorder.withValues(alpha: 0.5))),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.schedule_rounded,
                                  size: 16, color: p.textHint),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  timeLabel,
                                  style: t.labelSmall?.copyWith(
                                      color: p.textHint,
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: p.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${widget.index + 1} / ${widget.total}',
                                  style: t.labelSmall?.copyWith(
                                    color: p.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _ActionIcon(
                                  icon: Icons.favorite_border_rounded,
                                  label: '${post.likes}'),
                              const SizedBox(width: 8),
                              _ActionIcon(
                                icon: Icons.chat_rounded,
                                label: 'Share',
                                iconColor: const Color(0xFF25D366),
                                labelColor: const Color(0xFF25D366),
                                onTap: () => _shareToWhatsApp(context),
                              ),
                            ],
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
      ),
    );
  }
}

class _FeedLanguageDropdown extends StatelessWidget {
  final String selectedCode;
  final void Function(String code) onChanged;

  const _FeedLanguageDropdown({
    required this.selectedCode,
    required this.onChanged,
  });

  static const _codes = ['all', 'en', 'te', 'hi'];

  static String _label(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'te':
        return 'Telugu';
      case 'hi':
        return 'Hindi';
      case 'all':
      default:
        return 'All';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final value =
        _codes.contains(selectedCode) ? selectedCode : 'all';
    return SizedBox(
      height: 48,
      child: PopupMenuButton<String>(
        initialValue: value,
        tooltip: 'Select language',
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: onChanged,
        itemBuilder: (context) => _codes.map((code) {
          final selected = code == value;
          return PopupMenuItem<String>(
            value: code,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _label(code),
                    style: TextStyle(
                      color: p.textPrimary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                if (selected) Icon(Icons.check_rounded, size: 18, color: p.primary),
              ],
            ),
          );
        }).toList(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.primary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: p.primary.withValues(alpha: 0.22),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _label(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white.withValues(alpha: 0.95),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? labelColor;
  const _ActionIcon({
    required this.icon,
    required this.label,
    this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ic = iconColor ?? p.textSecondary;
    final lc = labelColor ?? p.textSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: ic),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 12, color: lc)),
        ],
      ),
    );
  }
}

class FeedSearchDelegate extends SearchDelegate<String> {
  final NewsProvider provider;
  FeedSearchDelegate(this.provider);

  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
          border: InputBorder.none,
          hintStyle: TextStyle(color: context.palette.textHint),
        ),
      );

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
            icon: Icon(Icons.clear, color: context.palette.textSecondary),
            onPressed: () => query = '')
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
      icon: Icon(Icons.arrow_back_ios_new_rounded,
          size: 18, color: context.palette.textSecondary),
      onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) =>
      _FeedSearchResults(query: query, provider: provider);

  @override
  Widget buildSuggestions(BuildContext context) => query.isEmpty
      ? Center(
          child: Text('Search for news...',
              style: TextStyle(color: context.palette.textHint)))
      : _FeedSearchResults(query: query, provider: provider);
}

class _FeedSearchResults extends StatefulWidget {
  final String query;
  final NewsProvider provider;
  const _FeedSearchResults({required this.query, required this.provider});
  @override
  State<_FeedSearchResults> createState() => _FeedSearchResultsState();
}

class _FeedSearchResultsState extends State<_FeedSearchResults> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void didUpdateWidget(_FeedSearchResults old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _search();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    await widget.provider.search(widget.query);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(color: context.palette.accentGreen));
    }
    final posts = widget.provider.posts;
    if (posts.isEmpty) {
      return const EmptyState(
          icon: Icons.search_off, title: 'No results found');
    }
    return ListView.builder(
        itemCount: posts.length,
        itemBuilder: (_, i) => NewsCard(
              post: posts[i],
            ));
  }
}

/// Opens feed search with the shared [NewsProvider] delegate.
void openFeedSearch(BuildContext context) {
  final provider = context.read<NewsProvider>();
  showSearch(context: context, delegate: FeedSearchDelegate(provider));
}
