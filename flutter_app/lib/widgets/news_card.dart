import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../constants.dart';

class NewsCard extends StatelessWidget {
  final NewsPost post;
  final bool compact;
  const NewsCard({super.key, required this.post, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final imageFit = kIsWeb ? BoxFit.contain : BoxFit.cover;
    return GestureDetector(
      onTap: () => context.push('/article/${post.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: GlassColors.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: GlassColors.borderWhite, width: 0.8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Breaking / featured header
          if (post.isBreaking || post.isFeatured)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: post.isBreaking
                    ? [GlassColors.accentOrange.withOpacity(0.4), GlassColors.accentOrange.withOpacity(0.2)]
                    : [GlassColors.accentGreen.withOpacity(0.4), GlassColors.accentGreen.withOpacity(0.2)]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: post.isBreaking ? GlassColors.accentOrangeLight : GlassColors.accentGreenLight,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  post.isBreaking ? 'BREAKING NEWS' : 'FEATURED',
                  style: TextStyle(
                    color: post.isBreaking ? GlassColors.accentOrangeLight : GlassColors.accentGreenLight,
                    fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6,
                  ),
                ),
              ]),
            ),

          // Thumbnail
          if (post.hasImages && !compact)
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: post.isBreaking || post.isFeatured ? Radius.zero : const Radius.circular(16),
              ),
              child: Stack(children: [
                CachedNetworkImage(
                  imageUrl: post.firstImage!.url,
                  width: double.infinity,
                  height: 175,
                  fit: imageFit,
                  placeholder: (_, __) => Container(
                    height: 175,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [GlassColors.accentGreen.withOpacity(0.2), GlassColors.accentPurple.withOpacity(0.2)],
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(height: 175, color: GlassColors.surfaceBright,
                      child: const Icon(Icons.image_not_supported, color: GlassColors.textHint, size: 36)),
                ),
                if (post.hasVideos)
                  Positioned(bottom: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(6)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.play_arrow, color: Colors.white, size: 13),
                        SizedBox(width: 3),
                        Text('VIDEO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
              ]),
            ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Category badge
              if (post.category != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: GlassColors.accentGreenSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: GlassColors.accentGreenBorder, width: 0.8),
                  ),
                  child: Text(
                    '${post.category!.icon} ${post.category!.name}',
                    style: const TextStyle(fontSize: 10, color: GlassColors.accentGreenLight, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 7),
              ],

              // Title
              Text(
                post.title,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: GlassColors.textPrimary, height: 1.4),
              ),

              const SizedBox(height: 8),

              // Meta
              Wrap(spacing: 10, runSpacing: 4, children: [
                if (post.reporter != null)
                  _MetaChip(Icons.person_outline, post.reporter!.name),
                _MetaChip(Icons.access_time, timeago.format(post.createdAt)),
                if (post.location?.city != null)
                  _MetaChip(Icons.location_on_outlined, post.location!.city!),
                _MetaChip(Icons.visibility_outlined, '${post.views}'),
                _MetaChip(Icons.favorite_border, '${post.likes}'),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaChip(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: GlassColors.textHint),
      const SizedBox(width: 3),
      Text(text, style: const TextStyle(fontSize: 11, color: GlassColors.textHint)),
    ]);
  }
}