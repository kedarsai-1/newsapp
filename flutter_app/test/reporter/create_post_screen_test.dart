import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:news_app/providers/reporter_provider.dart';
import 'package:news_app/screens/reporter/create_post_screen.dart';

import '../test_helpers.dart';

void main() {
  setUpAll(() async {
    await initTestEnv();
  });

  group('CreatePostScreen', () {
    testWidgets('renders story form shell', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ReporterProvider(),
          child: const MaterialApp(home: CreatePostScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('New Story'), findsOneWidget);
      expect(find.text('Save Draft'), findsOneWidget);
      expect(find.text('Submit for Approval'), findsOneWidget);
      expect(find.text('Story Headline'), findsOneWidget);
    });
  });
}
