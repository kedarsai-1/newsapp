import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/sports_models.dart';
import '../feed/feed_xpresso_theme.dart';

/// Horizontal live / upcoming match card — Dailyhunt compact style.
class SportsLiveCard extends StatelessWidget {
  final SportsMatch match;
  final VoidCallback? onTap;

  const SportsLiveCard({super.key, required this.match, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final isLive = match.status == SportsMatchStatus.live;
    final a = match.teams.isNotEmpty ? match.teams.first : null;
    final b = match.teams.length > 1 ? match.teams[1] : null;

    return SizedBox(
      width: 268,
      child: Material(
        color: fx.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: fx.divider, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isLive) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE53935),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE53935),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        match.tournament,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: fx.meta,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _teamRow(fx, a),
                const SizedBox(height: 6),
                _teamRow(fx, b),
                const SizedBox(height: 8),
                Text(
                  match.statusLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    color: fx.summary,
                  ),
                ),
                if (match.thumbnail != null && match.thumbnail!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: match.thumbnail!,
                      height: 36,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      placeholder: (_, __) => Container(
                        height: 36,
                        color: fx.imagePlaceholder,
                      ),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _teamRow(FeedXpressoPalette fx, SportsTeam? t) {
    if (t == null) return const SizedBox.shrink();
    final scoreLine = [
      if (t.score != null) t.score,
      if (t.overs != null) '${t.overs} ov',
    ].join(' · ');
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fx.iconSurface,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            t.shortName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: fx.title,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            t.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fx.title,
            ),
          ),
        ),
        if (scoreLine.isNotEmpty)
          Text(
            scoreLine,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fx.title,
            ),
          ),
      ],
    );
  }
}
