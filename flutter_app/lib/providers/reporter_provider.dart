import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ReporterProvider extends ChangeNotifier {
  List<NewsPost> _myPosts = [];
  Map<String, dynamic>? _stats;
  bool _loading = false;
  String? _error;

  List<NewsPost> get myPosts => _myPosts;
  Map<String, dynamic>? get stats => _stats;
  bool get loading => _loading;
  String? get error => _error;

  int get pendingCount => _myPosts.where((p) => p.status == 'pending').length;
  int get approvedCount => _myPosts.where((p) => p.status == 'approved').length;
  int get rejectedCount => _myPosts.where((p) => p.status == 'rejected').length;
  int get draftCount => _myPosts.where((p) => p.status == 'draft').length;

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
        await loadMyPosts();  // refresh list
        return true;
      } else {
        _error = res['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Submission failed. Check your connection.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }
}