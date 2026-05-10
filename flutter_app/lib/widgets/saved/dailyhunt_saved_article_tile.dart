import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/models.dart';
import '../../theme/dailyhunt_theme.dart';
import '../premium_news_ui.dart';

/// Saved article row: thumbnail, title, source, time, remove (Dailyhunt-style card).
class DailyhuntSavedArticleTile extends StatelessWidget {
  final NewsPost post;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const DailyhuntSavedArticleTile({
    super.key,
    required this.post,
    required this.onTap,
    required this.onRemove,
  });

  String get _source =>
      (post.sourceName?.trim().isNotEmpty == true)
          ? post.sourceName!.trim()
          : (post.category?.name ?? 'News');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final imageUrl = premiumImageUrl(post);
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final thumbPx = (96 * dpr).round().clamp(120, 320);

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.10),
      surfaceTintColor: Colors.transparent,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: imageUrl.isEmpty
                      ? ColoredBox(
                          color: cs.surfaceContainerHighest.withValues(
                            alpha: 0.65,
                          ),
                          child: Icon(
                            Icons.article_outlined,
                            color: cs.onSurface.withValues(alpha: 0.35),
                            size: 36,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: kIsWeb ? null : thumbPx,
                          fadeInDuration: const Duration(milliseconds: 200),
                          placeholder: (_, __) => ColoredBox(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          errorWidget: (_, __, ___) => ColoredBox(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.65,
                            ),
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: cs.onSurface.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            height: 1.22,
                            letterSpacing: -0.2,
                            color: cs.onSurface,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: DailyhuntTheme.accentGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(post.displayTime),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.52),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove from saved',
                onPressed: onRemove,
                icon: Icon(
                  Icons.bookmark_remove_rounded,
                  color: cs.error.withValues(alpha: 0.9),
                  size: 26,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
