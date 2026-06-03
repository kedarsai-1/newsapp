import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/sports_models.dart';
import '../../constants.dart';
import '../glass_card.dart';
import '../premium_animations.dart';
import 'pulsing_live_indicator.dart';

/// Horizontal live / upcoming match card — Premium Glassmorphic style.
class SportsLiveCard extends StatefulWidget {
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
  State<SportsLiveCard> createState() => _SportsLiveCardState();
}

class _SportsLiveCardState extends State<SportsLiveCard> {

  @override
  Widget build(BuildContext context) {
    final isLive = widget.match.status == SportsMatchStatus.live;
    final a = widget.match.teams.isNotEmpty ? widget.match.teams.first : null;
    final b = widget.match.teams.length > 1 ? widget.match.teams[1] : null;
    final hasScores = widget.match.teams.any(
      (t) => t.score != null && t.score!.trim().isNotEmpty,
    );
    final showFooter =
        !widget.compact || (!hasScores && widget.match.status == SportsMatchStatus.upcoming);
    final pad = widget.compact ? 12.0 : 14.0;

    // Glowing border highlight for live matches, clean translucent border for others
    final Color borderColor = isLive
        ? Colors.redAccent.withOpacity(0.40)
        : Colors.white.withOpacity(0.12);

    return SizedBox(
      width: widget.compact ? 258 : 272,
      child: GestureDetector(
        onTap: widget.onTap,
        child: PremiumAnimatedWrapper(
          // Default pressScale matches previous behavior (0.97)
          pressScale: 0.97,
          child: GlassCard(
            enableAnimation: false,
            radius: 16,
            padding: EdgeInsets.all(pad),
            color: isLive
                ? Colors.redAccent.withOpacity(0.03) // Subtle red ambient tint for live matches
                : Colors.white.withOpacity(0.04),
            borderColor: borderColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              if (isLive)
                BoxShadow(
                  color: Colors.redAccent.withOpacity(0.05),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (isLive) ...[
                      PulsingLiveIndicator(color: Colors.redAccent, size: 7.0),
                      const SizedBox(width: 8),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.redAccent,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        widget.match.tournament,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.50),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _teamRow(a, compact: widget.compact),
                const SizedBox(height: 6),
                _teamRow(b, compact: widget.compact),
                if (showFooter && widget.match.statusLabel.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.match.statusLabel,
                    maxLines: widget.compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: isLive ? Colors.redAccent.shade100 : Colors.white.withOpacity(0.60),
                    ),
                  ),
                ],
                if (!widget.compact &&
                    widget.match.thumbnail != null &&
                    widget.match.thumbnail!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: widget.match.thumbnail!,
                      height: 38,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      placeholder: (_, __) => Container(
                        height: 38,
                        color: Colors.white12,
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

  Widget _teamRow(
    SportsTeam? t, {
    bool compact = false,
  }) {
    if (t == null) return const SizedBox.shrink();
    final scoreLine = [
      if (t.score != null) t.score,
      if (t.overs != null) '${t.overs} ov',
    ].join(' · ');
    final badge = compact ? 24.0 : 26.0;

    return Row(
      children: [
        // Frosted Glass Circle Badge for Team Name
        Container(
          width: badge,
          height: badge,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 0.8,
            ),
          ),
          child: Text(
            t.shortName,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.white70,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            t.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        if (scoreLine.isNotEmpty)
          Text(
            scoreLine,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
      ],
    );
  }
}
