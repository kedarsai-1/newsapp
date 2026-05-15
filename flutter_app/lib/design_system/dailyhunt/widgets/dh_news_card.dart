import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../dailyhunt_tokens.dart';

/// List-style news row: thumbnail, bold headline, meta line (Dailyhunt-style).
class DhNewsCard extends StatelessWidget {
  final String title;
  final String? summary;
  final String imageUrl;
  final String sourceLabel;
  final String timeLabel;
  final VoidCallback? onTap;
  final Widget? trailing;

  const DhNewsCard({
    super.key,
    required this.title,
    this.summary,
    required this.imageUrl,
    required this.sourceLabel,
    required this.timeLabel,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final thumbPx = (84 * dpr).round().clamp(120, 280);

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: imageUrl.isEmpty
                      ? ColoredBox(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
                          child: Icon(
                            Icons.article_outlined,
                            color: cs.onSurface.withValues(alpha: 0.35),
                            size: 32,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: kIsWeb ? null : thumbPx,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          placeholder: (_, __) => ColoredBox(
                            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          ),
                          errorWidget: (_, __, ___) => ColoredBox(
                            color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
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
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.22,
                        color: cs.onSurface,
                      ),
                    ),
                    if (summary != null && summary!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        summary!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.62),
                          height: 1.38,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '$sourceLabel · $timeLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.labelLarge?.copyWith(
                        color: DhTokens.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
