import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../models/sports_models.dart';
import '../../../providers/sports_provider.dart';
import '../../../services/auth_provider.dart';
import '../../../utils/i18n.dart';
import '../../../widgets/feed/feed_xpresso_theme.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<LeaderboardEntry> _entries = [];
  LeaderboardEntry? _me;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await context.read<SportsProvider>().fetchLeaderboard();
    if (!mounted) return;
    if (res['success'] == true) {
      final board = res['leaderboard'];
      final entries = <LeaderboardEntry>[];
      if (board is List) {
        for (var i = 0; i < board.length; i++) {
          if (board[i] is! Map) continue;
          final row = Map<String, dynamic>.from(board[i] as Map);
          row['rank'] = row['rank'] ?? (i + 1);
          entries.add(LeaderboardEntry.fromJson(row));
        }
      }
      LeaderboardEntry? me;
      if (res['currentUser'] is Map) {
        me = LeaderboardEntry.fromJson(
          Map<String, dynamic>.from(res['currentUser'] as Map),
        );
      }
      setState(() {
        _entries = entries;
        _me = me;
        _loading = false;
      });
    } else {
      setState(() {
        _error = res['message']?.toString() ?? 'Could not load leaderboard.';
        _loading = false;
      });
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/feed');
  }

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
      backgroundColor: fx.background,
      appBar: AppBar(
        backgroundColor: fx.background,
        foregroundColor: fx.title,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _handleBack,
        ),
        title: Text(I18n.t(context, 'menu_leaderboard')),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
                    children: [
                      if (!loggedIn)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Sign in and vote on match predictions to earn points.',
                            style: TextStyle(color: fx.actionMuted, height: 1.4),
                          ),
                        ),
                      if (_me != null) ...[
                        _MeCard(entry: _me!, fx: fx),
                        SizedBox(height: 16),
                      ],
                      ..._entries.map((e) => _RankTile(entry: e, fx: fx)),
                      if (_entries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No scores yet. Vote on live cricket matches to climb the board.',
                            style: TextStyle(color: fx.actionMuted),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
    ),
    );
  }
}

class _MeCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final FeedXpressoPalette fx;

  const _MeCard({required this.entry, required this.fx});

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fx.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fx.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: fx.accent,
            child: Text(
              entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
              style: TextStyle(color: fx.onImage, fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your rank',
                  style: TextStyle(color: fx.actionMuted, fontSize: 12),
                ),
                Text(
                  entry.name,
                  style: TextStyle(
                    color: fx.title,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '#${entry.rank > 0 ? entry.rank : '—'}',
                style: TextStyle(
                  color: fx.accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              Text(
                '${entry.points} pts',
                style: TextStyle(color: fx.summary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final FeedXpressoPalette fx;

  const _RankTile({required this.entry, required this.fx});

  @override
  Widget build(BuildContext context) {
    final fx = context.fx;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: fx.iconSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fx.divider.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                color: fx.accent,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.name,
              style: TextStyle(
                color: fx.title,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${entry.points} pts',
            style: TextStyle(color: fx.summary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
