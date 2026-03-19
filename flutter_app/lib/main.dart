import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'services/auth_provider.dart';
import 'providers/news_provider.dart';
import 'providers/reporter_provider.dart';
import 'providers/admin_provider.dart';
import 'constants.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/user/feed_screen.dart';
import 'screens/user/article_detail_screen.dart';
import 'screens/user/bookmarks_screen.dart';
import 'screens/user/profile_screen.dart';
import 'screens/reporter/reporter_dashboard_screen.dart';
import 'screens/reporter/create_post_screen.dart';
import 'screens/reporter/my_posts_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/pending_posts_screen.dart';
import 'screens/admin/manage_users_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env');
  runApp(const NewsApp());
}

class NewsApp extends StatelessWidget {
  const NewsApp({super.key});

  static CustomTransitionPage<void> _smoothPage({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        final slide = Tween<Offset>(
          begin: const Offset(0.02, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: slide, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => NewsProvider()),
        ChangeNotifierProvider(create: (_) => ReporterProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          // Show a blank splash until init() has read SharedPreferences
          if (!auth.initialized) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              home: const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          return MaterialApp.router(
            title: AppConstants.appName,
            theme: AppTheme.light,
            routerConfig: _buildRouter(auth),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }

  GoRouter _buildRouter(AuthProvider auth) {
    return GoRouter(
      initialLocation: auth.homeRoute, // ← starts at role-correct route
      redirect: (context, state) {
        final loggedIn = auth.isLoggedIn;
        final loc = state.matchedLocation;

        final goingToAuth = loc == '/login' || loc == '/register';
        final goingToAdmin = loc.startsWith('/admin');
        final goingToReporter = loc.startsWith('/reporter');

        // Not logged in → always go to login
        if (!loggedIn && !goingToAuth) return '/login';

        // Logged in, trying to reach auth screens → go home
        if (loggedIn && goingToAuth) return auth.homeRoute;

        // Role guards: block wrong-role access
        if (loggedIn && goingToAdmin && !auth.isAdmin) return auth.homeRoute;
        if (loggedIn && goingToReporter && !auth.isReporter && !auth.isAdmin) return auth.homeRoute;

        return null; // no redirect needed
      },
      routes: [
        // ── Auth ──────────────────────────────────────────────
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) =>
              _smoothPage(state: state, child: const LoginScreen()),
        ),
        GoRoute(
          path: '/register',
          pageBuilder: (context, state) =>
              _smoothPage(state: state, child: const RegisterScreen()),
        ),

        // ── End User ──────────────────────────────────────────
        ShellRoute(
          builder: (context, state, child) => UserShell(child: child),
          routes: [
            GoRoute(
              path: '/feed',
              pageBuilder: (context, state) =>
                  _smoothPage(state: state, child: const FeedScreen()),
            ),
            GoRoute(
              path: '/article/:id',
              pageBuilder: (context, state) => _smoothPage(
                state: state,
                child: ArticleDetailScreen(postId: state.pathParameters['id']!),
              ),
            ),
            GoRoute(
              path: '/bookmarks',
              pageBuilder: (context, state) =>
                  _smoothPage(state: state, child: const BookmarksScreen()),
            ),
            GoRoute(
              path: '/profile',
              pageBuilder: (context, state) =>
                  _smoothPage(state: state, child: const ProfileScreen()),
            ),
          ],
        ),

        // ── Reporter ──────────────────────────────────────────
        ShellRoute(
          builder: (context, state, child) => ReporterShell(child: child),
          routes: [
            GoRoute(
              path: '/reporter',
              pageBuilder: (context, state) => _smoothPage(
                state: state,
                child: const ReporterDashboardScreen(),
              ),
            ),
            GoRoute(
              path: '/reporter/new',
              pageBuilder: (context, state) =>
                  _smoothPage(state: state, child: const CreatePostScreen()),
            ),
            GoRoute(
              path: '/reporter/posts',
              pageBuilder: (context, state) =>
                  _smoothPage(state: state, child: const MyPostsScreen()),
            ),
            // Reporter profile reuses the user profile screen
            GoRoute(
              path: '/reporter/profile',
              pageBuilder: (context, state) =>
                  _smoothPage(state: state, child: const ProfileScreen()),
            ),
          ],
        ),

        // ── Admin ─────────────────────────────────────────────
        ShellRoute(
          builder: (context, state, child) => AdminShell(child: child),
          routes: [
            GoRoute(
              path: '/admin',
              pageBuilder: (context, state) =>
                  _smoothPage(state: state, child: const AdminDashboardScreen()),
            ),
            GoRoute(
              path: '/admin/pending',
              pageBuilder: (context, state) =>
                  _smoothPage(state: state, child: const PendingPostsScreen()),
            ),
            GoRoute(
              path: '/admin/users',
              pageBuilder: (context, state) =>
                  _smoothPage(state: state, child: const ManageUsersScreen()),
            ),
            // Admin profile reuses the user profile screen
            GoRoute(
              path: '/admin/profile',
              pageBuilder: (context, state) =>
                  _smoothPage(state: state, child: const ProfileScreen()),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Bottom Nav Shells ────────────────────────────────────────────────────────

class UserShell extends StatelessWidget {
  final Widget child;
  const UserShell({super.key, required this.child});

  void _goIfNeeded(BuildContext context, String current, String target) {
    if (current == target) return;
    context.go(target);
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    int idx = 0;
    if (loc == '/bookmarks') idx = 1;
    if (loc == '/profile') idx = 3;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (i) {
          switch (i) {
            case 0:
              _goIfNeeded(context, loc, '/feed');
              return;
            case 1:
              _goIfNeeded(context, loc, '/bookmarks');
              return;
            case 2:
              showSearch(context: context, delegate: _DummySearch());
              return;
            case 3:
              _goIfNeeded(context, loc, '/profile');
              return;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark_outline), activeIcon: Icon(Icons.bookmark), label: 'Saved'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class ReporterShell extends StatelessWidget {
  final Widget child;
  const ReporterShell({super.key, required this.child});

  void _goIfNeeded(BuildContext context, String current, String target) {
    if (current == target) return;
    context.go(target);
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    int idx = 0;
    if (loc == '/reporter/new') idx = 1;
    if (loc == '/reporter/posts') idx = 2;
    if (loc == '/reporter/profile') idx = 3;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (i) {
          switch (i) {
            case 0:
              _goIfNeeded(context, loc, '/reporter');
              return;
            case 1:
              _goIfNeeded(context, loc, '/reporter/new');
              return;
            case 2:
              _goIfNeeded(context, loc, '/reporter/posts');
              return;
            case 3:
              _goIfNeeded(context, loc, '/reporter/profile');
              return;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), activeIcon: Icon(Icons.add_circle), label: 'New Story'),
          BottomNavigationBarItem(icon: Icon(Icons.article_outlined), activeIcon: Icon(Icons.article), label: 'My Posts'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class AdminShell extends StatelessWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  void _goIfNeeded(BuildContext context, String current, String target) {
    if (current == target) return;
    context.go(target);
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    int idx = 0;
    if (loc == '/admin/pending') idx = 1;
    if (loc == '/admin/users') idx = 2;
    if (loc == '/admin/profile') idx = 3;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        onTap: (i) {
          switch (i) {
            case 0:
              _goIfNeeded(context, loc, '/admin');
              return;
            case 1:
              _goIfNeeded(context, loc, '/admin/pending');
              return;
            case 2:
              _goIfNeeded(context, loc, '/admin/users');
              return;
            case 3:
              _goIfNeeded(context, loc, '/admin/profile');
              return;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.pending_outlined), activeIcon: Icon(Icons.pending), label: 'Pending'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// Lightweight search delegate — real results handled inside FeedScreen
class _DummySearch extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));
  @override
  Widget buildResults(BuildContext context) =>
      const Center(child: Text('No results'));
  @override
  Widget buildSuggestions(BuildContext context) =>
      const Center(child: Text('Search for news...'));
}