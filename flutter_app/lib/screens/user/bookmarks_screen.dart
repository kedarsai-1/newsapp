// screens/user/bookmarks_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/news_card.dart';
import '../../widgets/news_shimmer_loader.dart';
import '../../constants.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<NewsPost> _bookmarks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loggedIn = context.read<AuthProvider>().isLoggedIn;
    if (!loggedIn) {
      final guest = await ApiService.getGuestBookmarks();
      if (!mounted) return;
      setState(() {
        _bookmarks = guest;
        _loading = false;
      });
      return;
    }

    final res = await ApiService.getBookmarks();
    if (!mounted) return;
    setState(() {
      if (res['success'] == true) {
        _bookmarks = (res['bookmarks'] as List).map((p) => NewsPost.fromJson(p)).toList();
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Stories')),
      body: _loading
          ? const NewsShimmerLoader(count: 6)
          : _bookmarks.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.bookmark_border, size: 60, color: p.textHint),
                  const SizedBox(height: 12),
                  Text('No saved stories yet', style: TextStyle(color: p.textSecondary)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _bookmarks.length,
                    itemBuilder: (_, i) {
                      final post = _bookmarks[i];
                      return Dismissible(
                        key: ValueKey('bm-${post.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 22),
                          color: context.palette.error.withValues(alpha: 0.9),
                          child: const Icon(Icons.bookmark_remove_rounded,
                              color: Colors.white, size: 28),
                        ),
                        confirmDismiss: (_) async {
                          final loggedIn =
                              context.read<AuthProvider>().isLoggedIn;
                          if (loggedIn) {
                            final res =
                                await ApiService.toggleBookmark(post.id);
                            return res['success'] == true;
                          }
                          await ApiService.toggleGuestBookmark(post);
                          return true;
                        },
                        onDismissed: (_) {
                          setState(() => _bookmarks.removeAt(i));
                        },
                        child: NewsCard(post: post),
                      );
                    },
                  ),
                ),
    );
  }
}