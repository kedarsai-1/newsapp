import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/models.dart';
import '../feed/compact_news_row.dart';
import '../premium_news_ui.dart';

/// Saved article — same dense row as the main feed.
class DailyhuntSavedArticleTile extends StatelessWidget {
  final NewsPost post;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const DailyhuntSavedArticleTile({
    super.key,
    required this.post,
    required this.onTap,
    required this.onRemove,
  });

  String get _source =>
      (post.sourceName?.trim().isNotEmpty == true)
          ? post.sourceName!.trim()
          : (post.category?.name ?? 'News');

  @override
  Widget build(BuildContext context) {
    return CompactNewsRow(
      title: post.title,
      imageUrl: premiumImageUrl(post),
      metaLine: '$_source · ${timeago.format(post.displayTime)}',
      onTap: onTap,
      trailing: IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        tooltip: 'Remove from saved',
        onPressed: onRemove,
        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF9E9E9E)),
      ),
    );
  }
}
