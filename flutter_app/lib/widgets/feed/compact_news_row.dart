import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const double kFeedRowExtent = 72;
const double kFeedThumbWidth = 76;
const double kFeedThumbHeight = 50;

/// Dense horizontal news row — flat, minimal layers for list scrolling.
class CompactNewsRow extends StatelessWidget {
  final String title;
  final String? summary;
  final String? imageUrl;
  final String metaLine;
  final VoidCallback? onTap;
  final Widget? trailing;
  final List<CompactFeedAction>? footerActions;
  final double thumbWidth;
  final double thumbHeight;
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
    this.footerActions,
    this.thumbWidth = kFeedThumbWidth,
    this.thumbHeight = kFeedThumbHeight,
    this.titleMaxLines = 2,
    this.showDivider = true,
  });

  /// Headline-first: strong contrast, heavier weight than body.
  static const _titleStyle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 13.75,
    height: 1.12,
    letterSpacing: -0.06,
    color: Color(0xFF101010),
  );
  /// De-emphasised below the headline — light colour, regular weight.
  static const _summaryStyle = TextStyle(
    fontSize: 10.75,
    height: 1.12,
    fontWeight: FontWeight.w400,
    color: Color(0xFFADADAD),
  );
  /// Smallest tier — sits under summary, unobtrusive.
  static const _metaStyle = TextStyle(
    fontSize: 9.25,
    height: 1.05,
    fontWeight: FontWeight.w400,
    color: Color(0xFFB0B0B0),
    letterSpacing: 0.1,
  );

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memW = (thumbWidth * dpr).round().clamp(96, 220);
    final url = imageUrl?.trim() ?? '';
    final hasSummary = summary != null && summary!.trim().isNotEmpty;
    final actions = footerActions;

    return ColoredBox(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 3, 8, 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Thumb(
                    url: url,
                    width: thumbWidth,
                    height: thumbHeight,
                    memCacheWidth: memW,
                  ),
                  const SizedBox(width: 7),
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
                        if (hasSummary)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              summary!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _summaryStyle,
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.only(top: hasSummary ? 0 : 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  metaLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _metaStyle,
                                ),
                              ),
                              if (actions != null && actions.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: actions,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            if (showDivider)
              const Divider(
                height: 1,
                thickness: 0.5,
                color: Color(0xFFE6E6E6),
              ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final int memCacheWidth;

  const _Thumb({
    required this.url,
    required this.width,
    required this.height,
    required this.memCacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        width: width,
        height: height,
        child: url.isEmpty
            ? const ColoredBox(
                color: Color(0xFFF3F3F3),
                child: Icon(Icons.article_outlined, color: Color(0xFFCCCCCC), size: 16),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: kIsWeb ? null : memCacheWidth,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholder: (_, __) => const ColoredBox(color: Color(0xFFEDEDED)),
                errorWidget: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFF3F3F3),
                  child: Icon(Icons.broken_image_outlined, color: Color(0xFFCCCCCC), size: 14),
                ),
              ),
      ),
    );
  }
}

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

  static const Color muted = Color(0xFFB8B8B8);
  static const Color liked = Color(0xFFE57373);
  static const Color saved = Color(0xFF0A8F57);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }
}
