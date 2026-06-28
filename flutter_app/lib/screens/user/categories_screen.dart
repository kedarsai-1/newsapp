import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../../services/api_service.dart';
import '../../utils/category_navigation.dart';
import '../../utils/i18n.dart';
import '../../widgets/categories/dailyhunt_category_card.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// Category discovery grid — 2-column emoji cards from API categories.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  static const List<String> _fallbackSlugs = [
    'business',
    'crime',
    'education',
    'entertainment',
    'general',
    'health',
    'local',
    'politics',
    'sports',
    'technology',
    'weather',
    'agriculture',
    'jobs',
  ];

  static const double _gridSpacing = 10;
  static const double _screenPadH = 16;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final news = context.read<NewsProvider>();
      if (news.categories.isEmpty) {
        news.loadCategories();
      }
    });
  }

  static String? _matchCategoryId(String slug, List<Category> api) {
    final s = slug.toLowerCase().trim();
    for (final c in api) {
      if (c.slug.toLowerCase().trim() == s) return c.id;
    }
    return null;
  }

  String _labelForSlug(BuildContext context, String slug, {String? apiName}) {
    final key = 'cat_$slug';
    final translated = I18n.t(context, key);
    if (translated != key) return translated;
    if (apiName != null && apiName.trim().isNotEmpty) return apiName.trim();
    return slug;
  }

  List<Category> _visibleCategories(NewsProvider news) {
    if (news.categories.isNotEmpty) {
      return [...news.categories]
        ..sort(
          (a, b) => _labelForSlug(context, a.slug, apiName: a.name)
              .toLowerCase()
              .compareTo(
                _labelForSlug(context, b.slug, apiName: b.name).toLowerCase(),
              ),
        );
    }
    return _fallbackSlugs
        .map(
          (slug) => Category(
            id: slug,
            name: slug,
            slug: slug,
            icon: '',
            color: '#1D9E75',
          ),
        )
        .toList();
  }

  Future<void> _openCategory(BuildContext context, String slug) async {
    final messenger = ScaffoldMessenger.of(context);
    final news = context.read<NewsProvider>();

    if (slug == 'sports' || slug == 'weather') {
      await openCategorySlug(context, slug, news: news);
      return;
    }

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
    if (width >= 1000) return 4;
    if (width >= 720) return 3;
    return 2;
  }

  double _childAspectRatio(double width, int columns) {
    final innerW = width - _screenPadH * 2 - _gridSpacing * (columns - 1);
    final cellW = innerW / columns;
    const cellH = 56.0;
    return cellW / cellH;
  }

  Future<void> _onRefresh() async {
    await context.read<NewsProvider>().loadCategories();
  }

  @override
  Widget build(BuildContext context) {
    final news = context.watch<NewsProvider>();
    final fx = FeedXpressoTheme.fx(context);
    final items = _visibleCategories(news);

    final w = MediaQuery.sizeOf(context).width;
    final columns = _crossAxisCount(w);
    final aspect = _childAspectRatio(w, columns);
    final loading = news.categories.isEmpty && news.categoriesError == null;

    return Scaffold(
      backgroundColor: fx.background,
      body: RefreshIndicator(
        color: fx.accent,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
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
                padding:
                    const EdgeInsets.fromLTRB(_screenPadH, 8, _screenPadH, 12),
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
            if (news.categoriesError != null && news.categories.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(_screenPadH, 0, _screenPadH, 8),
                  child: Material(
                    color: fx.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_off_rounded,
                              color: fx.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              news.categoriesError!,
                              style: TextStyle(
                                fontSize: 12,
                                color: fx.title,
                                height: 1.3,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _onRefresh,
                            child: Text(I18n.t(context, 'action_retry')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else
              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(_screenPadH, 0, _screenPadH, 0),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: _gridSpacing,
                    crossAxisSpacing: _gridSpacing,
                    childAspectRatio: aspect,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    childCount: items.length,
                    (context, index) {
                      final cat = items[index];
                      final slug = cat.slug.toLowerCase();
                      return DailyhuntCategoryCard.fromSlug(
                        slug: slug,
                        title: _labelForSlug(context, slug, apiName: cat.name),
                        emoji: cat.icon,
                        onTap: () => _openCategory(context, slug),
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
      ),
    );
  }
}
