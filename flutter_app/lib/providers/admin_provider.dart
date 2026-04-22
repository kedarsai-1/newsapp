import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AdminProvider extends ChangeNotifier {
  Map<String, dynamic>? _dashboardStats;
  List<NewsPost> _pendingPosts = [];
  List<NewsPost> _recentActivity = [];
  List<User> _users = [];
  Map<String, dynamic>? _ingestionStatus;
  Map<String, dynamic>? _lastIngestionStats;
  bool _ingestionLoading = false;
  bool _loading = false;
  String? _error;

  Map<String, dynamic>? get dashboardStats => _dashboardStats;
  List<NewsPost> get pendingPosts => _pendingPosts;
  List<NewsPost> get recentActivity => _recentActivity;
  List<User> get users => _users;
  Map<String, dynamic>? get ingestionStatus => _ingestionStatus;
  Map<String, dynamic>? get lastIngestionStats => _lastIngestionStats;
  bool get ingestionLoading => _ingestionLoading;
  bool get loading => _loading;
  String? get error => _error;
  int get pendingCount => _pendingPosts.length;

  Future<void> loadDashboard() async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getDashboard();
      if (res['success'] == true) {
        _dashboardStats = res['stats'];
        _recentActivity = (res['recentActivity'] as List? ?? [])
            .map((p) => NewsPost.fromJson(p))
            .toList();
        _error = null;
      }
    } catch (e) {
      _error = 'Failed to load dashboard.';
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadPendingPosts() async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getPendingPosts();
      if (res['success'] == true) {
        _pendingPosts = (res['posts'] as List)
            .map((p) => NewsPost.fromJson(p))
            .toList();
        _error = null;
      }
    } catch (e) {
      _error = 'Failed to load pending posts.';
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> approvePost(String id, {bool isBreaking = false, bool isFeatured = false}) async {
    try {
      final res = await ApiService.approvePost(id, isBreaking: isBreaking, isFeatured: isFeatured);
      if (res['success'] == true) {
        _pendingPosts.removeWhere((p) => p.id == id);
        if (_dashboardStats != null) {
          _dashboardStats!['pendingPosts'] =
              (_dashboardStats!['pendingPosts'] as int) - 1;
          _dashboardStats!['approvedToday'] =
              (_dashboardStats!['approvedToday'] as int) + 1;
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectPost(String id, String reason) async {
    try {
      final res = await ApiService.rejectPost(id, reason);
      if (res['success'] == true) {
        _pendingPosts.removeWhere((p) => p.id == id);
        if (_dashboardStats != null) {
          _dashboardStats!['pendingPosts'] =
              (_dashboardStats!['pendingPosts'] as int) - 1;
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadUsers({String? role}) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await ApiService.getUsers(role: role);
      if (res['success'] == true) {
        _users = (res['users'] as List).map((u) => User.fromJson(u)).toList();
        _error = null;
      }
    } catch (e) {
      _error = 'Failed to load users.';
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> updateUserRole(String userId, String role) async {
    try {
      final res = await ApiService.updateUserRole(userId, role);
      if (res['success'] == true) {
        final index = _users.indexWhere((u) => u.id == userId);
        if (index != -1) {
          _users[index] = User.fromJson(res['user']);
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleUserActive(String userId) async {
    try {
      final res = await ApiService.toggleUserActive(userId);
      if (res['success'] == true) {
        final index = _users.indexWhere((u) => u.id == userId);
        if (index != -1) {
          _users[index] = User.fromJson(res['user']);
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadIngestionStatus() async {
    try {
      final res = await ApiService.getIngestionStatus();
      if (res['success'] == true) {
        _ingestionStatus = res['status'] as Map<String, dynamic>?;
        _error = null;
        notifyListeners();
      }
    } catch (_) {
      // no-op, status polling should fail silently in UI
    }
  }

  Future<Map<String, dynamic>> runIngestionNow() async {
    _ingestionLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.runIngestionNow();
      if (res['success'] == true) {
        _lastIngestionStats = res['stats'] as Map<String, dynamic>?;
        await Future.wait([loadPendingPosts(), loadIngestionStatus()]);
      } else {
        await loadIngestionStatus();
      }
      return res;
    } catch (e) {
      return {'success': false, 'message': 'Failed to start ingestion.'};
    } finally {
      _ingestionLoading = false;
      notifyListeners();
    }
  }
}