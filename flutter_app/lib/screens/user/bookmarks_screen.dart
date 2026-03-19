// screens/user/bookmarks_screen.dart
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/news_card.dart';
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
    final res = await ApiService.getBookmarks();
    if (mounted) setState(() {
      if (res['success'] == true) {
        _bookmarks = (res['bookmarks'] as List).map((p) => NewsPost.fromJson(p)).toList();
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Stories')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bookmarks.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.bookmark_border, size: 60, color: AppColors.textHint),
                  SizedBox(height: 12),
                  Text('No saved stories yet', style: TextStyle(color: AppColors.textSecondary)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _bookmarks.length,
                    itemBuilder: (_, i) => NewsCard(post: _bookmarks[i]),
                  ),
                ),
    );
  }
}