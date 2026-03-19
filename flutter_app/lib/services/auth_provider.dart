import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../constants.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _loading = false;
  bool _initialized = false; // NEW: tracks whether init() has completed
  String? _error;

  User? get user => _user;
  bool get loading => _loading;
  bool get initialized => _initialized; // NEW: router waits for this
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isReporter => _user?.isReporter ?? false;

  // Called once at app start — reads cached user from SharedPreferences
  Future<void> init() async {
    await ApiService.loadToken();
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(AppConstants.userKey);
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
          notifyListeners();
        } else {
          // Token expired / invalid — force re-login
          await logout();
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
    await ApiService.clearToken();
    _user = null;
    notifyListeners();
  }

  // Used by OTP auth flows after backend verifies the code.
  Future<void> loginWithToken(String token, Map<String, dynamic> userJson) async {
    await ApiService.saveToken(token);
    _user = User.fromJson(userJson);
    _error = null;
    _loading = false;
    await _saveUser(_user!);
    notifyListeners();
  }

  // Returns the correct home route for the current user's role
  String get homeRoute {
    if (_user == null) return '/login';
    if (_user!.isAdmin) return '/admin';
    if (_user!.isReporter) return '/reporter';
    return '/feed';
  }

  Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, jsonEncode({
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