import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../constants.dart';
import '../models/models.dart';
import 'feed/compact_news_row.dart';

String _snippet(NewsPost post, {int maxLen = 140}) {
  final summary = post.summary?.replaceAll(RegExp(r'\s+'), ' ').trim();
  final base = (summary != null && summary.isNotEmpty)
      ? summary
      : post.body.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (base.length <= maxLen) return base;
  return '${base.substring(0, maxLen).trim()}…';
}

/// Compact list card for news feeds (no immersive / glass layout).
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
    final imageUrl = AppConstants.imageUrlForDisplay(
      post.firstImage?.url,
      articleReferer: post.sourceUrl,
    );
    final source = (post.sourceName?.trim().isNotEmpty == true)
        ? post.sourceName!.trim()
        : (post.category?.name ?? 'News').trim();

    return CompactNewsRow(
      title: post.title,
      summary: _snippet(post),
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
      metaLine: '$source · ${timeago.format(post.displayTime)}',
      onTap: onTap ?? () => context.push('/article/${post.id}'),
    );
  }
}
