import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../constants.dart';

class NewsProvider extends ChangeNotifier {
  List<NewsPost> _posts = [];
  List<Category> _categories = [];
  String? _selectedCategoryId;
  String? _searchQuery;
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  bool _refreshing = false;
  String? _error;

  List<NewsPost> get posts => _posts;
  List<Category> get categories => _categories;
  String? get selectedCategoryId => _selectedCategoryId;
  bool get loading => _loading;
  bool get refreshing => _refreshing;
  bool get hasMore => _hasMore;
  String? get error => _error;

  Future<void> loadCategories() async {
    _categories = await ApiService.getCategories();
    notifyListeners();
  }

  Future<void> refresh() async {
    _refreshing = true;
    _error = null;
    _page = 1;
    _hasMore = true;
    notifyListeners();
    await _fetchPosts(reset: true);
    _refreshing = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;
    notifyListeners();
    await _fetchPosts(reset: false);
    _loading = false;
    notifyListeners();
  }

  Future<void> selectCategory(String? categoryId) async {
    _selectedCategoryId = categoryId;
    _searchQuery = null;
    await refresh();
  }

  Future<void> search(String query) async {
    _searchQuery = query.isEmpty ? null : query;
    _selectedCategoryId = null;
    await refresh();
  }

  Future<void> _fetchPosts({required bool reset}) async {
    try {
      final res = await ApiService.getFeed(
        page: reset ? 1 : _page,
        categoryId: _selectedCategoryId,
        search: _searchQuery,
      );
      if (res['success'] == true) {
        final fetched = (res['posts'] as List)
            .map((p) => NewsPost.fromJson(p))
            .toList();
        if (reset) {
          _posts = fetched;
          _page = 2;
        } else {
          _posts.addAll(fetched);
          _page++;
        }
        _hasMore = fetched.length == AppConstants.pageSize;
        _error = null;
      } else {
        _error = res['message'];
      }
    } catch (e) {
      _error = 'Failed to load news. Check your connection.';
    }
  }

  // Update a single post in the list (e.g. after like/bookmark)
  void updatePost(String postId, {int? likes, bool? liked}) {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    // Posts are immutable — rebuild with updated values via fromJson
    notifyListeners();
  }
}