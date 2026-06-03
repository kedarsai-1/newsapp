import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'feed_xpresso_theme.dart';
import '../glass_card.dart';
import '../../constants.dart';

/// Compact horizontal row for saved / search on dark surfaces — frosted GlassCard.
class CompactListRow extends StatefulWidget {
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
  State<CompactListRow> createState() => _CompactListRowState();
}

class _CompactListRowState extends State<CompactListRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = (CompactListRow._thumbSize * dpr).round().clamp(96, 200);
    final url = widget.imageUrl?.trim() ?? '';
    final hasSummary = widget.summary != null && widget.summary!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: GlassCard(
            padding: const EdgeInsets.all(8),
            radius: 12,
            enableBlur: false,
            borderColor: GlassColors.borderWhite,
            color: GlassColors.surfaceWhite,
            boxShadow: [
              BoxShadow(
                color: GlassColors.isLightMode
                    ? Colors.black.withOpacity(0.04)
                    : Colors.black.withOpacity(0.10),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumb(url: url, memCacheWidth: memW),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: fx.titleStyle.copyWith(fontSize: 13.5),
                      ),
                      if (hasSummary)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            widget.summary!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: fx.summaryStyle,
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.only(top: hasSummary ? 0 : 2),
                        child: Text(
                          widget.metaLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: fx.metaStyle,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
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
                memCacheWidth: kIsWeb ? null : memCacheWidth,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholder: (_, __) =>
                    ColoredBox(color: fx.imagePlaceholder),
                errorWidget: (_, __, ___) => ColoredBox(
                  color: fx.imagePlaceholder,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: fx.iconFgMuted,
                    size: 14,
                  ),
                ),
              ),
      ),
    );
  }
}
