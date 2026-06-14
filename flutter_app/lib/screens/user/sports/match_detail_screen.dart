import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/sports_models.dart';
import '../../../providers/sports_provider.dart';
import '../../../widgets/feed/feed_xpresso_theme.dart';

class MatchDetailScreen extends StatefulWidget {
  final String matchId;
  final SportsMatch? initialMatch;

  const MatchDetailScreen({
    super.key,
    required this.matchId,
    this.initialMatch,
  });

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen>
    with SingleTickerProviderStateMixin {
  SportsMatch? _match;
  MatchPoll? _poll;
  bool _loading = true;
  bool _voting = false;
  String? _error;
  TabController? _inningsTab;

  @override
  void initState() {
    super.initState();
    _match = widget.initialMatch;
    _syncInningsTabs(_match);
    _load();
  }

  @override
  void dispose() {
    _inningsTab?.dispose();
    super.dispose();
  }

  void _syncInningsTabs(SportsMatch? m) {
    final count = m?.scorecard.length ?? 0;
    if (count <= 1) {
      _inningsTab?.dispose();
      _inningsTab = null;
      return;
    }
    if (_inningsTab == null || _inningsTab!.length != count) {
      _inningsTab?.dispose();
      _inningsTab = TabController(length: count, vsync: this);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = _match == null;
      _error = null;
    });
    final detail =
        await context.read<SportsProvider>().fetchMatchDetail(widget.matchId);
    if (!mounted) return;
    setState(() {
      _match = detail?.match ?? _match;
      _poll = detail?.poll ?? _poll;
      _loading = false;
      _error = _match == null ? 'Match not found or scores unavailable.' : null;
    });
    _syncInningsTabs(_match);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final m = _match;

    return Scaffold(
      backgroundColor: fx.background,
      appBar: AppBar(
        backgroundColor: fx.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: fx.title,
        title: Text(
          m != null && m.teams.length >= 2
              ? '${m.teams[0].shortName} vs ${m.teams[1].shortName}'
              : 'Scorecard',
          style: fx.screenTitleStyle.copyWith(fontSize: 17),
        ),
      ),
      body: _loading && m == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null && m == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : m == null
                  ? const SizedBox.shrink()
                  : _buildBody(context, fx, m),
    );
  }

