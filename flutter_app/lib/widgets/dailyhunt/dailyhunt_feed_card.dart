import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../theme/dailyhunt_theme.dart';

/// Single news row: image, headline, summary, meta, actions (Dailyhunt-style card).
class DailyhuntFeedCard extends StatelessWidget {
  final String imageUrl;
  final String headline;
  final String summary;
  final String sourceName;
  final DateTime publishedAt;
  final int likeCount;
  final bool liked;
  final bool bookmarked;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onShare;
  final VoidCallback? onBookmark;

  const DailyhuntFeedCard({
    super.key,
    required this.imageUrl,
    required this.headline,
    required this.summary,
    required this.sourceName,
    required this.publishedAt,
    this.likeCount = 0,
    this.liked = false,
    this.bookmarked = false,
    this.onTap,
    this.onLike,
    this.onShare,
    this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Material(
        color: Colors.white,
        elevation: 0,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 900,
                      fadeInDuration: const Duration(milliseconds: 220),
                      placeholder: (_, __) => Container(
                        color: const Color(0xFFECECEC),
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: DailyhuntTheme.accentGreen.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFFECECEC),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: cs.onSurface.withValues(alpha: 0.35),
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                    child: Text(
                      headline,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.22,
                        fontSize: 16,
                        letterSpacing: -0.2,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Text(
                      summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium?.copyWith(
                        height: 1.38,
                        fontSize: 13.5,
                        color: cs.onSurface.withValues(alpha: 0.68),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$sourceName • ${timeago.format(publishedAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.labelMedium?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface.withValues(alpha: 0.48),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: cs.onSurface.withValues(alpha: 0.06),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        _ActionChip(
                          icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          label: _formatCount(likeCount + (liked ? 1 : 0)),
                          color: liked ? Colors.redAccent : cs.onSurface.withValues(alpha: 0.55),
                          onTap: onLike,
                        ),
                        _ActionChip(
                          icon: Icons.share_outlined,
                          label: 'Share',
                          color: cs.onSurface.withValues(alpha: 0.55),
                          onTap: onShare,
                        ),
                        _ActionChip(
                          icon: bookmarked
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          label: 'Save',
                          color: bookmarked
                              ? DailyhuntTheme.accentGreen
                              : cs.onSurface.withValues(alpha: 0.55),
                          onTap: onBookmark,
                        ),
                      ],
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

  static String _formatCount(int n) {
    if (n < 1000) return '$n';
    if (n < 1000000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
