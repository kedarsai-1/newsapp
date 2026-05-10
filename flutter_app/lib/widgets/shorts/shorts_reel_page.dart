import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../constants.dart';
import '../../models/models.dart';
import '../premium_news_ui.dart';

/// One full-screen Shorts card: media, dark gradient, copy, glass action rail.
class ShortsReelPage extends StatelessWidget {
  final NewsPost post;
  final PageController pageController;
  final int pageIndex;
  final bool liked;
  final bool saved;
  final String? translatedSummary;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onTranslate;
  final VoidCallback onOpenArticle;

  const ShortsReelPage({
    super.key,
    required this.post,
    required this.pageController,
    required this.pageIndex,
    required this.liked,
    required this.saved,
    this.translatedSummary,
    required this.onLike,
    required this.onSave,
    required this.onShare,
    required this.onTranslate,
    required this.onOpenArticle,
  });

  String _snippet() {
    if (translatedSummary != null && translatedSummary!.trim().isNotEmpty) {
      return translatedSummary!.trim();
    }
    return premiumSnippet(post, maxLength: 200);
  }

  String _sourceLine() {
    final src = (post.sourceName?.trim().isNotEmpty == true)
        ? post.sourceName!.trim()
        : (post.category?.name ?? 'News');
    return '$src • ${timeago.format(post.createdAt)}';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = premiumImageUrl(post);
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final widthPx = MediaQuery.of(context).size.width * dpr;
    final memW = widthPx.clamp(1080, 2400).round();
    final t = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onOpenArticle,
      behavior: HitTestBehavior.deferToChild,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: pageController,
            builder: (context, child) {
              double delta = 0;
              if (pageController.hasClients) {
                delta = (pageController.page ?? pageIndex.toDouble()) -
                    pageIndex;
              }
              delta = delta.clamp(-1.0, 1.0);
              return Transform.scale(
                scale: 1.03 - (delta.abs() * 0.03),
                child: Transform.translate(
                  offset: Offset(0, delta * 14),
                  child: child,
                ),
              );
            },
            child: imageUrl.isEmpty
                ? ColoredBox(
                    color: const Color(0xFF1A1A1A),
                    child: Center(
                      child: Icon(
                        Icons.article_outlined,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  )
                : Hero(
                    tag: 'post-hero-${post.id}',
                    child: Material(
                      type: MaterialType.transparency,
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        memCacheWidth: kIsWeb ? null : memW,
                        fadeInDuration: const Duration(milliseconds: 240),
                        placeholder: (_, __) => const ColoredBox(
                          color: Color(0xFF0D0D0D),
                          child: Center(
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF34D399),
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => ColoredBox(
                          color: const Color(0xFF151515),
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.white.withValues(alpha: 0.4),
                            size: 56,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          // Dark gradient for title readability (Dailyhunt Shorts style).
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000),
                  Color(0x22000000),
                  Color(0x66000000),
                  Color(0xD9000000),
                ],
                stops: [0.0, 0.28, 0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            right: 10,
            bottom: 200,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PremiumIconButton(
                  icon: liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: null,
                  color: liked ? Colors.redAccent : Colors.white,
                  labelColor: Colors.white.withValues(alpha: 0.92),
                  panelColor: Colors.black.withValues(alpha: 0.50),
                  circular: true,
                  onTap: onLike,
                ),
                const SizedBox(height: 18),
                PremiumIconButton(
                  icon: saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  label: 'Save',
                  color: saved ? context.palette.primary : Colors.white,
                  labelColor: Colors.white.withValues(alpha: 0.92),
                  panelColor: Colors.black.withValues(alpha: 0.50),
                  circular: true,
                  onTap: onSave,
                ),
                const SizedBox(height: 14),
                PremiumIconButton(
                  icon: AppIcons.share,
                  label: 'Share',
                  color: Colors.white,
                  labelColor: Colors.white.withValues(alpha: 0.92),
                  panelColor: Colors.black.withValues(alpha: 0.50),
                  circular: true,
                  onTap: onShare,
                ),
                const SizedBox(height: 14),
                PremiumIconButton(
                  icon: AppIcons.translate,
                  label: translatedSummary == null ? 'Translate' : 'Original',
                  color: Colors.white,
                  labelColor: Colors.white.withValues(alpha: 0.92),
                  panelColor: Colors.black.withValues(alpha: 0.50),
                  circular: true,
                  onTap: onTranslate,
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 108,
            bottom: 108,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  post.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                    fontSize: 22,
                    letterSpacing: -0.5,
                    shadows: const [
                      Shadow(
                        color: Color(0x88000000),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _snippet(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.42,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    shadows: const [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 8,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _sourceLine(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    shadows: const [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 6,
                        offset: Offset(0, 1),
                      ),
                    ],
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
