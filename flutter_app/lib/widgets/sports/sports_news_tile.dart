import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/sports_models.dart';
import '../feed/compact_list_row.dart';
import '../feed/feed_xpresso_theme.dart';
import '../premium_animations.dart';

class SportsNewsTile extends StatelessWidget {
  final SportsNewsItem item;
  final VoidCallback onTap;

  const SportsNewsTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = item.time != null
        ? '${item.source} · ${timeago.format(item.time!)}'
        : item.source;

    return PremiumAnimatedWrapper(
      pressScale: 0.98,
      child: CompactListRow(
        title: item.title,
        imageUrl: item.thumbnail,
        metaLine: meta,
        onTap: onTap,
        trailing: item.hasVideo
            ? Icon(Icons.play_circle_outline, color: FeedXpressoTheme.fx(context).meta, size: 20)
            : null,
      ),
    );
  }
}

/// Full-width news row with lazy image (list variant).
class SportsNewsRow extends StatelessWidget {
  final SportsNewsItem item;
  final VoidCallback onTap;

  const SportsNewsRow({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SportsNewsTile(item: item, onTap: onTap);
  }
}
