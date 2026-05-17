import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/sports_models.dart' show SportsMatch, SportsTeam;
import '../../../providers/sports_provider.dart';
import '../../../widgets/feed/feed_xpresso_theme.dart';

class MatchDetailScreen extends StatefulWidget {
  final String matchId;

  const MatchDetailScreen({super.key, required this.matchId});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  SportsMatch? _match;
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
    final m = await context.read<SportsProvider>().fetchMatchDetail(widget.matchId);
    if (!mounted) return;
    setState(() {
      _match = m;
      _loading = false;
      _error = m == null ? 'Match not found or scores unavailable.' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);

    return Scaffold(
      backgroundColor: fx.background,
      appBar: AppBar(
        backgroundColor: fx.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: fx.title,
        title: Text('Match', style: fx.screenTitleStyle.copyWith(fontSize: 17)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : _buildBody(context, fx, _match!),
    );
  }

  Widget _buildBody(BuildContext context, FeedXpressoPalette fx, SportsMatch m) {
    return RefreshIndicator(
      color: fx.accent,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
        children: [
          if (m.thumbnail != null && m.thumbnail!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: m.thumbnail!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                memCacheWidth: 720,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            m.tournament,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fx.meta),
          ),
          const SizedBox(height: 4),
          Text(
            m.statusLabel,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fx.title),
          ),
          if (m.venue.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(m.venue, style: TextStyle(fontSize: 12, color: fx.summary)),
          ],
          const SizedBox(height: 16),
          ...m.teams.map((t) => _teamCard(fx, t)),
          if (m.result != null && m.result!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(m.result!, style: TextStyle(fontSize: 13, color: fx.summary)),
          ],
        ],
      ),
    );
  }

  Widget _teamCard(FeedXpressoPalette fx, SportsTeam t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fx.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fx.divider, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fx.iconSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              t.shortName,
              style: TextStyle(fontWeight: FontWeight.w800, color: fx.title),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t.name,
              style: TextStyle(fontWeight: FontWeight.w700, color: fx.title),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (t.score != null)
                Text(
                  t.score!,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: fx.title),
                ),
              if (t.overs != null)
                Text('${t.overs} ov', style: TextStyle(fontSize: 11, color: fx.meta)),
            ],
          ),
        ],
      ),
    );
  }
}
