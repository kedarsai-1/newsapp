import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/dailyhunt/dailyhunt_category_tab_bar.dart';
import '../../widgets/dailyhunt/dailyhunt_feed_card.dart';
import '../../widgets/dailyhunt/dailyhunt_feed_shimmer.dart';
import '../../widgets/dailyhunt/dailyhunt_home_app_bar.dart';
import '../../widgets/dailyhunt/xpresso_side_menu.dart';
import '../../widgets/feed/feed_list_tuning.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

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
    final fx = FeedXpressoTheme.fx(context);
    final items = _itemsForCategory(_categoryIndex);
    return Scaffold(
      backgroundColor: fx.background,
      body: Column(
        children: [
          // Header with glass morphism effect
          Container(
            decoration: BoxDecoration(
              color: fx.glassSurface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border.all(color: fx.glassBorder, width: 1),
            ),
            child: Column(
              children: [
                // Header content
                DailyhuntHomeAppBar(
                  onProfileTap: () => XpressoSideMenu.open(context),
                  onNotificationTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'No new notifications',
                          style: GoogleFonts.notoSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: fx.title,
                          ),
                        ),
                        behavior: SnackBarBehavior.floating,
                        width: 280,
                        backgroundColor: fx.surfaceElevated,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: fx.divider, width: 0.5),
                        ),
                        duration: const Duration(milliseconds: 1400),
                      ),
                    );
                  },
                ),
                // Category Tab Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: fx.glassSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: fx.glassBorder, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: fx.accent.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: DailyhuntCategoryTabBar(
                      categories: DailyhuntHomeScreen.categories,
                      selectedIndex: _categoryIndex,
                      onSelected: _onCategoryChanged,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),

          // Content area
          Expanded(
            child: ColoredBox(
              color: fx.background,
              child: RefreshIndicator(
                color: fx.accent,
                backgroundColor: fx.surfaceElevated,
                edgeOffset: 4,
                onRefresh: _onRefresh,
                child: _loading
                    ? SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: List.generate(6, (index) =>
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: fx.glassSurface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: fx.glassBorder, width: 1),
                                  ),
                                  height: 200,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        cacheExtent: 1000,
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final s = items[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DailyhuntFeedCard(
                              key: ValueKey(s.id),
                              imageUrl: s.imageUrl,
                              headline: s.headline,
                              summary: s.summary,
                              sourceName: s.sourceName,
                              publishedAt: s.publishedAt,
                              likeCount: s.likeCount,
                              onTap: () {},
                              onShare: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Share functionality coming soon',
                                      style: GoogleFonts.notoSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: fx.title,
                                      ),
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    width: 280,
                                    backgroundColor: fx.surfaceElevated,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: fx.divider, width: 0.5),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
