import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../models/sports_models.dart';
import '../../providers/sports_provider.dart';
import '../../screens/user/super_home/widgets/super_home_astrology.dart';
import 'feed_youtube_rail.dart';
import 'feed_xpresso_theme.dart';

/// Top-of-feed modules: YouTube rail, live cricket, astrology.
class FeedHomeHeader extends StatefulWidget {
  final void Function(NewsPost post) onOpen;
  final String? language;

  const FeedHomeHeader({
    super.key,
    required this.onOpen,
    this.language,
  });

  @override
  State<FeedHomeHeader> createState() => _FeedHomeHeaderState();
}

class _FeedHomeHeaderState extends State<FeedHomeHeader> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sports = context.read<SportsProvider>();
      if (sports.live.isEmpty && !sports.loadingLive) {
        sports.refreshLive(silent: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FeedYoutubeRail(
          language: widget.language,
          onOpen: widget.onOpen,
        ),
        const _LiveCricketRail(),
        SuperHomeAstrologySection(
          onSeeAll: () => context.push('/ai-chat'),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _LiveCricketRail extends StatelessWidget {
  const _LiveCricketRail();

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Selector<SportsProvider, List<SportsMatch>>(
      selector: (_, s) => [...s.live, ...s.upcoming].take(6).toList(),
      builder: (_, matches, __) {
        if (matches.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Row(
                children: [
                  Icon(Icons.sports_cricket_rounded, color: fx.accent, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Live Cricket',
                    style: TextStyle(
                      color: fx.iconFg,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.push('/sports'),
                    child: const Text('All matches'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: matches.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final m = matches[i];
                  final a = m.teams.isNotEmpty ? m.teams[0] : null;
                  final b = m.teams.length > 1 ? m.teams[1] : null;
                  return Material(
                    color: fx.iconSurface,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => context.push('/sports/match/${m.id}', extra: m),
                      child: Container(
                        width: 210,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: fx.divider.withValues(alpha: 0.6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.tournament,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: fx.actionMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${a?.shortName ?? '—'} vs ${b?.shortName ?? '—'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: fx.iconFg,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              m.statusLabel.isNotEmpty ? m.statusLabel : m.status.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: fx.accent, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
          ],
        );
      },
    );
  }
}
