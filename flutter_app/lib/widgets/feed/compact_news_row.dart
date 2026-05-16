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
  final bool showSummary;
  final VoidCallback? onImageUnavailable;

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
    this.showSummary = false,
    this.onImageUnavailable,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = (MediaQuery.sizeOf(context).width * dpr).round().clamp(480, 1400);
    final url = imageUrl?.trim() ?? '';
    final hasSummary =
        showSummary && summary != null && summary!.trim().isNotEmpty;
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
                _HeroImage(
                  url: url,
                  memCacheWidth: memW,
                  onUnavailable: onImageUnavailable,
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

class _HeroImage extends StatefulWidget {
  final String url;
  final int memCacheWidth;
  final VoidCallback? onUnavailable;

  const _HeroImage({
    required this.url,
    required this.memCacheWidth,
    this.onUnavailable,
  });

  @override
  State<_HeroImage> createState() => _HeroImageState();
}

class _HeroImageState extends State<_HeroImage> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (widget.url.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onUnavailable?.call();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _HeroImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _failed = false;
      if (widget.url.trim().isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onUnavailable?.call();
        });
      }
    }
  }

  void _reportUnavailable() {
    if (_failed) return;
    _failed = true;
    widget.onUnavailable?.call();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url.trim();
    if (url.isEmpty || _failed) {
      return const SizedBox.shrink();
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: FeedXpressoTheme.imageFit,
      alignment: FeedXpressoTheme.imageAlignment,
      memCacheWidth: kIsWeb ? null : widget.memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 160),
      fadeOutDuration: Duration.zero,
      placeholder: (_, __) => const SizedBox.shrink(),
      errorWidget: (_, __, ___) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _reportUnavailable());
        return const SizedBox.shrink();
      },
      imageBuilder: (context, imageProvider) {
        return AspectRatio(
          aspectRatio: FeedXpressoTheme.imageAspectRatio,
          child: Image(
            image: imageProvider,
            fit: FeedXpressoTheme.imageFit,
            alignment: FeedXpressoTheme.imageAlignment,
            width: double.infinity,
            height: double.infinity,
          ),
        );
      },
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
