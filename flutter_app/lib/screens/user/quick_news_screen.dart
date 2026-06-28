import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../constants.dart';
import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../../utils/i18n.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/premium_news_ui.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';
import '../../utils/feed_image_url.dart';

class QuickNewsScreen extends StatefulWidget {
  const QuickNewsScreen({super.key});

  @override
  State<QuickNewsScreen> createState() => _QuickNewsScreenState();
}

class _QuickNewsScreenState extends State<QuickNewsScreen> {
  late final PageController _pageController;
  int _index = 0;
  bool _quickMode = true;

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/feed');
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NewsProvider>().loadBreakingFeed();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openPreview(NewsPost post) async {
    final p = context.palette;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FrostedPanel(
        radius: 26,
        margin: const EdgeInsets.all(10),
        padding: EdgeInsets.fromLTRB(
          18,
          16,
          18,
          18 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              premiumSnippet(post, maxLength: 420),
              style: context.subtitleText.copyWith(
                color: p.textSecondary,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 16),
            GradientPillButton(
              label: I18n.t(context, 'quick_news_open_full'),
              icon: AppIcons.share,
              onPressed: () {
                Navigator.pop(context);
                context.push('/article/${post.id}');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsProvider>();
    final p = context.palette;
    final posts = provider.breakingPosts;
    final loading = provider.breakingLoading;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: PremiumScaffold(
      safeArea: true,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  PremiumIconButton(
                    icon: AppIcons.back,
                    onTap: _handleBack,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          I18n.t(context, 'menu_quick_news'),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: p.textPrimary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.7,
                              ),
                        ),
                        Text(
                          I18n.t(context, 'quick_news_subtitle'),
                          style: context.subtitleText.copyWith(
                            color: p.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FrostedPanel(
                    radius: 14,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    color: p.textPrimary.withValues(alpha: 0.08),
                    boxShadow: const [],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ModeChip(
                          label: I18n.t(context, 'quick_news_mode_quick'),
                          selected: _quickMode,
                          onTap: () => setState(() => _quickMode = true),
                        ),
                        const SizedBox(width: 4),
                        _ModeChip(
                          label: I18n.t(context, 'quick_news_mode_full'),
                          selected: !_quickMode,
                          onTap: () {
                            setState(() => _quickMode = false);
                            context.go('/feed');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (posts.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                icon: AppIcons.alert,
                title: I18n.t(context, 'quick_news_empty_title'),
                subtitle: provider.breakingError ??
                    I18n.t(context, 'quick_news_empty_subtitle'),
                buttonLabel: I18n.t(context, 'action_retry'),
                onButtonTap: () => provider.loadBreakingFeed(),
              ),
            )
          else if (_quickMode)
            SliverPadding(
              padding: EdgeInsets.only(
                top: 14,
                bottom: 98 + MediaQuery.of(context).padding.bottom,
              ),
              sliver: SliverFillRemaining(
                child: Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        scrollDirection: Axis.horizontal,
                        onPageChanged: (value) =>
                            setState(() => _index = value),
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return AnimatedPadding(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.fromLTRB(
                              6,
                              index == _index ? 2 : 10,
                              6,
                              index == _index ? 2 : 10,
                            ),
                            child: _QuickHeadlineCard(
                              post: post,
                              index: index,
                              total: posts.length,
                              onTap: () => _openPreview(post),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    StoryProgressDots(total: posts.length, index: _index),
                  ],
                ),
              ),
            )
          else
            SliverFillRemaining(
              child: Center(
                child: GradientPillButton(
                  label: I18n.t(context, 'quick_news_switching_full'),
                  icon: AppIcons.home,
                  onPressed: () => context.go('/feed'),
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }
}

class _QuickHeadlineCard extends StatelessWidget {
  final NewsPost post;
  final int index;
  final int total;
  final VoidCallback onTap;

  const _QuickHeadlineCard({
    required this.post,
    required this.index,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fx = context.fx;
    final imageUrl = feedImageUrlForPost(post);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = (MediaQuery.sizeOf(context).width * dpr).round().clamp(480, 1400);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: fx.heroOverlayBorder),
            boxShadow: [
              BoxShadow(
                color: fx.heroShadow,
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    memCacheWidth: memW,
                    placeholder: (_, __) => ColoredBox(
                      color: p.inputFill,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p.primary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => _QuickImageFallback(p: p),
                  )
                else
                  _QuickImageFallback(p: p),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          fx.overlayScrim.withValues(alpha: 0.72),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: p.primary.withValues(alpha: 0.9),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: fx.onImage,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            post.category?.name ?? 'Headline',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.metaText.copyWith(
                              color: fx.onImage,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${index + 1}/$total',
                          style: context.metaText.copyWith(
                            color: fx.onImage.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          fx.overlayScrim.withValues(alpha: 0.55),
                          fx.overlayScrim.withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          post.title,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: context.titleText.copyWith(
                            color: fx.onImage,
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            height: 1.22,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${post.displaySourceName} • ${timeago.format(post.displayTime)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.metaText.copyWith(
                            color: fx.onImage.withValues(alpha: 0.88),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          I18n.t(context, 'quick_news_tap_expand'),
                          style: context.metaText.copyWith(
                            color: p.primary.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickImageFallback extends StatelessWidget {
  final AppPalette p;

  const _QuickImageFallback({required this.p});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: p.inputFill,
      child: Center(
        child: Icon(
          AppIcons.image,
          size: 48,
          color: p.textHint.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color:
              selected ? p.primary.withValues(alpha: 0.2) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? p.primary : p.textSecondary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
