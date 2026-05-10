import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../providers/news_provider.dart';
import '../../../providers/super_home_provider.dart';
import '../../../theme/dailyhunt_theme.dart';
import '../../../widgets/dailyhunt/dailyhunt_feed_shimmer.dart';
import '../../../widgets/dailyhunt/dailyhunt_home_app_bar.dart';
import 'widgets/super_home_astrology.dart';
import 'widgets/super_home_cricket.dart';
import 'widgets/super_home_news_sections.dart';

/// Dailyhunt-style "super home" screen: vertically scrollable feed of multiple
/// sections (top stories, live cricket, astrology, entertainment, shorts,
/// local news, trending).
///
/// Each section is its own widget so it can be reordered, A/B tested, or
/// disabled in config without touching the rest of the layout.
class SuperHomeScreen extends StatefulWidget {
  const SuperHomeScreen({super.key});

  @override
  State<SuperHomeScreen> createState() => _SuperHomeScreenState();
}

class _SuperHomeScreenState extends State<SuperHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final news = context.read<NewsProvider>();
      final home = context.read<SuperHomeProvider>();
      home.ensureLoaded(
        language: news.selectedLanguage,
        categories: news.categories,
        city: news.preferredCity,
      );
    });
  }

  Future<void> _refresh() async {
    final news = context.read<NewsProvider>();
    final home = context.read<SuperHomeProvider>();
    await Future.wait([
      news.refresh(),
      home.refresh(
        language: news.selectedLanguage,
        categories: news.categories,
        city: news.preferredCity,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: DailyhuntTheme.overlay(context),
      child: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final home = context.watch<SuperHomeProvider>();
          final news = context.watch<NewsProvider>();
          final dividerColor = cs.onSurface.withValues(alpha: 0.06);

          return Scaffold(
            backgroundColor: const Color(0xFFF5F6F8),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DailyhuntHomeAppBar(
                  onProfileTap: () => context.push('/settings'),
                  onNotificationTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No new notifications'),
                        behavior: SnackBarBehavior.floating,
                        width: 320,
                        duration: Duration(milliseconds: 1200),
                      ),
                    );
                  },
                ),
                Divider(height: 1, thickness: 1, color: dividerColor),
                Expanded(
                  child: RefreshIndicator(
                    color: DailyhuntTheme.accentGreen,
                    edgeOffset: 8,
                    onRefresh: _refresh,
                    child: _SuperHomeBody(
                      home: home,
                      cityLabel: news.preferredCity,
                      onChangeCity: () => context.push('/settings'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SuperHomeBody extends StatelessWidget {
  final SuperHomeProvider home;
  final String? cityLabel;
  final VoidCallback onChangeCity;

  const _SuperHomeBody({
    required this.home,
    required this.cityLabel,
    required this.onChangeCity,
  });

  @override
  Widget build(BuildContext context) {
    if (!home.loadedOnce && home.refreshing) {
      return const _LoadingState();
    }
    if (home.isEmpty) {
      return _EmptyState(message: home.error);
    }

    final sections = <Widget>[
      const SizedBox(height: 12),
      if (home.topStories.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded,
                  color: Color(0xFFEF4444), size: 16),
              const SizedBox(width: 6),
              Text(
                'Top Stories',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        SuperHomeHeroRail(
          posts: home.topStories,
          onTap: (p) => context.push('/article/${p.id}'),
        ),
        const _SectionGap(),
      ],
      const SuperHomeCricketSection(),
      const _SectionGap(),
      SuperHomeTrendingSection(
        posts: home.trending,
        onSeeAll: () => context.push('/feed'),
      ),
      const _SectionGap(),
      SuperHomeEntertainmentSection(
        posts: home.entertainment,
        onSeeAll: () => context.push('/categories'),
      ),
      const _SectionGap(),
      const SuperHomeAstrologySection(),
      const _SectionGap(),
      SuperHomeShortsSection(
        posts: home.shorts,
        onSeeAll: () => context.push('/shorts'),
      ),
      const _SectionGap(),
      SuperHomeLocalSection(
        posts: home.local,
        cityLabel: cityLabel,
        onChangeCity: onChangeCity,
        onSeeAll: () => context.push('/feed'),
      ),
      const SizedBox(height: 28),
    ];

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.zero,
      itemCount: sections.length,
      itemBuilder: (_, i) => sections[i],
    );
  }
}

class _SectionGap extends StatelessWidget {
  const _SectionGap();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 14),
        Container(height: 8, color: const Color(0xFFEEF0F3)),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.only(top: 8),
      child: DailyhuntFeedShimmer(itemCount: 4),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String? message;
  const _EmptyState({this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
        const Center(
          child: Icon(Icons.cloud_off_rounded,
              size: 56, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            message ?? 'Could not load the home feed.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'Pull down to refresh.',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}
