import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/dailyhunt_theme.dart';
import '../../widgets/dailyhunt/dailyhunt_category_tab_bar.dart';
import '../../widgets/dailyhunt/dailyhunt_feed_card.dart';
import '../../widgets/dailyhunt/dailyhunt_feed_shimmer.dart';
import '../../widgets/dailyhunt/dailyhunt_home_app_bar.dart';

/// Demo feed item for UI-only home (replace with API models later).
class DailyhuntFeedItem {
  final String id;
  final String imageUrl;
  final String headline;
  final String summary;
  final String sourceName;
  final DateTime publishedAt;
  final int likeCount;

  const DailyhuntFeedItem({
    required this.id,
    required this.imageUrl,
    required this.headline,
    required this.summary,
    required this.sourceName,
    required this.publishedAt,
    this.likeCount = 0,
  });
}

/// Material 3 light home: Dailyhunt-inspired chrome, categories, and card feed.
class DailyhuntHomeScreen extends StatefulWidget {
  const DailyhuntHomeScreen({super.key});

  static const List<String> categories = [
    'Top News',
    'Politics',
    'Sports',
    'Entertainment',
    'Technology',
    'Local',
    'Business',
  ];

  @override
  State<DailyhuntHomeScreen> createState() => _DailyhuntHomeScreenState();
}

class _DailyhuntHomeScreenState extends State<DailyhuntHomeScreen> {
  int _categoryIndex = 0;
  bool _loading = true;
  final Map<String, bool> _liked = {};
  final Map<String, bool> _bookmarked = {};

  @override
  void initState() {
    super.initState();
    _simulateLoad();
  }

  Future<void> _simulateLoad() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _onRefresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted) setState(() {});
  }

  void _onCategoryChanged(int i) {
    if (i == _categoryIndex) return;
    setState(() => _categoryIndex = i);
    _simulateLoad();
  }

  List<DailyhuntFeedItem> _itemsForCategory(int i) {
    final tag = DailyhuntHomeScreen.categories[i]
        .toLowerCase()
        .replaceAll(' ', '');
    return List<DailyhuntFeedItem>.generate(10, (j) {
      final id = '$tag-$j';
      final seed = '${tag}_$j'.hashCode.abs();
      return DailyhuntFeedItem(
        id: id,
        imageUrl: 'https://picsum.photos/seed/$seed/960/540',
        headline: _headline(i, j),
        summary: _summary(i, j),
        sourceName: _source(j),
        publishedAt: DateTime.now().subtract(Duration(minutes: j * 13 + 7)),
        likeCount: 40 + (seed % 1200) + j * 3,
      );
    });
  }

  String _headline(int cat, int j) {
    switch (cat) {
      case 1:
        return 'Assembly session: key bills tabled as opposition stages walkout • Update ${j + 1}';
      case 2:
        return 'Championship finals: injury-time goal seals historic win for the hosts';
      case 3:
        return 'Box office: regional cinema crosses milestone as streaming rights heat up';
      case 4:
        return 'Gadget roundup: flagship phones push AI features; buyers weigh battery life';
      case 5:
        return 'City bulletin: traffic diversions and metro timings for the weekend';
      case 6:
        return 'Markets wrap: indices edge higher; investors eye inflation data next week';
      default:
        if (j.isEven) {
          return 'హోమ్ స్క్రీన్ డెమో: స్థానిక భాషతో శీర్షికలు స్పష్టంగా కనిపిస్తాయి';
        }
        return 'Breaking: policy shift signals faster rollout for urban infrastructure projects';
    }
  }

  String _summary(int cat, int j) {
    return 'Short context lines for the story body so the card shows two or three lines '
        'like a typical news app feed. Category slot ${cat + 1}, item ${j + 1}. '
        'Tap the card for details once wired to your router.';
  }

  String _source(int j) {
    const names = ['ANI', 'PTI', 'Reuters', 'Local Bureau', 'TechWire', 'City Post'];
    return names[j % names.length];
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: DailyhuntTheme.overlay(context),
      child: Builder(
        builder: (context) {
          final items = _itemsForCategory(_categoryIndex);
          final dividerColor = Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.07);
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
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
                        duration: Duration(milliseconds: 1400),
                      ),
                    );
                  },
                ),
                Divider(height: 1, thickness: 1, color: dividerColor),
                DailyhuntCategoryTabBar(
                  categories: DailyhuntHomeScreen.categories,
                  selectedIndex: _categoryIndex,
                  onSelected: _onCategoryChanged,
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.06),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: DailyhuntTheme.accentGreen,
                    edgeOffset: 8,
                    onRefresh: _onRefresh,
                    child: _loading
                        ? const SingleChildScrollView(
                            physics: AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            child: DailyhuntFeedShimmer(itemCount: 6),
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.only(top: 8, bottom: 20),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final s = items[index];
                              final liked = _liked[s.id] ?? false;
                              final bookmarked = _bookmarked[s.id] ?? false;
                              return DailyhuntFeedCard(
                                imageUrl: s.imageUrl,
                                headline: s.headline,
                                summary: s.summary,
                                sourceName: s.sourceName,
                                publishedAt: s.publishedAt,
                                likeCount: s.likeCount,
                                liked: liked,
                                bookmarked: bookmarked,
                                onTap: () {},
                                onLike: () =>
                                    setState(() => _liked[s.id] = !liked),
                                onShare: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Share sheet (wire up)'),
                                      behavior: SnackBarBehavior.floating,
                                      width: 320,
                                    ),
                                  );
                                },
                                onBookmark: () => setState(
                                  () => _bookmarked[s.id] = !bookmarked,
                                ),
                              );
                            },
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
