import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Dense horizontal news row — flat layout, minimal repaints.
class CompactNewsRow extends StatelessWidget {
  final String title;
  final String? summary;
  final String? imageUrl;
  final String metaLine;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? actionBar;
  final double thumbSize;

  const CompactNewsRow({
    super.key,
    required this.title,
    this.summary,
    this.imageUrl,
    required this.metaLine,
    this.onTap,
    this.trailing,
    this.actionBar,
    this.thumbSize = 84,
  });

  static const _borderSide = BorderSide(color: Color(0xFFEBEBEB));
  static const _titleStyle = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 14.5,
    height: 1.2,
    letterSpacing: -0.15,
    color: Color(0xFF111111),
  );
  static const _summaryStyle = TextStyle(
    fontSize: 12.5,
    height: 1.25,
    color: Color(0xFF666666),
  );
  static const _metaStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Color(0xFF909090),
  );

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final thumbPx = (thumbSize * dpr).round().clamp(120, 240);
    final url = imageUrl?.trim() ?? '';
    final hasSummary = summary != null && summary!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: RepaintBoundary(
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: _borderSide,
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Thumb(url: url, size: thumbSize, memCacheWidth: thumbPx),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: _titleStyle,
                            ),
                            if (hasSummary) ...[
                              const SizedBox(height: 4),
                              Text(
                                summary!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: _summaryStyle,
                              ),
                            ],
                            const SizedBox(height: 5),
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
                if (actionBar != null) ...[
                  const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
                  actionBar!,
                ],
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
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? const ColoredBox(
                color: Color(0xFFF0F0F0),
                child: Icon(Icons.article_outlined, color: Color(0xFFBBBBBB), size: 28),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: kIsWeb ? null : memCacheWidth,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholder: (_, __) => const ColoredBox(color: Color(0xFFE8E8E8)),
                errorWidget: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFF0F0F0),
                  child: Icon(Icons.broken_image_outlined, color: Color(0xFFBBBBBB), size: 24),
                ),
              ),
      ),
    );
  }
}

/// Flat icon+label action for feed rows.
class CompactFeedActionBar extends StatelessWidget {
  final List<CompactFeedAction> actions;

  const CompactFeedActionBar({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(children: actions);
  }
}

class CompactFeedAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const CompactFeedAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  static const _labelStyle = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _labelStyle.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
