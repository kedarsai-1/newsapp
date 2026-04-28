import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../constants.dart';
import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/premium_news_ui.dart';

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
              label: 'Open full news',
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
    final posts = provider.posts.take(12).toList();

    return PremiumScaffold(
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
                          'Quick News',
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
                          'Ultra-fast headline mode',
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
                    color: Colors.black.withValues(alpha: 0.24),
                    boxShadow: const [],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ModeChip(
                          label: 'Quick',
                          selected: _quickMode,
                          onTap: () => setState(() => _quickMode = true),
                        ),
                        const SizedBox(width: 4),
                        _ModeChip(
                          label: 'Full',
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
          if (posts.isEmpty)
            const SliverFillRemaining(
              child: EmptyState(
                icon: AppIcons.alert,
                title: 'No quick briefs yet',
                subtitle: 'Refresh the feed and try again.',
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
                  label: 'Switching to full mode...',
                  icon: AppIcons.home,
                  onPressed: () => context.go('/feed'),
                ),
              ),
            ),
        ],
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
    final thumb = premiumImageUrl(post);
    return FrostedPanel(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: p.primary.withValues(alpha: 0.16),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: p.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    post.category?.name ?? 'Headline',
                    style: context.metaText.copyWith(
                      color: p.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${index + 1}/$total',
                  style: context.metaText.copyWith(color: p.textHint),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (thumb.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: CachedNetworkImage(
                        imageUrl: thumb,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        memCacheWidth: 420,
                        placeholder: (_, __) => ColoredBox(color: p.inputFill),
                        errorWidget: (_, __, ___) =>
                            Icon(AppIcons.image, color: p.textHint),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.titleText.copyWith(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      height: 1.2,
                      shadows: const [
                        Shadow(
                          color: Color(0x77000000),
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${post.sourceName ?? post.category?.name ?? 'News'} • ${timeago.format(post.createdAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.metaText.copyWith(
                color: p.textHint,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to expand',
              style: context.metaText.copyWith(
                color: p.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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
