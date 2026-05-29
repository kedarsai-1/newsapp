import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ReporterProvider extends ChangeNotifier {
  List<NewsPost> _myPosts = [];
  Map<String, dynamic>? _stats;
  NewsPost? _editingPost;
  bool _loading = false;
  String? _error;

  List<NewsPost> get myPosts => _myPosts;
  Map<String, dynamic>? get stats => _stats;
  NewsPost? get editingPost => _editingPost;
  bool get loading => _loading;
  String? get error => _error;

  int get pendingCount => _myPosts.where((p) => p.status == 'pending').length;
  int get approvedCount => _myPosts.where((p) => p.status == 'approved').length;
  int get rejectedCount => _myPosts.where((p) => p.status == 'rejected').length;
  int get draftCount => _myPosts.where((p) => p.status == 'draft').length;

  void reset() {
    _myPosts = [];
    _stats = null;
    _editingPost = null;
    _loading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> loadMyPosts({String? status}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.getMyPosts(status: status);
      if (res['success'] == true) {
        _myPosts = (res['posts'] as List)
            .map((p) => NewsPost.fromJson(p))
            .toList();
      } else {
        _error = res['message'];
      }
    } catch (e) {
      _error = 'Failed to load posts.';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadStats() async {
    try {
      final res = await ApiService.getReporterStats();
      if (res['success'] == true) {
        _stats = res['stats'];
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<NewsPost?> loadPostForEdit(String postId) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final cached = _myPosts.where((p) => p.id == postId).firstOrNull;
      if (cached != null) {
        _editingPost = cached;
        _loading = false;
        notifyListeners();
        return cached;
      }
      final res = await ApiService.getMyPosts();
      if (res['success'] == true) {
        final posts = (res['posts'] as List)
            .map((p) => NewsPost.fromJson(p))
            .toList();
        _myPosts = posts;
        _editingPost = posts.where((p) => p.id == postId).firstOrNull;
        if (_editingPost == null) {
          _error = 'Post not found.';
        }
      } else {
        _error = res['message'];
      }
    } catch (_) {
      _error = 'Failed to load post.';
    }
    _loading = false;
    notifyListeners();
    return _editingPost;
  }

  Future<bool> submitPost({
    required String title,
    required String body,
    String? summary,
    required String categoryId,
    double? latitude,
    double? longitude,
    List<String> tags = const [],
    List<XFile> mediaFiles = const [],
    bool isDraft = false,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.createPost(
        title: title,
        body: body,
        summary: summary,
        categoryId: categoryId,
        latitude: latitude,
        longitude: longitude,
        tags: tags,
        mediaFiles: mediaFiles,
        isDraft: isDraft,
      );
      _loading = false;
      if (res['success'] == true) {
        await loadMyPosts();
        await loadStats();
        return true;
      }
      _error = res['message'];
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Submission failed. Check your connection.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePost({
    required String postId,
    required String title,
    required String body,
    String? summary,
    required String categoryId,
    List<String> tags = const [],
    List<XFile> mediaFiles = const [],
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.updatePost(
        postId: postId,
        title: title,
        body: body,
        summary: summary,
        categoryId: categoryId,
        tags: tags,
        mediaFiles: mediaFiles,
      );
      _loading = false;
      if (res['success'] == true) {
        _editingPost = null;
        await loadMyPosts();
        await loadStats();
        return true;
      }
      _error = res['message'];
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Update failed. Check your connection.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteMedia({
    required String postId,
    required String mediaId,
  }) async {
    try {
      final res = await ApiService.deletePostMedia(
        postId: postId,
        mediaId: mediaId,
      );
      if (res['success'] == true) {
        await loadPostForEdit(postId);
        return true;
      }
      _error = res['message'];
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Failed to remove media.';
      notifyListeners();
      return false;
    }
  }
}
