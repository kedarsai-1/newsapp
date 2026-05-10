import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../constants.dart';
import '../models/models.dart';

String _snippet(NewsPost post, {int maxLen = 220}) {
  final summary = post.summary?.replaceAll(RegExp(r'\s+'), ' ').trim();
  final base = (summary != null && summary.isNotEmpty)
      ? summary
      : post.body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (base.length <= maxLen) return base;
  return '${base.substring(0, maxLen).trim()}...';
}

class NewsCard extends StatelessWidget {
  final NewsPost post;
  final VoidCallback? onTap;

  const NewsCard({
    super.key,
    required this.post,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final iconColor = isDark ? Colors.white : Colors.black;
    final overlayBase = isDark ? Colors.black : Colors.white;
    final imageUrl = AppConstants.imageUrlForDisplay(
      post.firstImage?.url,
      articleReferer: post.sourceUrl,
    );
    final source = (post.sourceName?.trim().isNotEmpty == true)
        ? post.sourceName!.trim()
        : (post.category?.name ?? 'News').trim();
    final timeLabel = timeago.format(post.displayTime);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: AspectRatio(
        aspectRatio: 9 / 12,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: bgColor,
            child: InkWell(
              onTap: onTap ?? () => context.push('/article/${post.id}'),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: imageUrl.isEmpty
                        ? Container(
                            color: isDark ? Colors.black12 : Colors.black26,
                          )
                        : CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            memCacheWidth: 1600,
                            placeholder: (context, url) =>
                                Container(
                                  color:
                                      isDark ? Colors.black12 : Colors.black26,
                                ),
                            errorWidget: (context, url, error) =>
                                Icon(
                                  Icons.error,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                          ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            overlayBase.withValues(alpha: 0.2),
                            overlayBase.withValues(alpha: 0.6),
                            overlayBase.withValues(alpha: 0.9),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _circleIcon(context, Icons.person),
                        _glassBadge(context, 'NewsNow'),
                        _circleIcon(context, Icons.notifications),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 130,
                    child: Column(
                      children: [
                        _actionButton(
                          context,
                          Icons.favorite_border,
                          '${post.likes}',
                        ),
                        const SizedBox(height: 14),
                        _actionButton(context, Icons.bookmark_border, 'Save'),
                        const SizedBox(height: 14),
                        _actionButton(context, Icons.share, 'Share'),
                        const SizedBox(height: 14),
                        _actionButton(context, Icons.translate, 'Translate'),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 92,
                    bottom: 14,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  height: 1.3,
                                  shadows: [
                                    Shadow(
                                      color: Color(0x88000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _snippet(post, maxLen: 180),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.85),
                                  fontSize: 14,
                                  height: 1.4,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0x66000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '$source • $timeLabel',
                                style: TextStyle(
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.7),
                                  fontSize: 12,
                                  shadows: const [
                                    Shadow(
                                      color: Color(0x55000000),
                                      blurRadius: 4,
                                      offset: Offset(0, 1),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleIcon(BuildContext context, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.black.withValues(alpha: 0.4)
            : Colors.white.withValues(alpha: 0.78),
      ),
      child: Icon(icon, color: isDark ? Colors.white : Colors.black),
    );
  }

  Widget _actionButton(BuildContext context, IconData icon, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.black.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.82),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.black.withValues(alpha: 0.16),
                ),
              ),
              child: Icon(icon, color: isDark ? Colors.white : Colors.black),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _glassBadge(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
