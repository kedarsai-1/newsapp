import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:news_app/providers/theme_provider.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await initTestEnv();
    SharedPreferences.setMockInitialValues({});
  });

  test('ThemeProvider defaults to dark mode', () async {
    final themeProvider = ThemeProvider();
    await themeProvider.load();
    expect(themeProvider.themeMode, ThemeMode.dark);
  });

  test('ThemeProvider persists theme selection', () async {
    final themeProvider = ThemeProvider();
    await themeProvider.setThemeMode(ThemeMode.light);
    expect(themeProvider.themeMode, ThemeMode.light);

    final reloaded = ThemeProvider();
    await reloaded.load();
    expect(reloaded.themeMode, ThemeMode.light);
  });
}
