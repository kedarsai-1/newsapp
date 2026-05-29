import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:news_app/models/models.dart';
import 'package:news_app/providers/news_provider.dart';
import 'package:news_app/providers/reporter_provider.dart';
import 'package:news_app/screens/reporter/my_posts_screen.dart';
import 'package:news_app/screens/reporter/reporter_dashboard_screen.dart';
import 'package:news_app/services/auth_provider.dart';
import 'package:news_app/utils/i18n.dart';

import 'test_helpers.dart';

class TestReporterProvider extends ReporterProvider {
  bool didCallLoadStats = false;
  bool didCallLoadMyPosts = false;

  bool _testLoading = false;
  Map<String, dynamic>? _testStats;
  List<NewsPost> _testPosts = const [];

  @override
  bool get loading => _testLoading;

  @override
  Map<String, dynamic>? get stats => _testStats;

  @override
  List<NewsPost> get myPosts => _testPosts;

  void seed({
    bool loading = false,
    Map<String, dynamic>? stats,
    List<NewsPost> posts = const [],
  }) {
    _testLoading = loading;
    _testStats = stats;
    _testPosts = posts;
    notifyListeners();
  }

  @override
  Future<void> loadStats() async {
    didCallLoadStats = true;
  }

  @override
  Future<void> loadMyPosts({String? status}) async {
    didCallLoadMyPosts = true;
  }
}

Widget _testApp({
  required ReporterProvider reporterProvider,
  AuthProvider? authProvider,
  required Widget child,
}) {
  return ChangeNotifierProvider<NewsProvider>(
    create: (_) => NewsProvider(),
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider<ReporterProvider>.value(value: reporterProvider),
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider ?? AuthProvider(),
        ),
      ],
      child: MaterialApp(home: child),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initTestEnv();
  });

  group('Reporter screens', () {
    testWidgets('dashboard renders sections and triggers initial loads', (
      tester,
    ) async {
      final provider = TestReporterProvider()
        ..seed(
          stats: {
            'totalPosts': 6,
            'approved': 2,
            'pending': 1,
            'rejected': 1,
            'totalViews': 100,
            'totalLikes': 20,
          },
        );

      await tester.pumpWidget(
        _testApp(
          reporterProvider: provider,
          child: const ReporterDashboardScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text(I18n.t(tester.element(find.byType(MaterialApp)), 'reporter_hub_title')), findsOneWidget);
      expect(find.text('Your Stats'), findsOneWidget);
      expect(provider.didCallLoadStats, isTrue);
      expect(provider.didCallLoadMyPosts, isTrue);
    });

    testWidgets('my posts shows empty state for no stories', (tester) async {
      final provider = TestReporterProvider()..seed(posts: const []);

      await tester.pumpWidget(
        _testApp(reporterProvider: provider, child: const MyPostsScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No stories here'), findsOneWidget);
      expect(find.text('Create Story'), findsOneWidget);
    });

    testWidgets('dashboard greets user when name is missing', (tester) async {
      final provider = TestReporterProvider()
        ..seed(stats: {'totalPosts': 0, 'approved': 0, 'pending': 0, 'rejected': 0});

      await tester.pumpWidget(
        _testApp(
          reporterProvider: provider,
          authProvider: AuthProvider(),
          child: const ReporterDashboardScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Hello,'), findsOneWidget);
    });

    testWidgets('my posts renders rejected story details', (tester) async {
      final post = NewsPost(
        id: 'p1',
        title: 'Rejected post title',
        body: 'This is a rejected post body',
        status: 'rejected',
        rejectionReason: 'Please add source verification.',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        category: Category(
          id: 'c1',
          name: 'Politics',
          slug: 'politics',
          icon: '🗳️',
          color: '#1D9E75',
        ),
        location: LocationData(latitude: 16.5, longitude: 80.6, city: 'Vijayawada'),
      );

      final provider = TestReporterProvider()..seed(posts: [post]);

      await tester.pumpWidget(
        _testApp(reporterProvider: provider, child: const MyPostsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rejected post title'), findsOneWidget);
      expect(find.textContaining('Please add source verification'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });
  });
}
