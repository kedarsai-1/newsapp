import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/news_provider.dart';
import '../../services/api_service.dart';
import '../../utils/category_navigation.dart';
import '../../utils/i18n.dart';
import '../../widgets/feed/feed_xpresso_theme.dart';

/// Production-grade categories discovery screen with modern design.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  static const _sectionSlugs = {
    'headlines': ['politics', 'crime', 'local', 'general'],
    'lifestyle': ['entertainment', 'health', 'sports', 'education'],
    'work': ['business', 'technology', 'jobs', 'agriculture'],
    'other': ['weather'],
  };

  static const _accentMap = {
    'politics': [Color(0xFF8B5CF6), Color(0xFF6366F1)],
    'crime': [Color(0xFFEF4444), Color(0xFFDC2626)],
    'local': [Color(0xFF14B8A6), Color(0xFF06B6D4)],
    'general': [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    'entertainment': [Color(0xFFF59E0B), Color(0xFFEF4444)],
    'health': [Color(0xFF10B981), Color(0xFF059669)],
    'sports': [Color(0xFF3B82F6), Color(0xFF2563EB)],
    'education': [Color(0xFFF72585), Color(0xFFB5179E)],
    'business': [Color(0xFF00B4D8), Color(0xFF0077B6)],
    'technology': [Color(0xFF6366F1), Color(0xFF4F46E5)],
    'jobs': [Color(0xFF7209B7), Color(0xFF560BAD)],
    'agriculture': [Color(0xFF84CC16), Color(0xFF65A30D)],
    'weather': [Color(0xFF14B8A6), Color(0xFF0EA5E9)],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final news = context.read<NewsProvider>();
      if (news.categories.isEmpty) news.loadCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _matchCategoryId(String slug, List<Category> api) {
    final s = slug.toLowerCase().trim();
    final match = api.where((c) => c.slug.toLowerCase().trim() == s).toList();
    return match.map((c) => c.id).toList();
  }

  String _labelForSlug(BuildContext context, String slug, {String? apiName}) {
    final key = 'cat_$slug';
    final translated = I18n.t(context, key);
    if (translated != key) return translated;
    if (apiName != null && apiName.trim().isNotEmpty) return apiName.trim();
    return slug;
  }

  Future<void> _openCategory(BuildContext context, String slug) async {
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.of(context);
    final news = context.read<NewsProvider>();

    if (slug == 'sports' || slug == 'weather') {
      await openCategorySlug(context, slug, news: news);
      return;
    }

    String? id;
    final matches = _matchCategoryId(slug, news.categories);
    if (matches.isNotEmpty) {
      id = matches.first;
    }

    if (id == null || id.isEmpty) {
      await news.loadCategories();
      final retry = _matchCategoryId(slug, news.categories);
      if (retry.isNotEmpty) id = retry.first;
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
            'Could not open "${_labelForSlug(context, slug)}". Please try again.',
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

  Future<void> _onRefresh() async {
    await context.read<NewsProvider>().loadCategories();
  }

  List<_CategoryTile> _buildTiles(
      List<String> slugs, NewsProvider news, bool isApi) {
    final tiles = <_CategoryTile>[];
    for (final slug in slugs) {
      String name = _labelForSlug(context, slug);
      if (isApi) {
        final apiCat = news.categories
            .where((c) => c.slug.toLowerCase() == slug.toLowerCase())
            .toList();
        if (apiCat.isNotEmpty && apiCat.first.name.trim().isNotEmpty) {
          name = apiCat.first.name.trim();
        }
      }
      tiles.add(_CategoryTile(
        slug: slug,
        title: name,
        gradient: _accentMap[slug] ??
            [Theme.of(context).colorScheme.primary, Colors.purple],
      ));
    }
    return tiles;
  }

  @override
  Widget build(BuildContext context) {
    final news = context.watch<NewsProvider>();
    final fx = FeedXpressoTheme.fx(context);
    final loading = news.categories.isEmpty && news.categoriesError == null;
    final hasApiCategories = news.categories.isNotEmpty;

    // Build filtered sections
    final filtered = _searchQuery.trim().toLowerCase();
    List<_CategoryTile> allTiles = [];
    if (filtered.isNotEmpty) {
      final allSlugs = _sectionSlugs.values.expand((v) => v).toList();
      for (final slug in allSlugs) {
        final name = _labelForSlug(context, slug).toLowerCase();
        if (name.contains(filtered)) {
          allTiles.addAll(_buildTiles([slug], news, hasApiCategories));
        }
      }
    }

    return Scaffold(
      backgroundColor: fx.background,
      body: RefreshIndicator(
        color: fx.accent,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── Header ─────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              toolbarHeight: 52,
              backgroundColor: fx.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              expandedHeight: 0,
              foregroundColor: fx.title,
              title: Text(
                I18n.t(context, 'feed_categories'),
                style: GoogleFonts.notoSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: fx.title,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(height: 1, thickness: 1, color: fx.divider),
              ),
            ),

            // ── Hero Banner ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      fx.accent,
                      fx.accent.withValues(alpha: 0.7),
                      fx.accentTertiary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: fx.accent.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Background pattern
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Icon(
                        Icons.category_rounded,
                        size: 120,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    Positioned(
                      left: -10,
                      top: -10,
                      child: Icon(
                        Icons.grid_view_rounded,
                        size: 80,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.explore_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Explore Categories',
                                      style: GoogleFonts.notoSans(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        height: 1.2,
                                      ),
                                    ),
                                    Text(
                                      'Discover news that matters to you',
                                      style: GoogleFonts.notoSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withValues(alpha: 0.8),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Quick stats
                          Row(
                            children: [
                              _StatChip(
                                icon: Icons.newspaper_rounded,
                                label: '${news.categories.length} Topics',
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              _StatChip(
                                icon: Icons.language_rounded,
                                label: '7 Languages',
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Search Bar ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: fx.glassSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: fx.glassBorder,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: GoogleFonts.notoSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: fx.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search categories...',
                      hintStyle: GoogleFonts.notoSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: fx.textTertiary,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: fx.textTertiary,
                        size: 22,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: fx.textTertiary,
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Error Banner ───────────────────────────────────────
            if (news.categoriesError != null && news.categories.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: fx.errorSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: fx.errorBorder),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_off_rounded,
                            color: fx.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            news.categoriesError!,
                            style: TextStyle(fontSize: 12, color: fx.onErrorSurface),
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

            // ── Search Results ─────────────────────────────────────
            if (filtered.isNotEmpty)
              ..._buildSearchResults(allTiles),

            // ── Main Content ────────────────────────────────────────
            if (filtered.isEmpty) ...[
              if (loading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: fx.accent,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading categories...',
                            style: GoogleFonts.notoSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: fx.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else ...[
                // Section: Headlines
                _buildSection(
                  context,
                  title: 'Top Headlines',
                  subtitle: 'Politics, crime, local & more',
                  icon: Icons.newspaper_rounded,
                  slugs: _sectionSlugs['headlines']!,
                  news: news,
                  hasApi: hasApiCategories,
                  accentColor: fx.accent,
                  fx: fx,
                ),

                // Section: Lifestyle
                _buildSection(
                  context,
                  title: 'Lifestyle',
                  subtitle: 'Entertainment, health, sports & education',
                  icon: Icons.favorite_rounded,
                  slugs: _sectionSlugs['lifestyle']!,
                  news: news,
                  hasApi: hasApiCategories,
                  accentColor: fx.accentTertiary,
                  fx: fx,
                ),

                // Section: Work & Tech
                _buildSection(
                  context,
                  title: 'Work & Tech',
                  subtitle: 'Business, technology & career',
                  icon: Icons.work_rounded,
                  slugs: _sectionSlugs['work']!,
                  news: news,
                  hasApi: hasApiCategories,
                  accentColor: fx.accentSecondary,
                  fx: fx,
                ),

                // Section: Other
                _buildSection(
                  context,
                  title: 'Other',
                  subtitle: 'Weather and more',
                  icon: Icons.wb_sunny_rounded,
                  slugs: _sectionSlugs['other']!,
                  news: news,
                  hasApi: hasApiCategories,
                  accentColor: fx.info,
                  fx: fx,
                ),
              ],
            ],

            // Bottom padding
            SliverToBoxAdapter(
              child: SizedBox(
                height: FeedXpressoTheme.feedBottomInset(context) + 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSearchResults(List<_CategoryTile> tiles) {
    if (tiles.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.search_off_rounded,
                    size: 48, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 12),
                Text(
                  'No categories found',
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Try a different search term',
                  style: GoogleFonts.notoSans(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Icon(Icons.search_rounded,
                  size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                '${tiles.length} result${tiles.length == 1 ? '' : 's'}',
                style: GoogleFonts.notoSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _CategoryTileCard(
              tile: tiles[index],
              onTap: () => _openCategory(context, tiles[index].slug),
            ),
            childCount: tiles.length,
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
    ];
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<String> slugs,
    required NewsProvider news,
    required bool hasApi,
    required Color accentColor,
    required dynamic fx,
  }) {
    final tiles = _buildTiles(slugs, news, hasApi);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accentColor, accentColor.withValues(alpha: 0.7)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.notoSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: fx.title,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.notoSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: fx.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Category tiles grid
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.55,
                ),
                itemCount: tiles.length,
                itemBuilder: (context, index) {
                  final tile = tiles[index];
                  // Alternate between large (first) and normal cards
                  final isLarge = index == 0;
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 200 + index * 30),
                    curve: Curves.easeOutCubic,
                    child: isLarge
                        ? _CategoryTileLarge(
                            tile: tile,
                            onTap: () => _openCategory(context, tile.slug),
                          )
                        : _CategoryTileCard(
                            tile: tile,
                            onTap: () => _openCategory(context, tile.slug),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tile Models & Widgets ───────────────────────────────────────────────────

class _CategoryTile {
  final String slug;
  final String title;
  final List<Color> gradient;

  const _CategoryTile({
    required this.slug,
    required this.title,
    required this.gradient,
  });
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.notoSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTileCard extends StatefulWidget {
  final _CategoryTile tile;
  final VoidCallback onTap;

  const _CategoryTileCard({required this.tile, required this.onTap});

  @override
  State<_CategoryTileCard> createState() => _CategoryTileCardState();
}

class _CategoryTileCardState extends State<_CategoryTileCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final (start, end) = (widget.tile.gradient[0], widget.tile.gradient[1]);
    final icon = _iconForSlug(widget.tile.slug);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _isPressed ? 0.96 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                start.withValues(alpha: 0.12),
                end.withValues(alpha: 0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: start.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: start.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background icon watermark
              Positioned(
                right: -8,
                bottom: -8,
                child: Icon(
                  icon,
                  size: 56,
                  color: start.withValues(alpha: 0.06),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon badge
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [start, end],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: start.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    const Spacer(),
                    // Title
                    Text(
                      widget.tile.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: fx.title,
                        height: 1.2,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTileLarge extends StatefulWidget {
  final _CategoryTile tile;
  final VoidCallback onTap;

  const _CategoryTileLarge({required this.tile, required this.onTap});

  @override
  State<_CategoryTileLarge> createState() => _CategoryTileLargeState();
}

class _CategoryTileLargeState extends State<_CategoryTileLarge> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final fx = FeedXpressoTheme.fx(context);
    final (start, end) = (widget.tile.gradient[0], widget.tile.gradient[1]);
    final icon = _iconForSlug(widget.tile.slug);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _isPressed ? 0.96 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [start, end],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: start.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Watermark
              Positioned(
                right: -16,
                bottom: -16,
                child: Icon(icon, size: 80, color: Colors.white.withValues(alpha: 0.12)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                    const Spacer(),
                    Text(
                      widget.tile.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white.withValues(alpha: 0.8), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Explore',
                          style: GoogleFonts.notoSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconForSlug(String slug) {
  switch (slug.toLowerCase()) {
    case 'politics': return Icons.account_balance_rounded;
    case 'crime': return Icons.local_police_rounded;
    case 'local': return Icons.location_city_rounded;
    case 'general': return Icons.newspaper_rounded;
    case 'entertainment': return Icons.movie_rounded;
    case 'health': return Icons.favorite_rounded;
    case 'sports': return Icons.sports_soccer_rounded;
    case 'education': return Icons.school_rounded;
    case 'business': return Icons.trending_up_rounded;
    case 'technology': return Icons.computer_rounded;
    case 'jobs': return Icons.work_rounded;
    case 'agriculture': return Icons.agriculture_rounded;
    case 'weather': return Icons.wb_sunny_rounded;
    default: return Icons.article_rounded;
  }
}
