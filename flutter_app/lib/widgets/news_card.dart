import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../constants.dart';
import '../models/models.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';

/// Production card: horizontal, borderless, responsive.
class NewsCard extends StatelessWidget {
  final NewsPost post;

  /// Optional override for navigation.
  final VoidCallback? onTap;

  const NewsCard({
    super.key,
    required this.post,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const cardRadius = 16.0;
    return Padding(
      padding: AppSpacing.cardMargin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface, // dark: #1A1A1A
          borderRadius: BorderRadius.circular(cardRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(p.surface, Colors.white, 0.03)!,
              p.surface,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(cardRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap ?? () => context.push('/article/${post.id}'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NewsCardImage(post: post),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: _NewsCardText(
                      post: post,
                      titleStyle:
                          context.titleText.copyWith(color: p.textPrimary),
                      subtitleStyle: context.subtitleText.copyWith(
                        color: p.textSecondary,
                      ),
                      metaStyle: context.metaText.copyWith(color: p.textHint),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewsCardImage extends StatelessWidget {
  final NewsPost post;
  const _NewsCardImage({required this.post});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final raw = post.firstImage?.url;
    final imageUrl = (raw != null && raw.trim().isNotEmpty)
        ? AppConstants.imageUrlForDisplay(raw, articleReferer: post.sourceUrl)
        : '';

    return Container(
      width: 90,
      height: 70,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: p.inputFill, // dark grey backdrop for low-quality images
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: imageUrl.isEmpty
            ? Center(
                child: Icon(
                  Icons.article_outlined,
                  size: 20,
                  color: p.textHint,
                ),
              )
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 180),
                placeholder: (_, __) => Container(color: p.inputFill),
                errorWidget: (_, __, ___) => Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 18,
                    color: p.textHint,
                  ),
                ),
              ),
      ),
    );
  }
}

class _NewsCardText extends StatelessWidget {
  final NewsPost post;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;
  final TextStyle metaStyle;

  const _NewsCardText({
    required this.post,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.metaStyle,
  });

  @override
  Widget build(BuildContext context) {
    final source = (post.sourceName?.trim().isNotEmpty == true)
        ? post.sourceName!.trim()
        : (post.category?.name ?? '').trim();
    final timeLabel = timeago.format(post.createdAt);
    final subtitle = post.summary?.trim().isNotEmpty == true ? post.summary!.trim() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          post.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: subtitleStyle,
          ),
        ],
        const SizedBox(height: AppSpacing.s8),
        _NewsCardMeta(
          source: source,
          timeLabel: timeLabel,
          style: metaStyle,
        ),
      ],
    );
  }
}

class _NewsCardMeta extends StatelessWidget {
  final String source;
  final String timeLabel;
  final TextStyle style;

  const _NewsCardMeta({
    required this.source,
    required this.timeLabel,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            source,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Text(timeLabel, style: style),
      ],
    );
  }
}
