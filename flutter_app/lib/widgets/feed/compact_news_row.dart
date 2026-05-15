import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Approximate row height for scroll precache (thumb + text + actions).
const double kFeedRowExtent = 96;

/// Default thumbnail edge — small square like Dailyhunt.
const double kFeedThumbSize = 64;

/// Dense horizontal news row: hairline separator, no card chrome.
class CompactNewsRow extends StatelessWidget {
  final String title;
  final String? summary;
  final String? imageUrl;
  final String metaLine;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? actionBar;
  final double thumbSize;
  final int titleMaxLines;
  final bool showDivider;

  const CompactNewsRow({
    super.key,
    required this.title,
    this.summary,
    this.imageUrl,
    required this.metaLine,
    this.onTap,
    this.trailing,
    this.actionBar,
    this.thumbSize = kFeedThumbSize,
    this.titleMaxLines = 2,
    this.showDivider = true,
  });

  static const _titleStyle = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 14,
    height: 1.18,
    letterSpacing: -0.12,
    color: Color(0xFF111111),
  );
  static const _summaryStyle = TextStyle(
    fontSize: 11.5,
    height: 1.2,
    color: Color(0xFF6B6B6B),
  );
  static const _metaStyle = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    color: Color(0xFF9A9A9A),
  );

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final thumbPx = (thumbSize * dpr).round().clamp(96, 200);
    final url = imageUrl?.trim() ?? '';
    final hasSummary = summary != null && summary!.trim().isNotEmpty;

    return RepaintBoundary(
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Thumb(url: url, size: thumbSize, memCacheWidth: thumbPx),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: titleMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style: _titleStyle,
                          ),
                          if (hasSummary) ...[
                            const SizedBox(height: 2),
                            Text(
                              summary!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _summaryStyle,
                            ),
                          ],
                          const SizedBox(height: 3),
                          Text(
                            metaLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _metaStyle,
                          ),
                        ],
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
              if (actionBar != null) actionBar!,
              if (showDivider)
                const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 10,
                  endIndent: 10,
                  color: Color(0xFFEDEDED),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String url;
  final double size;
  final int memCacheWidth;

  const _Thumb({
    required this.url,
    required this.size,
    required this.memCacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? const ColoredBox(
                color: Color(0xFFF2F2F2),
                child: Icon(Icons.article_outlined, color: Color(0xFFC4C4C4), size: 22),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: kIsWeb ? null : memCacheWidth,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholder: (_, __) => const ColoredBox(color: Color(0xFFE8E8E8)),
                errorWidget: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFF2F2F2),
                  child: Icon(Icons.broken_image_outlined, color: Color(0xFFC4C4C4), size: 20),
                ),
              ),
      ),
    );
  }
}

/// Icon-only action strip — minimal height.
class CompactFeedActionBar extends StatelessWidget {
  final List<CompactFeedAction> actions;

  const CompactFeedActionBar({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 2),
      child: Row(children: actions),
    );
  }
}

class CompactFeedAction extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color color;
  final VoidCallback? onTap;

  const CompactFeedAction({
    super.key,
    required this.icon,
    this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 30,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: color),
              if (label != null && label!.isNotEmpty) ...[
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    label!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
