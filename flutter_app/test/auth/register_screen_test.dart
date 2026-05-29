import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:news_app/screens/auth/register_screen.dart';

import '../test_helpers.dart';

void main() {
  setUpAll(() async {
    await initTestEnv();
  });

  Future<void> _pumpRegister(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(wrapRegisterRouter(const RegisterScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('RegisterScreen', () {
    testWidgets('renders registration form fields', (tester) async {
      await _pumpRegister(tester);

      expect(find.text('Create account'), findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);
      expect(find.text('Reader'), findsOneWidget);
      expect(find.text('Reporter'), findsOneWidget);
    });

    testWidgets('shows create account button', (tester) async {
      await _pumpRegister(tester);

      expect(find.widgetWithText(FilledButton, 'Create Account'), findsOneWidget);
    });
  });
}