  Widget _buildBody(BuildContext context, FeedXpressoPalette fx, SportsMatch m) {
    final hasScorecard = m.scorecard.isNotEmpty;

    return RefreshIndicator(
      color: fx.accent,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
        children: [
          _summaryCard(fx, m),
          if (_poll != null) ...[
            const SizedBox(height: 14),
            _pollCard(context, fx, _poll!),
          ],
          const SizedBox(height: 14),
          Text(
            'Scorecard',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: fx.title,
            ),
          ),
          const SizedBox(height: 8),
          if (hasScorecard) ...[
            if (m.scorecard.every((inn) => inn.batting.isEmpty && inn.totals != null))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Full player scorecard loads when the cricket API quota is available. Innings totals below.',
                  style: TextStyle(fontSize: 12, color: fx.meta, height: 1.35),
                ),
              ),
            if (_inningsTab != null) ...[
              TabBar(
                controller: _inningsTab,
                isScrollable: true,
                labelColor: fx.accent,
                unselectedLabelColor: fx.meta,
                indicatorColor: fx.accent,
                tabs: m.scorecard
                    .map((inn) => Tab(text: _shortInningLabel(inn.label)))
                    .toList(),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: _scorecardPaneHeight(m.scorecard[_inningsTab!.index]),
                child: TabBarView(
                  controller: _inningsTab,
                  children: m.scorecard
                      .map((inn) => _inningScorecard(fx, inn))
                      .toList(),
                ),
              ),
            ] else
              _inningScorecard(fx, m.scorecard.first),
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: fx.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: fx.divider, width: 0.5),
              ),
              child: Text(
                m.status == SportsMatchStatus.upcoming
                    ? 'Full scorecard will appear once the match starts.'
                    : 'Detailed scorecard is not available for this match yet. Pull to refresh.',
                style: TextStyle(fontSize: 13, color: fx.summary, height: 1.35),
              ),
            ),
        ],
      ),
    );
  }

  double _scorecardPaneHeight(SportsInningScorecard inn) {
    final rows = inn.batting.length + inn.bowling.length + 6;
    return (rows * 34.0 + 120).clamp(280.0, 520.0);
  }

  String _shortInningLabel(String label) {
    final parts = label.split(' ');
    if (parts.length >= 2) {
      return '${parts.first} ${parts.last.replaceAll('Inning', '').trim()}';
    }
    return label.length > 18 ? '${label.substring(0, 16)}…' : label;
  }

  Widget _summaryCard(FeedXpressoPalette fx, SportsMatch m) {
    final isLive = m.status == SportsMatchStatus.live;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fx.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fx.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.thumbnail != null && m.thumbnail!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: m.thumbnail!,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                memCacheWidth: 720,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              if (isLive) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE53935),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  m.tournament,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fx.meta),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            m.statusLabel,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: fx.title),
          ),
          if (m.venue.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(m.venue, style: TextStyle(fontSize: 12, color: fx.summary)),
          ],
          if (m.tossWinner != null && m.tossWinner!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Toss: ${m.tossWinner} chose to ${m.tossChoice ?? 'bat/bowl'}',
              style: TextStyle(fontSize: 12, color: fx.meta),
            ),
          ],
          const SizedBox(height: 12),
          ...m.teams.map((t) => _teamRow(fx, t)),
          if (m.matchWinner != null && m.matchWinner!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Winner: ${m.matchWinner}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fx.accent),
            ),
          ],
        ],
      ),
    );
  }

  Widget _teamRow(FeedXpressoPalette fx, SportsTeam t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fx.iconSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              t.shortName,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: fx.title),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.name,
              style: TextStyle(fontWeight: FontWeight.w700, color: fx.title),
            ),
          ),
          if (t.score != null)
            Text(
              t.score!,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: fx.title),
            ),
          if (t.overs != null) ...[
            const SizedBox(width: 6),
            Text('(${t.overs} ov)', style: TextStyle(fontSize: 11, color: fx.meta)),
          ],
        ],
      ),
    );
  }

  Widget _inningScorecard(FeedXpressoPalette fx, SportsInningScorecard inn) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        if (inn.totals != null && inn.totals!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(inn.totals!, style: TextStyle(fontWeight: FontWeight.w700, color: fx.title)),
          ),
        if (inn.extras != null && inn.extras!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(inn.extras!, style: TextStyle(fontSize: 12, color: fx.meta)),
          ),
        if (inn.batting.isNotEmpty) ...[
          _sectionTitle(fx, 'Batting'),
          _battingTable(fx, inn.batting),
          const SizedBox(height: 12),
        ],
        if (inn.bowling.isNotEmpty) ...[
          _sectionTitle(fx, 'Bowling'),
          _bowlingTable(fx, inn.bowling),
        ],
        if (inn.batting.isEmpty && inn.bowling.isEmpty && inn.totals != null)
          Text(
            'Innings total: ${inn.totals}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fx.title),
          ),
      ],
    );
  }

  Widget _sectionTitle(FeedXpressoPalette fx, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fx.title),
      ),
    );
  }

  Widget _battingTable(FeedXpressoPalette fx, List<SportsBatsmanRow> rows) {
    if (rows.isEmpty) {
      return Text('No batting data', style: TextStyle(fontSize: 12, color: fx.meta));
    }
    return _tableShell(
      fx,
      header: const ['Batsman', 'R', 'B', '4s', '6s', 'SR'],
      rows: rows
          .map(
            (b) => [
              '${b.name}\n${b.dismissal}',
              '${b.runs}',
              '${b.balls}',
              '${b.fours}',
              '${b.sixes}',
              b.strikeRate.toStringAsFixed(1),
            ],
          )
          .toList(),
      firstColumnFlex: 4,
    );
  }

  Widget _bowlingTable(FeedXpressoPalette fx, List<SportsBowlerRow> rows) {
    if (rows.isEmpty) {
      return Text('No bowling data', style: TextStyle(fontSize: 12, color: fx.meta));
    }
    return _tableShell(
      fx,
      header: const ['Bowler', 'O', 'M', 'R', 'W', 'Eco'],
      rows: rows
          .map(
            (b) => [
              b.name,
              _fmtOvers(b.overs),
              '${b.maidens}',
              '${b.runs}',
              '${b.wickets}',
              b.economy.toStringAsFixed(1),
            ],
          )
          .toList(),
      firstColumnFlex: 3,
    );
  }

  String _fmtOvers(double o) {
    if (o % 1 == 0) return o.toInt().toString();
    return o.toStringAsFixed(1);
  }

  Widget _tableShell(
    FeedXpressoPalette fx, {
    required List<String> header,
    required List<List<String>> rows,
    required int firstColumnFlex,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: fx.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fx.divider, width: 0.5),
      ),
      child: Column(
        children: [
          _tableRow(fx, header, bold: true, firstColumnFlex: firstColumnFlex),
          ...rows.map(
            (cells) => _tableRow(fx, cells, firstColumnFlex: firstColumnFlex),
          ),
        ],
      ),
    );
  }

  Widget _tableRow(
    FeedXpressoPalette fx,
    List<String> cells, {
    bool bold = false,
    int firstColumnFlex = 3,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: fx.divider.withValues(alpha: 0.5))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: i == 0 ? firstColumnFlex : 1,
              child: Text(
                cells[i],
                maxLines: i == 0 ? 3 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: i == 0 ? 12 : 11,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                  height: 1.25,
                  color: i == 0 ? fx.title : fx.summary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _castVote(String option) async {
    if (_voting || _poll == null) return;
    setState(() => _voting = true);
    final poll = await context.read<SportsProvider>().voteMatchPoll(
          widget.matchId,
          option,
        );
    if (!mounted) return;
    setState(() {
      _voting = false;
      if (poll != null) _poll = poll;
    });
    if (poll == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to vote on match predictions.')),
      );
    }
  }

  Widget _pollCard(BuildContext context, FeedXpressoPalette fx, MatchPoll poll) {
    final total = poll.totalVotes;
    final pctA = total > 0 ? poll.votesA / total : 0.5;
    final pctB = total > 0 ? poll.votesB / total : 0.5;
    final voted = poll.userVote != null;
    final closed = poll.isResolved;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fx.iconSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fx.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.how_to_vote_outlined, color: fx.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Who will win?',
                style: TextStyle(
                  color: fx.title,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (closed)
                Text(
                  'Closed',
                  style: TextStyle(color: fx.actionMuted, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _pollOption(
            fx: fx,
            label: poll.optionATitle,
            pct: pctA,
            selected: poll.userVote == 'A',
            enabled: !closed && !voted && !_voting,
            onTap: () => _castVote('A'),
          ),
          const SizedBox(height: 8),
          _pollOption(
            fx: fx,
            label: poll.optionBTitle,
            pct: pctB,
            selected: poll.userVote == 'B',
            enabled: !closed && !voted && !_voting,
            onTap: () => _castVote('B'),
          ),
          if (total > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$total votes',
              style: TextStyle(color: fx.actionMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pollOption({
    required FeedXpressoPalette fx,
    required String label,
    required double pct,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? fx.accent : fx.divider.withValues(alpha: 0.7),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: fx.title,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${(pct * 100).round()}%',
                style: TextStyle(color: fx.accent, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
