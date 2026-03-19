import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/news_provider.dart';
import '../../services/socket_service.dart';
import '../../models/models.dart';
import '../../widgets/news_card.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../widgets/empty_state.dart';
import '../../constants.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});
  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scrollController = ScrollController();
  bool _showBanner = false;
  String? _bannerTitle;

  @override
  void initState() {
    super.initState();
    final p = context.read<NewsProvider>();
    p.loadCategories();
    p.refresh();

    SocketService.connect();
    SocketService.onNewPost((data) {
      if (mounted) {
        setState(() { _showBanner = true; _bannerTitle = data['title'] as String?; });
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) setState(() => _showBanner = false);
        });
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
        context.read<NewsProvider>().loadMore();
      }
    });
  }

  @override
  void dispose() { _scrollController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsProvider>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        showBack: false,
        title: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [GlassColors.accentGreen, Color(0xFF0F6E56)]),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.newspaper, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 9),
          Text(AppConstants.appName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: GlassColors.textPrimary)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: GlassColors.textSecondary), onPressed: () => showSearch(context: context, delegate: _SearchDelegate(provider))),
          IconButton(icon: const Icon(Icons.notifications_outlined, color: GlassColors.textSecondary), onPressed: () {}),
        ],
      ),
      body: Column(children: [
        // Live update banner
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _showBanner ? 42 : 0,
          child: _showBanner
              ? GlassBreakingBanner(
                  text: _bannerTitle != null ? 'New: $_bannerTitle' : 'New story published — tap to refresh',
                  onTap: () {
                    setState(() => _showBanner = false);
                    provider.refresh();
                    _scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
                  },
                )
              : const SizedBox.shrink(),
        ),

        // Category chips
        if (provider.categories.isNotEmpty)
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: provider.categories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, i) {
                if (i == 0) return GlassCategoryChip(label: 'All', icon: '📰', selected: provider.selectedCategoryId == null, onTap: () => provider.selectCategory(null));
                final cat = provider.categories[i - 1];
                return GlassCategoryChip(label: cat.name, icon: cat.icon, selected: provider.selectedCategoryId == cat.id, onTap: () => provider.selectCategory(cat.id));
              },
            ),
          ),

        Expanded(
          child: provider.refreshing
              ? const FeedShimmer()
              : provider.error != null
                  ? ErrorState(message: provider.error!, onRetry: provider.refresh)
                  : provider.posts.isEmpty
                      ? const EmptyState(icon: Icons.newspaper, title: 'No stories yet', subtitle: 'Check back soon.')
                      : RefreshIndicator(
                          onRefresh: provider.refresh,
                          color: GlassColors.accentGreenLight,
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: provider.posts.length + (provider.hasMore ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i == provider.posts.length) {
                                return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: GlassColors.accentGreenLight, strokeWidth: 2)));
                              }
                              return NewsCard(post: provider.posts[i]);
                            },
                          ),
                        ),
        ),
      ]),
    );
  }
}

class _SearchDelegate extends SearchDelegate<String> {
  final NewsProvider provider;
  _SearchDelegate(this.provider);

  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context).copyWith(
    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      hintStyle: TextStyle(color: GlassColors.textHint),
    ),
  );

  @override
  List<Widget> buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear, color: GlassColors.textSecondary), onPressed: () => query = '')];

  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: GlassColors.textSecondary), onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) => _Results(query: query, provider: provider);

  @override
  Widget buildSuggestions(BuildContext context) =>
      query.isEmpty ? const Center(child: Text('Search for news...', style: TextStyle(color: GlassColors.textHint))) : _Results(query: query, provider: provider);
}

class _Results extends StatefulWidget {
  final String query;
  final NewsProvider provider;
  const _Results({required this.query, required this.provider});
  @override
  State<_Results> createState() => _ResultsState();
}

class _ResultsState extends State<_Results> {
  bool _loading = true;

  @override
  void initState() { super.initState(); _search(); }

  @override
  void didUpdateWidget(_Results old) { super.didUpdateWidget(old); if (old.query != widget.query) _search(); }

  Future<void> _search() async {
    setState(() => _loading = true);
    await widget.provider.search(widget.query);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: GlassColors.accentGreenLight));
    final posts = widget.provider.posts;
    if (posts.isEmpty) return const EmptyState(icon: Icons.search_off, title: 'No results found');
    return ListView.builder(itemCount: posts.length, itemBuilder: (_, i) => NewsCard(post: posts[i], compact: true));
  }
}