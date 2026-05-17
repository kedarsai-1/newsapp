import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../../services/api_service.dart';
import '../../utils/i18n.dart';
import '../../widgets/categories/dailyhunt_category_card.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// Discovery grid — theme-aware Xpresso layout.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const List<_DiscoveryCategory> _topics = [
    _DiscoveryCategory('politics', 'cat_politics', Icons.how_to_vote_rounded),
    _DiscoveryCategory('sports', 'cat_sports', Icons.sports_soccer_rounded),
    _DiscoveryCategory(
        'entertainment', 'cat_entertainment', Icons.movie_creation_rounded),
    _DiscoveryCategory('technology', 'cat_technology', Icons.memory_rounded),
    _DiscoveryCategory('business', 'cat_business', Icons.business_center_rounded),
    _DiscoveryCategory('local', 'cat_local', Icons.location_city_rounded),
    _DiscoveryCategory('health', 'cat_health', Icons.favorite_rounded),
    _DiscoveryCategory('education', 'cat_education', Icons.school_rounded),
  ];

  static const double _gridSpacing = 8;
  static const double _screenPadH = 14;

  static String? _matchCategoryId(String slug, List<Category> api) {
    final s = slug.toLowerCase().trim();
    for (final c in api) {
      if (c.slug.toLowerCase().trim() == s) return c.id;
    }
    return null;
  }

  String _labelForSlug(BuildContext context, String slug) {
    for (final t in _topics) {
      if (t.slug == slug) return I18n.t(context, t.i18nKey);
    }
    return slug;
  }

  Future<void> _openCategory(BuildContext context, String slug) async {
    final messenger = ScaffoldMessenger.of(context);
    final news = context.read<NewsProvider>();

    String? id = _matchCategoryId(slug, news.categories);

    if (id == null || id.isEmpty) {
      await news.loadCategories();
      id = _matchCategoryId(slug, news.categories);
    }

    if (id == null || id.isEmpty) {
      final data = await ApiService.getCategoryBySlug(slug);
      if (data['success'] == true && data['category'] is Map) {
        try {
          final c = Category.fromJson(
            Map<String, dynamic>.from(data['category'] as Map),
          );
          if (c.id.isNotEmpty) {
            news.mergeCategory(c);
            id = c.id;
          }
        } catch (_) {}
      }
    }

    if (id == null || id.isEmpty) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            news.categoriesError != null && news.categories.isEmpty
                ? 'Categories could not load. Pull to refresh on Home or check the server.'
                : '“${_labelForSlug(context, slug)}” was not found. Run npm run seed on the API or create this category.',
          ),
          behavior: SnackBarBehavior.floating,
          width: 360,
        ),
      );
      return;
    }
    await news.selectCategory(id);
    if (context.mounted) context.go('/feed');
  }

  int _crossAxisCount(double width) {
    if (width >= 1000) return 5;
    if (width >= 720) return 4;
    if (width >= 480) return 3;
    return 3;
  }

  double _childAspectRatio(double width, int columns) {
    final innerW = width - _screenPadH * 2 - _gridSpacing * (columns - 1);
    final cellW = innerW / columns;
    const cellH = 46.0;
    return cellW / cellH;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<NewsProvider>();
    final fx = FeedXpressoTheme.fx(context);

    final w = MediaQuery.sizeOf(context).width;
    final columns = _crossAxisCount(w);
    final aspect = _childAspectRatio(w, columns);

    return Scaffold(
      backgroundColor: fx.background,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            toolbarHeight: 46,
            backgroundColor: fx.background,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            foregroundColor: fx.title,
            iconTheme: IconThemeData(color: fx.iconFg),
            title: Text(
              I18n.t(context, 'feed_categories'),
              style: fx.screenTitleStyle.copyWith(fontSize: 18),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: fx.divider),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(_screenPadH, 8, _screenPadH, 10),
              child: Text(
                I18n.t(context, 'categories_subtitle'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  color: fx.summary,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(_screenPadH, 0, _screenPadH, 0),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: _gridSpacing,
                crossAxisSpacing: _gridSpacing,
                childAspectRatio: aspect,
              ),
              delegate: SliverChildBuilderDelegate(
                childCount: _topics.length,
                (context, index) {
                  final t = _topics[index];
                  return DailyhuntCategoryCard(
                    title: I18n.t(context, t.i18nKey),
                    icon: t.icon,
                    onTap: () => _openCategory(context, t.slug),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: FeedXpressoTheme.feedBottomInset(context)),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryCategory {
  final String slug;
  final String i18nKey;
  final IconData icon;

  const _DiscoveryCategory(this.slug, this.i18nKey, this.icon);
}
