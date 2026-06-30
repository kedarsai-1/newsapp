import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/publisher_follow_service.dart';
import '../services/bookmark_migration_service.dart';
import '../services/push_notifications.dart';
import '../constants.dart';

/// Secure storage for sensitive user data.
/// Falls back to in-memory only on web.
class _SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static Future<String?> read(String key) async {
    if (kIsWeb) return null;
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String key, String value) async {
    if (kIsWeb) return;
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {}
  }

  static Future<void> delete(String key) async {
    if (kIsWeb) return;
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _loading = false;
  bool _initialized = false;
  String? _error;

  User? get user => _user;
  bool get loading => _loading;
  bool get initialized => _initialized;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isReporter => _user?.isReporter ?? false;

  // Called once at app start — reads cached user from secure storage
  Future<void> init() async {
    await ApiService.loadToken();
    final userData = await _SecureStorage.read(AppConstants.userKey);
    if (userData != null) {
      try {
        _user = User.fromJson(jsonDecode(userData));
      } catch (_) {
        _user = null;
      }
    }
    _initialized = true;
    notifyListeners();

    // Refresh from server in background (non-blocking)
    if (_user != null) {
      try {
        final res = await ApiService.getMe();
        if (res['success'] == true) {
          _user = User.fromJson(res['user']);
          await _saveUser(_user!);
          await PushNotifications.syncAfterLogin();
          notifyListeners();
        } else {
          // Only force logout on auth failures (401/403). Treat other errors as transient.
          final sc = res['statusCode'];
          final statusCode = sc is int ? sc : int.tryParse('$sc');
          if (statusCode == 401 || statusCode == 403) {
            await logout();
          }
        }
      } catch (_) {
        // Network error — keep cached user, don't force logout
      }
    }
  }

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.login(email, password);
      if (res['success'] == true) {
        await ApiService.saveToken(res['token']);
        _user = User.fromJson(res['user']);
        await _saveUser(_user!);
        await PublisherFollowService.migrateGuestFollowsToServer();
        await BookmarkMigrationService.migrateGuestBookmarksToServer();
        await PushNotifications.syncAfterLogin();
        _loading = false;
        notifyListeners();
        return true;
      } else {
        _error = res['message'] ?? 'Login failed.';
        _loading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Connection error. Check your network.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.register(
        name: name, email: email,
        password: password, role: role, phone: phone,
      );
      if (res['success'] == true) {
        await ApiService.saveToken(res['token']);
        _user = User.fromJson(res['user']);
        await _saveUser(_user!);
        await PublisherFollowService.migrateGuestFollowsToServer();
        await BookmarkMigrationService.migrateGuestBookmarksToServer();
        await PushNotifications.syncAfterLogin();
        _loading = false;
        notifyListeners();
        return true;
      } else {
        _error = res['message'] ?? 'Registration failed.';
        _loading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Connection error. Check your network.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await PushNotifications.clearOnLogout();
    await ApiService.clearToken();
    _user = null;
    notifyListeners();
  }

  Future<bool> updateProfile({String? name, String? phone, String? bio}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiService.updateProfile(
        name: name,
        phone: phone,
        bio: bio,
      );
      if (res['success'] == true && res['user'] is Map) {
        _user = User.fromJson(Map<String, dynamic>.from(res['user'] as Map));
        await _saveUser(_user!);
        _loading = false;
        notifyListeners();
        return true;
      }
      _error = res['message']?.toString() ?? 'Could not update profile.';
      _loading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Connection error. Check your network.';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  // Used by OTP auth flows after backend verifies the code.
  Future<void> loginWithToken(String token, Map<String, dynamic> userJson) async {
    await ApiService.saveToken(token);
    _user = User.fromJson(userJson);
    _error = null;
    _loading = false;
    await _saveUser(_user!);
    await PublisherFollowService.migrateGuestFollowsToServer();
    await BookmarkMigrationService.migrateGuestBookmarksToServer();
    await PushNotifications.syncAfterLogin();
    notifyListeners();
  }

  // Returns the correct home route for the current user's role
  String get homeRoute {
    if (_user == null) return '/feed';
    if (_user!.isAdmin) return '/admin';
    if (_user!.isReporter) return '/reporter';
    return '/feed';
  }

  Future<void> _saveUser(User user) async {
    await _SecureStorage.write(AppConstants.userKey, jsonEncode({
      '_id': user.id,
      'name': user.name,
      'email': user.email,
      'role': user.role,
      'avatar': user.avatar,
      'phone': user.phone,
      'bio': user.bio,
      'isActive': user.isActive,
    }));
  }
}