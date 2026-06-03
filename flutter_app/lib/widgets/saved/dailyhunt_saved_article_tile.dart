import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/models.dart';
import '../feed/compact_list_row.dart';
import '../feed/feed_xpresso_theme.dart';
import '../premium_utils.dart';

/// Saved article — light compact row (feed uses Xpresso).
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
    return CompactListRow(
      title: post.title,
      imageUrl: premiumImageUrl(post),
      metaLine: '$_source · ${timeago.format(post.displayTime)}',
      onTap: onTap,
      trailing: IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        tooltip: 'Remove from saved',
        onPressed: onRemove,
        icon: Icon(
          Icons.close_rounded,
          size: 17,
          color: FeedXpressoTheme.fx(context).iconFgMuted,
        ),
      ),
    );
  }
}
