import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/models.dart';
import '../../theme/dailyhunt_theme.dart';
import '../premium_news_ui.dart';

/// Compact newspaper-style feed card (Dailyhunt-like): 16:9 image, headline, summary, actions.
class DailyhuntFeedArticleCard extends StatelessWidget {
  final NewsPost post;
  final bool liked;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onShare;
  final VoidCallback onBookmark;

  const DailyhuntFeedArticleCard({
    super.key,
    required this.post,
    required this.liked,
    required this.saved,
    required this.onTap,
    required this.onLike,
    required this.onShare,
    required this.onBookmark,
  });

  String _summary() {
    final s = post.summary?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s != null && s.isNotEmpty) return s;
    final b = post.body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (b.length <= 220) return b;
    return '${b.substring(0, 220).trim()}…';
  }

  String _sourceLine() {
    final src = (post.sourceName?.trim().isNotEmpty == true)
        ? post.sourceName!.trim()
        : (post.category?.name ?? 'News');
    return '$src · ${timeago.format(post.createdAt)}';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = premiumImageUrl(post);
    final cs = Theme.of(context).colorScheme;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final w = MediaQuery.sizeOf(context).width - 24;
    final memW = (w * dpr).round().clamp(400, 1600);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Material(
        color: Colors.white,
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: imageUrl.isEmpty
                    ? ColoredBox(
                        color: const Color(0xFFF0F2F5),
                        child: Icon(
                          Icons.article_outlined,
                          color: cs.onSurface.withValues(alpha: 0.28),
                          size: 44,
                        ),
                      )
                    : Hero(
                        tag: 'post-hero-${post.id}',
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          memCacheWidth: kIsWeb ? null : memW,
                          fadeInDuration: const Duration(milliseconds: 200),
                          placeholder: (_, __) => const ColoredBox(
                            color: Color(0xFFECEEF1),
                          ),
                          errorWidget: (_, __, ___) => ColoredBox(
                            color: const Color(0xFFF0F2F5),
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: cs.onSurface.withValues(alpha: 0.35),
                              size: 40,
                            ),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Text(
                  post.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        height: 1.22,
                        letterSpacing: -0.25,
                        color: const Color(0xFF111111),
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  _summary(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5C5C5C),
                        fontSize: 14,
                        height: 1.38,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  _sourceLine(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF8E8E8E),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                ),
              ),
              Divider(height: 1, color: cs.outline.withValues(alpha: 0.25)),
              Row(
                children: [
                  _ActionPill(
                    icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    label: 'Like',
                    color: liked ? Colors.redAccent : const Color(0xFF555555),
                    onTap: onLike,
                  ),
                  _ActionPill(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    color: const Color(0xFF555555),
                    onTap: onShare,
                  ),
                  _ActionPill(
                    icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    label: 'Save',
                    color: saved ? DailyhuntTheme.accentGreen : const Color(0xFF555555),
                    onTap: onBookmark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
