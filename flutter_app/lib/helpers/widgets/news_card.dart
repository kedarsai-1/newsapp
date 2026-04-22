import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../constants.dart';
import '../../theme/app_palette.dart';
import '../../widgets/location_label.dart';

class NewsCard extends StatelessWidget {
  final NewsPost post;
  final bool compact;

  const NewsCard({super.key, required this.post, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final imageFit = kIsWeb ? BoxFit.contain : BoxFit.cover;
    return GestureDetector(
      onTap: () => context.push('/article/${post.id}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: p.glassSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.cardBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breaking/Featured badge row
            if (post.isBreaking || post.isFeatured)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: post.isBreaking ? p.breaking : p.primary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle, color: Colors.white, size: 8),
                    const SizedBox(width: 6),
                    Text(
                      post.isBreaking ? 'BREAKING NEWS' : 'FEATURED',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),

            // Media thumbnail
            if (post.hasImages && !compact)
              ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: post.isBreaking || post.isFeatured ? Radius.zero : const Radius.circular(12),
                ),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: AppConstants.imageUrlForDisplay(
                        post.firstImage!.url,
                        articleReferer: post.sourceUrl,
                      ),
                      width: double.infinity,
                      height: 180,
                      fit: imageFit,
                      placeholder: (_, __) => Container(
                        height: 180,
                        color: const Color(0xFFF0F0F0),
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 180,
                        color: const Color(0xFFF0F0F0),
                        child: Icon(Icons.image_not_supported, size: 40, color: p.textHint),
                      ),
                    ),
                    if (post.hasVideos)
                      Positioned(
                        bottom: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow, color: Colors.white, size: 14),
                              SizedBox(width: 2),
                              Text('VIDEO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category chip
                  if (post.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      margin: const EdgeInsets.only(bottom: 7),
                      decoration: BoxDecoration(
                        color: p.categoryChipBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${post.category!.icon} ${post.category!.name}',
                        style: TextStyle(fontSize: 11, color: p.primaryDark, fontWeight: FontWeight.w500),
                      ),
                    ),

                  // Title
                  Text(
                    post.title,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Meta row: reporter, time, location, views
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      if (post.reporter != null)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.person_outline, size: 13, color: p.textHint),
                          const SizedBox(width: 3),
                          Text(post.reporter!.name, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                        ]),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.access_time, size: 13, color: p.textHint),
                        const SizedBox(width: 3),
                        Text(timeago.format(post.createdAt), style: TextStyle(fontSize: 12, color: p.textHint)),
                      ]),
                      if (post.location != null)
                        LocationLabel(
                          location: post.location!,
                          style: TextStyle(fontSize: 12, color: p.textHint),
                          iconSize: 13,
                          expandText: false,
                          maxTextWidth: 180,
                        ),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.visibility_outlined, size: 13, color: p.textHint),
                        const SizedBox(width: 3),
                        Text('${post.views}', style: TextStyle(fontSize: 12, color: p.textHint)),
                      ]),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.favorite_border, size: 13, color: p.textHint),
                        const SizedBox(width: 3),
                        Text('${post.likes}', style: TextStyle(fontSize: 12, color: p.textHint)),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}