import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../models/sports_models.dart';
import '../../../providers/sports_provider.dart';
import '../../../widgets/dailyhunt/xpresso_sliver_app_bar.dart';
import '../../../widgets/feed/feed_xpresso_theme.dart';
import '../../../widgets/sports/sports_highlight_tile.dart';
import '../../../widgets/sports/sports_live_card.dart';
import '../../../widgets/sports/sports_news_tile.dart';
import '../../../widgets/sports/sports_youtube_sheet.dart';

/// Cricket / sports hub — live scores, news, highlights (CricAPI via backend).
class SportsHomeScreen extends StatefulWidget {
  const SportsHomeScreen({super.key});

  @override
  State<SportsHomeScreen> createState() => _SportsHomeScreenState();
}

class _SportsHomeScreenState extends State<SportsHomeScreen> {
  final _scrollController = ScrollController();
  late final SportsProvider _sports;

  @override
  void initState() {
    super.initState();
    _sports = context.read<SportsProvider>();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sports.startLivePolling();
      if (_sports.live.isEmpty && _sports.news.isEmpty) {
        _sports.bootstrap();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _sports.stopLivePolling();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (_scrollController.offset < max - 280) return;
    context.read<SportsProvider>().loadMoreNews();
  }

  void _openMatch(SportsMatch match) {
    if (match.id.isEmpty) return;
    context.push('/sports/match/${match.id}');
  }

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final bottom = FeedXpressoTheme.feedBottomInset(context);

    return Scaffold(
      backgroundColor: fx.background,
      body: RefreshIndicator(
        color: fx.accent,
        onRefresh: () => context.read<SportsProvider>().refreshAll(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: [
            const XpressoSliverAppBar(title: 'Cricket'),
            SliverToBoxAdapter(child: _LiveSection(onMatchTap: _openMatch)),
            SliverToBoxAdapter(child: _HighlightsSection()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
                child: Text(
                  'Cricket news',
                  style: fx.screenTitleStyle.copyWith(fontSize: 16),
                ),
              ),
            ),
            _NewsSection(bottom: bottom),
          ],
        ),
      ),
    );
  }
}

class _LiveSection extends StatelessWidget {
  final void Function(SportsMatch) onMatchTap;

  const _LiveSection({required this.onMatchTap});

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Selector<SportsProvider, (List<SportsMatch>, List<SportsMatch>, String?)>(
      selector: (_, p) => (p.live, p.upcoming, p.liveError),
      builder: (context, data, _) {
        final live = data.$1;
        final upcoming = data.$2;
        final err = data.$3;
        final combined = [...live, ...upcoming];
        if (combined.isEmpty && err != null) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(err, style: TextStyle(color: fx.meta, fontSize: 13)),
          );
        }
        if (combined.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Text(
              'No live or upcoming matches right now.',
              style: TextStyle(color: fx.meta, fontSize: 13),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Row(
                children: [
                  Text(
                    live.isNotEmpty ? 'Live now' : 'Upcoming',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: fx.title,
                    ),
                  ),
                  const Spacer(),
                  if (live.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${live.length} live',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE53935),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 132,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: combined.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => SportsLiveCard(
                  match: combined[i],
                  onTap: () => onMatchTap(combined[i]),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HighlightsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    return Selector<SportsProvider, List<SportsHighlight>>(
      selector: (_, p) => p.highlights,
      builder: (context, items, _) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
              child: Text(
                'Highlights',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: fx.title,
                ),
              ),
            ),
            SizedBox(
              height: 168,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final h = items[i];
                  return SportsHighlightTile(
                    item: h,
                    onTap: () => SportsYoutubeSheet.open(
                      context,
                      title: h.title,
                      youtubeUrl: h.youtubeUrl,
                      youtubeVideoId: h.youtubeVideoId,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NewsSection extends StatelessWidget {
  final double bottom;

  const _NewsSection({required this.bottom});

  @override
  Widget build(BuildContext context) {
    return Selector<SportsProvider, (List<SportsNewsItem>, bool, String?)>(
      selector: (_, p) => (p.news, p.loadingMoreNews, p.newsError),
      builder: (context, data, _) {
        final news = data.$1;
        final loadingMore = data.$2;
        final err = data.$3;

        if (news.isEmpty && err != null) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(err, style: TextStyle(color: FeedXpressoTheme.fx(context).meta)),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= news.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final item = news[index];
              return SportsNewsTile(
                item: item,
                onTap: () {
                  if (item.hasVideo &&
                      (item.youtubeVideoId != null || item.youtubeUrl != null)) {
                    SportsYoutubeSheet.open(
                      context,
                      title: item.title,
                      youtubeUrl: item.youtubeUrl,
                      youtubeVideoId: item.youtubeVideoId,
                    );
                  } else {
                    context.push('/article/${item.id}');
                  }
                },
              );
            },
            childCount: news.length + (loadingMore ? 1 : 0),
          ),
        );
      },
    );
  }
}
