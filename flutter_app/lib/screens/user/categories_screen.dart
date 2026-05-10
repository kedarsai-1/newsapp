import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../../services/api_service.dart';
import '../../theme/dailyhunt_theme.dart';
import '../../utils/i18n.dart';
import '../../widgets/categories/dailyhunt_category_card.dart';

/// Dailyhunt-inspired topic grid: light theme, green accent, compact rounded cards.
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

  Future<void> _openCategory(
    BuildContext context,
    String slug,
  ) async {
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
    if (width >= 1100) return 4;
    if (width >= 720) return 3;
    return 2;
  }

  double _childAspectRatio(double width) {
    // Slightly taller cards on narrow phones for touch targets.
    if (width < 360) return 0.78;
    if (width < 480) return 0.85;
    return 0.92;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<NewsProvider>(); // rebuild when categories load

    return Theme(
      data: DailyhuntTheme.overlay(context),
      child: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final w = MediaQuery.sizeOf(context).width;
          final pad = w >= 720 ? 20.0 : 14.0;
          final n = _crossAxisCount(w);
          final aspect = _childAspectRatio(w);

          return Scaffold(
            backgroundColor: cs.surface,
            body: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  toolbarHeight: 52,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  shadowColor: Colors.black.withValues(alpha: 0.06),
                  title: Text(
                    I18n.t(context, 'feed_categories'),
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(pad, 4, pad, 10),
                    child: Text(
                      I18n.t(context, 'categories_subtitle'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.58),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            height: 1.35,
                          ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, 0, pad, 24),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: n,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: aspect,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      childCount: _topics.length,
                      (context, index) {
                        final t = _topics[index];
                        return DailyhuntCategoryCard(
                          title: I18n.t(context, t.i18nKey),
                          icon: t.icon,
                          onTap: () async => _openCategory(context, t.slug),
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.paddingOf(context).bottom + 88,
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

class _DiscoveryCategory {
  final String slug;
  final String i18nKey;
  final IconData icon;

  const _DiscoveryCategory(this.slug, this.i18nKey, this.icon);
}
