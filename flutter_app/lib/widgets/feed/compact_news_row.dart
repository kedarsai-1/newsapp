import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'feed_xpresso_theme.dart';

export 'feed_xpresso_theme.dart' show FeedXpressoTheme, kFeedRowExtent;

/// Editorial feed row — 16:9 image on top, copy in a separate block below.
class CompactNewsRow extends StatelessWidget {
  final String title;
  final String? summary;
  final String? imageUrl;
  final String metaLine;
  final VoidCallback? onTap;
  final Widget? trailing;
  final List<CompactFeedAction>? footerActions;
  final int titleMaxLines;
  final int summaryMaxLines;
  final bool showDivider;

  const CompactNewsRow({
    super.key,
    required this.title,
    this.summary,
    this.imageUrl,
    required this.metaLine,
    this.onTap,
    this.trailing,
    this.footerActions,
    this.titleMaxLines = FeedXpressoTheme.titleMaxLines,
    this.summaryMaxLines = FeedXpressoTheme.summaryMaxLines,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = (MediaQuery.sizeOf(context).width * dpr).round().clamp(480, 1400);
    final url = imageUrl?.trim() ?? '';
    final hasSummary = summary != null && summary!.trim().isNotEmpty;
    final actions = footerActions;
    final hasActions = actions != null && actions.isNotEmpty;

    return Padding(
      padding: FeedXpressoTheme.cardMargin,
      child: ClipRRect(
        borderRadius: FeedXpressoTheme.cardBorderRadius,
        child: Material(
          color: FeedXpressoTheme.cardSurface,
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: FeedXpressoTheme.imageAspectRatio,
                  child: _HeroImage(url: url, memCacheWidth: memW),
                ),
                Padding(
                  padding: FeedXpressoTheme.rowContentPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: titleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: FeedXpressoTheme.titleStyle,
                      ),
                      if (hasSummary) ...[
                        const SizedBox(height: 5),
                        Text(
                          summary!.trim(),
                          maxLines: summaryMaxLines.clamp(1, 2),
                          overflow: TextOverflow.ellipsis,
                          style: FeedXpressoTheme.summaryStyle,
                        ),
                      ],
                      SizedBox(height: hasSummary ? 8 : 7),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              metaLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FeedXpressoTheme.metaStyle,
                            ),
                          ),
                          if (hasActions) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: FeedXpressoTheme.actionRowWidth,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: actions,
                              ),
                            ),
                          ] else if (trailing != null) ...[
                            const SizedBox(width: 8),
                            trailing!,
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (showDivider)
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: FeedXpressoTheme.divider,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  final String url;
  final int memCacheWidth;

  const _HeroImage({required this.url, required this.memCacheWidth});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const ColoredBox(
        color: FeedXpressoTheme.imagePlaceholder,
        child: Center(
          child: Icon(
            Icons.article_outlined,
            color: FeedXpressoTheme.iconFgMuted,
            size: 28,
          ),
        ),
      );
    }
    return ColoredBox(
      color: FeedXpressoTheme.imagePlaceholder,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: FeedXpressoTheme.imageFit,
        alignment: FeedXpressoTheme.imageAlignment,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: kIsWeb ? null : memCacheWidth,
        fadeInDuration: const Duration(milliseconds: 160),
        fadeOutDuration: Duration.zero,
        placeholder: (_, __) => const ColoredBox(color: FeedXpressoTheme.imagePlaceholder),
        errorWidget: (_, __, ___) => const ColoredBox(
          color: FeedXpressoTheme.imagePlaceholder,
          child: Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: FeedXpressoTheme.iconFgMuted,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary action — fixed slot in the meta row.
class CompactFeedAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const CompactFeedAction({
    super.key,
    required this.icon,
    required this.color,
    this.onTap,
  });

  static const Color muted = FeedXpressoTheme.actionMuted;
  static const Color active = FeedXpressoTheme.actionActive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}
