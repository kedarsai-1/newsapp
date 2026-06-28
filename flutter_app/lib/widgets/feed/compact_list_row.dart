import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../utils/feed_failed_image_cache.dart';
import 'feed_xpresso_theme.dart';

/// Compact horizontal row for saved / search on dark surfaces.
class CompactListRow extends StatelessWidget {
  final String title;
  final String? summary;
  final String? imageUrl;
  final String metaLine;
  final VoidCallback? onTap;
  final Widget? trailing;

  const CompactListRow({
    super.key,
    required this.title,
    this.summary,
    this.imageUrl,
    required this.metaLine,
    this.onTap,
    this.trailing,
  });

  static const _thumbSize = 56.0;

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = (_thumbSize * dpr).round().clamp(96, 200);
    final url = imageUrl?.trim() ?? '';
    final hasSummary = summary != null && summary!.trim().isNotEmpty;

    return ColoredBox(
      color: fx.background,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Thumb(url: url, memCacheWidth: memW),
                  SizedBox(width: 7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: fx.titleStyle.copyWith(fontSize: 13.5),
                        ),
                        if (hasSummary)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              summary!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: fx.summaryStyle,
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.only(top: hasSummary ? 0 : 2),
                          child: Text(
                            metaLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: fx.metaStyle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 0.5,
              color: fx.divider,
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String url;
  final int memCacheWidth;

  const _Thumb({required this.url, required this.memCacheWidth});

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: CompactListRow._thumbSize,
        height: CompactListRow._thumbSize * 0.68,
        child: url.isEmpty
            ? ColoredBox(
                color: fx.imagePlaceholder,
                child: Icon(
                  Icons.article_outlined,
                  color: fx.iconFgMuted,
                  size: 16,
                ),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: memCacheWidth,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholder: (_, __) =>
                    ColoredBox(color: fx.imagePlaceholder),
                errorWidget: (_, __, ___) {
                  FeedFailedImageCache.markFailed(url);
                  return ColoredBox(
                    color: fx.imagePlaceholder,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: fx.iconFgMuted,
                      size: 14,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
