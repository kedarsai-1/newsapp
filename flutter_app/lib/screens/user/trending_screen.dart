import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../models/models.dart';
import '../providers/news_provider.dart';
import '../utils/i18n.dart';
import '../widgets/feed/feed_xpresso_theme.dart';
import '../widgets/feed/feed_xpresso_palette.dart';
import '../widgets/shimmer_widgets.dart';
import '../widgets/empty_state.dart';
import '../widgets/location_label.dart';
import '../helpers/widgets/news_card.dart';
import '../utils/theme_utils.dart';

/// Trending topics page showing all trending stories in a vertical list
class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    final provider = context.read<NewsProvider>();
    await provider.loadFeedHighlights();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsProvider>();
    final trendingPosts = provider.trendingPosts;
    final loading = provider.loadingHighlights;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(I18n.t(context, 'feed_trending')),
            pinned: true,
            floating: true,
          ),
          if (loading && trendingPosts.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            ),
          if (!loading && trendingPosts.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                icon: Icons.trending_up_outlined,
                title: 'No trending stories yet',
                subtitle: 'Check back later for what\'s trending.',
                buttonLabel: I18n.t(context, 'action_refresh'),
                onButtonTap: _loadTrending,
                dark: ThemeUtils.isDarkMode(context),
              ),
            ),
          if (trendingPosts.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = trendingPosts[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: NewsCard(
                        post: post,
                        onTap: () => _openPost(post),
                      ),
                    );
                  },
                  childCount: trendingPosts.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openPost(NewsPost post) {
    context.read<NewsProvider>().openPost(post, context);
  }
}
