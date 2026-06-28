import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../helpers/widgets/news_card.dart';
import '../../providers/news_provider.dart';
import '../../utils/i18n.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// Trending topics page showing all trending stories in a vertical list.
class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    setState(() => _loading = true);
    await context.read<NewsProvider>().loadTrendingFeed();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsProvider>();
    final trendingPosts = provider.trendingPosts;
    final isDark = FeedXpressoTheme.isDark(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(I18n.t(context, 'feed_trending')),
            pinned: true,
            floating: true,
          ),
          if (_loading && trendingPosts.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            ),
          if (!_loading && trendingPosts.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                icon: Icons.trending_up_outlined,
                title: 'No trending stories yet',
                subtitle: 'Check back later for what\'s trending.',
                buttonLabel: I18n.t(context, 'action_refresh'),
                onButtonTap: _loadTrending,
                dark: isDark,
              ),
            ),
          if (trendingPosts.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: NewsCard(post: trendingPosts[index]),
                  ),
                  childCount: trendingPosts.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
