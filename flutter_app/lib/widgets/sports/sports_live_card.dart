import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/sports_models.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// Horizontal live / upcoming match card — Dailyhunt compact style.
class SportsLiveCard extends StatelessWidget {
  final SportsMatch match;
  final VoidCallback? onTap;

  /// Tighter layout for horizontal carousels (no thumbnail, shorter footer).
  final bool compact;

  const SportsLiveCard({
    super.key,
    required this.match,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final isLive = match.status == SportsMatchStatus.live;
    final a = match.teams.isNotEmpty ? match.teams.first : null;
    final b = match.teams.length > 1 ? match.teams[1] : null;
    final hasScores = match.teams.any(
      (t) => t.score != null && t.score!.trim().isNotEmpty,
    );
    final showFooter =
        !compact || (!hasScores && match.status == SportsMatchStatus.upcoming);
    final pad = compact ? 10.0 : 12.0;

    return SizedBox(
      width: compact ? 252 : 268,
      child: Material(
        color: fx.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: fx.divider, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          label: '${a?.shortName ?? ''} ${b != null ? 'vs ${b.shortName}' : ''} ${match.status.toString().split('.').last} match',
          hint: 'Double tap to activate',
          button: true,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                Row(
                  children: [
                    if (isLive) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: fx.live,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: fx.live,
                          letterSpacing: 0.6,
                        ),
                      ),
                      SizedBox(width: 8),
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
                SizedBox(height: compact ? 8 : 10),
                _teamRow(fx, a, compact: compact),
                SizedBox(height: compact ? 4 : 6),
                _teamRow(fx, b, compact: compact),
                if (showFooter && match.statusLabel.trim().isNotEmpty) ...[
                  SizedBox(height: compact ? 6 : 8),
                  Text(
                    match.statusLabel,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      color: fx.summary,
                    ),
                  ),
                ],
                if (!compact &&
                    match.thumbnail != null &&
                    match.thumbnail!.isNotEmpty) ...[
                  SizedBox(height: 8),
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
      ),
    );
  }

  Widget _teamRow(
    FeedXpressoPalette fx,
    SportsTeam? t, {
    bool compact = false,
  }) {
    if (t == null) return const SizedBox.shrink();
    final scoreLine = [
      if (t.score != null) t.score,
      if (t.overs != null) '${t.overs} ov',
    ].join(' · ');
    final badge = compact ? 24.0 : 28.0;
    return Row(
      children: [
        Container(
          width: badge,
          height: badge,
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
        SizedBox(width: 8),
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
