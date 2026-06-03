import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists [ThemeMode] (system / light / dark).
class ThemeProvider extends ChangeNotifier {
  static const _key = 'app_theme_mode';

  static ThemeMode currentMode = ThemeMode.dark;

  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get themeMode => _mode;

  static bool get isLight {
    if (currentMode == ThemeMode.light) return true;
    if (currentMode == ThemeMode.dark) return false;
    return PlatformDispatcher.instance.platformBrightness == Brightness.light;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    if (v == 'light') {
      _mode = ThemeMode.light;
    } else if (v == 'system') {
      _mode = ThemeMode.system;
    } else if (v == 'dark') {
      _mode = ThemeMode.dark;
    } else {
      _mode = ThemeMode.dark;
    }
    currentMode = _mode;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _mode = mode;
    currentMode = _mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
