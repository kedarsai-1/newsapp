import 'package:flutter/material.dart';

import 'super_home_section.dart';
import '../../../../widgets/feed/feed_xpresso_palette.dart';
import '../../../../widgets/feed/feed_xpresso_theme.dart';

enum CricketMatchStatus { live, upcoming, finished }

class CricketTeam {
  final String code; // 3-letter code, e.g. CSK
  final String name;
  final Color color;
  final String? score; // e.g. "186/4 (18.2)"

  const CricketTeam({
    required this.code,
    required this.name,
    required this.color,
    this.score,
  });
}

class CricketMatch {
  final String tournament;
  final CricketTeam teamA;
  final CricketTeam teamB;
  final CricketMatchStatus status;
  final String venue;
  final String statusText; // e.g. "Live · 14.3 ov" / "Today, 7:30 PM"
  final String? result;

  const CricketMatch({
    required this.tournament,
    required this.teamA,
    required this.teamB,
    required this.status,
    required this.venue,
    required this.statusText,
    this.result,
  });
}

/// Live Cricket: scoreboard strip + featured match cards + IPL highlights row.
/// Uses a small curated dataset so the section is always populated; swap the
/// `matches` getter for a real cricket API when one is available.
class SuperHomeCricketSection extends StatelessWidget {
  final VoidCallback? onSeeAll;
  final void Function(CricketMatch match)? onMatchTap;

  const SuperHomeCricketSection({
    super.key,
    this.onSeeAll,
    this.onMatchTap,
  });

  static final List<CricketMatch> _matches = [
    CricketMatch(
      tournament: 'IPL 2026',
      teamA: CricketTeam(
        code: 'CSK',
        name: 'Chennai Super Kings',
        color: FeedXpressoPalette.cricketTeamColor("AUS"),
        score: '186/4 (18.2)',
      ),
      teamB: CricketTeam(
        code: 'MI',
        name: 'Mumbai Indians',
        color: FeedXpressoPalette.cricketTeamColor("IND"),
        score: '142/6 (15.4)',
      ),
      status: CricketMatchStatus.live,
      venue: 'Wankhede, Mumbai',
      statusText: 'Live · MI need 45 from 26',
    ),
    CricketMatch(
      tournament: 'IPL 2026',
      teamA: CricketTeam(
        code: 'RCB',
        name: 'Royal Challengers',
        color: FeedXpressoPalette.cricketTeamColor("ENG"),
      ),
      teamB: CricketTeam(
        code: 'KKR',
        name: 'Kolkata Knight Riders',
        color: FeedXpressoPalette.cricketTeamColor("WI"),
      ),
      status: CricketMatchStatus.upcoming,
      venue: 'M Chinnaswamy, Bengaluru',
      statusText: 'Today · 7:30 PM',
    ),
    CricketMatch(
      tournament: 'WPL 2026',
      teamA: CricketTeam(
        code: 'DC-W',
        name: 'Delhi Capitals (W)',
        color: FeedXpressoPalette.cricketTeamColor("SL"),
        score: '164/5 (20.0)',
      ),
      teamB: CricketTeam(
        code: 'GG-W',
        name: 'Gujarat Giants (W)',
        color: FeedXpressoPalette.cricketTeamColor("SA"),
        score: '160/8 (20.0)',
      ),
      status: CricketMatchStatus.finished,
      venue: 'DY Patil, Navi Mumbai',
      statusText: 'Result',
      result: 'Delhi Capitals won by 4 runs',
    ),
  ];

