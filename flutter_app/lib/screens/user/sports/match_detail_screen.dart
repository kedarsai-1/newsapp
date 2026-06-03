import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/sports_models.dart';
import '../../../providers/sports_provider.dart';
import '../../../constants.dart';
import '../../../widgets/premium_animations.dart';
import '../../../widgets/sports/pulsing_live_indicator.dart';

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
  bool _loading = true;
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
      _inningsTab!.addListener(() {
        // Redraw table when tab changes
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = _match == null;
      _error = null;
    });
    final m = await context.read<SportsProvider>().fetchMatchDetail(widget.matchId);
    if (!mounted) return;
    setState(() {
      _match = m ?? _match;
      _loading = false;
      _error = _match == null ? 'Match not found or scores unavailable.' : null;
    });
    _syncInningsTabs(_match);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final m = _match;

    return GlassScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white70),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          m != null && m.teams.length >= 2
              ? '${m.teams[0].shortName} vs ${m.teams[1].shortName}'
              : 'Scorecard',
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF070A12).withOpacity(0.40),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.08),
                    width: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      child: _loading && m == null
          ? Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: GlassColors.accentGreen,
              ),
            )
          : _error != null && m == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.50)),
                    ),
                  ),
                )
              : m == null
                  ? const SizedBox.shrink()
                  : _buildBody(context, m),
    );
  }

  Widget _buildBody(BuildContext context, SportsMatch m) {
    final hasScorecard = m.scorecard.isNotEmpty;

    return RefreshIndicator(
      color: GlassColors.accentGreen,
      backgroundColor: const Color(0xFF0F172A),
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 48),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          StaggeredEntranceAnimation(
            index: 0,
            child: _summaryCard(m),
          ),
          const SizedBox(height: 24),
          StaggeredEntranceAnimation(
            index: 1,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 15,
                    decoration: BoxDecoration(
                      color: GlassColors.accentGreen,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Full Scorecard',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (hasScorecard) ...[
            if (m.scorecard.every((inn) => inn.batting.isEmpty && inn.totals != null))
              StaggeredEntranceAnimation(
                index: 2,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Text(
                    'Full player scorecard loads when the cricket API quota is available. Innings totals below.',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.40), height: 1.35),
                  ),
                ),
              ),
            if (_inningsTab != null) ...[
              // Premium capsule tab bar
              StaggeredEntranceAnimation(
                index: 2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.8),
                  ),
                  child: TabBar(
                    controller: _inningsTab,
                    isScrollable: true,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white38,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        colors: [
                          GlassColors.accentGreen.withOpacity(0.35),
                          GlassColors.accentGreen.withOpacity(0.15),
                        ],
                      ),
                      border: Border.all(
                        color: GlassColors.accentGreen.withOpacity(0.40),
                        width: 0.8,
                      ),
                    ),
                    tabs: m.scorecard
                        .map((inn) => Tab(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  _shortInningLabel(inn.label),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              StaggeredEntranceAnimation(
                index: 3,
                child: SizedBox(
                  height: _scorecardPaneHeight(m.scorecard[_inningsTab!.index]),
                  child: TabBarView(
                    controller: _inningsTab,
                    children: m.scorecard
                        .map((inn) => _inningScorecard(inn))
                        .toList(),
                  ),
                ),
              ),
            ] else
              StaggeredEntranceAnimation(
                index: 2,
                child: _inningScorecard(m.scorecard.first),
              ),
          ] else
            StaggeredEntranceAnimation(
              index: 2,
              child: GlassCard(
                padding: const EdgeInsets.all(20),
                color: Colors.white.withOpacity(0.04),
                child: Text(
                  m.status == SportsMatchStatus.upcoming
                      ? 'Full scorecard will appear once the match starts.'
                      : 'Detailed scorecard is not available for this match yet. Pull to refresh.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.50),
                    height: 1.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _scorecardPaneHeight(SportsInningScorecard inn) {
    final rows = inn.batting.length + inn.bowling.length + 6;
    return (rows * 38.0 + 100).clamp(280.0, 560.0);
  }

  String _shortInningLabel(String label) {
    final parts = label.split(' ');
    if (parts.length >= 2) {
      return '${parts.first} ${parts.last.replaceAll('Inning', '').trim()}';
    }
    return label.length > 18 ? '${label.substring(0, 16)}…' : label;
  }

  Widget _summaryCard(SportsMatch m) {
    final isLive = m.status == SportsMatchStatus.live;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      color: isLive ? Colors.redAccent.withOpacity(0.03) : Colors.white.withOpacity(0.04),
      borderColor: isLive ? Colors.redAccent.withOpacity(0.30) : Colors.white.withOpacity(0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.thumbnail != null && m.thumbnail!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: m.thumbnail!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                memCacheWidth: 720,
              ),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              if (isLive) ...[
                PulsingLiveIndicator(color: Colors.redAccent, size: 7.0),
                const SizedBox(width: 8),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  m.tournament,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.40),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            m.statusLabel,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
          if (m.venue.isNotEmpty) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 13, color: Colors.white.withOpacity(0.40)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    m.venue,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.45)),
                  ),
                ),
              ],
            ),
          ],
          if (m.tossWinner != null && m.tossWinner!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Toss: ${m.tossWinner} chose to ${m.tossChoice ?? 'bat/bowl'}',
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.40)),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 0.8, color: Colors.white10),
          const SizedBox(height: 12),
          ...m.teams.map((t) => _teamRow(t)),
          if (m.matchWinner != null && m.matchWinner!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: GlassColors.accentGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GlassColors.accentGreen.withOpacity(0.25), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_outlined, size: 14, color: GlassColors.accentGreen),
                  const SizedBox(width: 6),
                  Text(
                    'Winner: ${m.matchWinner}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: GlassColors.accentGreenLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _teamRow(SportsTeam t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.10), width: 0.8),
            ),
            child: Text(
              t.shortName,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t.name,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
          if (t.score != null)
            Text(
              t.score!,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: Colors.white,
              ),
            ),
          if (t.overs != null) ...[
            const SizedBox(width: 6),
            Text(
              '(${t.overs} ov)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.40),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _inningScorecard(SportsInningScorecard inn) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        if (inn.totals != null && inn.totals!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Text(
              inn.totals!,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                color: Colors.white,
              ),
            ),
          ),
        if (inn.extras != null && inn.extras!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 4),
            child: Text(
              inn.extras!,
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.40)),
            ),
          ),
        if (inn.batting.isNotEmpty) ...[
          _sectionTitle('Batting Details'),
          _battingTable(inn.batting),
          const SizedBox(height: 18),
        ],
        if (inn.bowling.isNotEmpty) ...[
          _sectionTitle('Bowling Details'),
          _bowlingTable(inn.bowling),
        ],
        if (inn.batting.isEmpty && inn.bowling.isEmpty && inn.totals != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Innings total: ${inn.totals}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
          color: Colors.white70,
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  Widget _battingTable(List<SportsBatsmanRow> rows) {
    if (rows.isEmpty) {
      return Text('No batting data', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.40)));
    }
    return _tableShell(
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

  Widget _bowlingTable(List<SportsBowlerRow> rows) {
    if (rows.isEmpty) {
      return Text('No bowling data', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.40)));
    }
    return _tableShell(
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

  Widget _tableShell({
    required List<String> header,
    required List<List<String>> rows,
    required int firstColumnFlex,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _tableRow(header, bold: true, firstColumnFlex: firstColumnFlex),
          ...rows.map(
            (cells) => _tableRow(cells, firstColumnFlex: firstColumnFlex),
          ),
        ],
      ),
    );
  }

  Widget _tableRow(
    List<String> cells, {
    bool bold = false,
    int firstColumnFlex = 3,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bold ? GlassColors.accentGreen.withOpacity(0.05) : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 0.8,
          ),
        ),
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
                  fontSize: i == 0 ? 11.5 : 10.5,
                  fontWeight: bold ? FontWeight.w900 : (i == 0 ? FontWeight.w700 : FontWeight.w600),
                  height: 1.25,
                  color: bold
                      ? (i == 0 ? Colors.white : GlassColors.accentGreenLight)
                      : (i == 0 ? Colors.white : Colors.white.withOpacity(0.50)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
