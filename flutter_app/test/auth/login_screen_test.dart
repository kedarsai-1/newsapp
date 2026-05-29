import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:news_app/screens/auth/login_screen.dart';

import '../test_helpers.dart';

void main() {
  setUpAll(() async {
    await initTestEnv();
  });

  group('LoginScreen', () {
    testWidgets('renders mobile and email mode switcher', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Mobile'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('switches to email form', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Email'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('shows phone validation error for invalid mobile', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextFormField).first, '12345');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(
        find.text('Enter a valid 10-digit mobile number'),
        findsOneWidget,
      );
    });
  });
}