  static const List<_HighlightItem> _highlights = [
    _HighlightItem(
      title: 'Top 5 sixes from last night',
      tag: 'IPL Highlights',
      duration: '02:14',
    ),
    _HighlightItem(
      title: 'Bumrah hat-trick: ball-by-ball',
      tag: 'Match Wrap',
      duration: '01:48',
    ),
    _HighlightItem(
      title: 'Captain’s post-match presser',
      tag: 'Press Room',
      duration: '03:02',
    ),
    _HighlightItem(
      title: 'Points table after Match 32',
      tag: 'Standings',
      duration: '01:05',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SuperHomeSectionHeader(
          title: 'Live Cricket',
          subtitle: 'Live scores, upcoming fixtures and highlights',
          icon: Icons.sports_cricket_rounded,
          accentColor: FeedXpressoPalette.cricketPitchGreen,
          onSeeAll: onSeeAll,
          seeAllLabel: 'All matches',
        ),
        _ScoreboardStrip(matches: _matches),
        SizedBox(height: 6),
        SuperHomeHorizontalRail(
          height: 162,
          itemCount: _matches.length,
          itemBuilder: (context, i) =>
              _MatchCard(match: _matches[i], onTap: onMatchTap),
        ),
        SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
          child: Row(
            children: [
              Icon(Icons.movie_filter_rounded,
                  size: 16, color: FeedXpressoPalette.cricketPitchGreen),
              SizedBox(width: 6),
              Text(
                'IPL Highlights',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
        SuperHomeHorizontalRail(
          height: 138,
          itemCount: _highlights.length,
          itemBuilder: (context, i) => _HighlightCard(item: _highlights[i]),
        ),
      ],
    );
  }
}

// ─── Scoreboard strip ────────────────────────────────────────────────────

class _ScoreboardStrip extends StatelessWidget {
  final List<CricketMatch> matches;
  const _ScoreboardStrip({required this.matches});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: matches.length,
        separatorBuilder: (_, __) => SizedBox(width: 8),
        itemBuilder: (_, i) => _ScoreChip(match: matches[i]),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final CricketMatch match;
  const _ScoreChip({required this.match});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLive = match.status == CricketMatchStatus.live;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cs.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          if (isLive) ...[
            const _LiveDot(),
            SizedBox(width: 6),
          ],
          Text(
            '${match.teamA.code} ${match.teamA.score?.split(' ').first ?? '-'}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          SizedBox(width: 4),
          Text(
            'vs',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(width: 4),
          Text(
            '${match.teamB.code} ${match.teamB.score?.split(' ').first ?? '-'}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.55, end: 1).animate(_c),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: fx.live,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─── Match card ──────────────────────────────────────────────────────────

class _MatchCard extends StatelessWidget {
  final CricketMatch match;
  final void Function(CricketMatch)? onTap;

  const _MatchCard({required this.match, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final cs = Theme.of(context).colorScheme;
    final isLive = match.status == CricketMatchStatus.live;
    final isFinished = match.status == CricketMatchStatus.finished;
    final accent = match.status == CricketMatchStatus.upcoming
        ? FeedXpressoPalette.cricketTeamColor("IND")
        : isFinished
            ? FeedXpressoPalette.cricketTeamColor("")
            : fx.liked;

    return SizedBox(
      width: 280,
      child: Material(
        color: fx.onImage,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null ? null : () => onTap!(match),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: cs.onSurface.withValues(alpha: 0.07),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      match.tournament,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface.withValues(alpha: 0.55),
                        letterSpacing: 0.4,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLive) ...[
                            const _LiveDot(),
                            SizedBox(width: 4),
                          ],
                          Text(
                            isLive
                                ? 'LIVE'
                                : isFinished
                                    ? 'RESULT'
                                    : 'UPCOMING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: accent,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                _TeamRow(team: match.teamA),
                SizedBox(height: 6),
                _TeamRow(team: match.teamB),
                const Spacer(),
                SizedBox(height: 8),
                Text(
                  match.result ?? match.statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  match.venue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  final CricketTeam team;
  const _TeamRow({required this.team});

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: team.color,
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: Text(
            team.code.substring(0, team.code.length > 3 ? 3 : team.code.length),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: fx.onImage,
              letterSpacing: 0.4,
            ),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            team.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
        SizedBox(width: 8),
        Text(
          team.score ?? '—',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ─── Highlights row ──────────────────────────────────────────────────────

class _HighlightItem {
  final String title;
  final String tag;
  final String duration;
  const _HighlightItem({
    required this.title,
    required this.tag,
    required this.duration,
  });
}

class _HighlightCard extends StatelessWidget {
  final _HighlightItem item;
  const _HighlightCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 180,
      child: Material(
        color: fx.onImage,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.onSurface.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [FeedXpressoPalette.cricketPitchGreenDark, FeedXpressoPalette.cricketPitchGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: fx.onImage,
                        size: 38,
                      ),
                    ),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: fx.overlayScrim,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.duration,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: fx.onImage,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: fx.onImage.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          item.tag,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: FeedXpressoPalette.cricketPitchGreen,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
