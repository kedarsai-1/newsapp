import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'services/auth_provider.dart';
import 'providers/news_provider.dart';
import 'providers/reporter_provider.dart';
import 'providers/admin_provider.dart';
import 'constants.dart';
import 'providers/theme_provider.dart';

import 'screens/onboarding/select_language_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/user/feed_screen.dart' show FeedScreen;
import 'screens/user/article_detail_screen.dart';
import 'screens/user/bookmarks_screen.dart';
import 'screens/user/profile_screen.dart';
import 'screens/user/privacy_policy_screen.dart';
import 'utils/i18n.dart';
import 'screens/reporter/reporter_dashboard_screen.dart';
import 'screens/reporter/create_post_screen.dart';
import 'screens/reporter/my_posts_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/pending_posts_screen.dart';
import 'screens/admin/manage_users_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env');
  final themeProvider = ThemeProvider();
  await themeProvider.load();
  runApp(NewsApp(themeProvider: themeProvider));
}

CustomTransitionPage<void> _smoothAppPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.024),
        end: Offset.zero,
      ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      final scale = Tween<double>(begin: 0.985, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      );

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: ScaleTransition(scale: scale, child: child),
        ),
      );
    },
  );
}

/// Single [GoRouter] for the app lifetime. Must not be recreated in [build] —
/// [NewsProvider] notifies often (feed loads) and a new router each time tanks performance.
GoRouter createAppRouter(BuildContext context) {
  final auth = context.read<AuthProvider>();
  final news = context.read<NewsProvider>();
  return GoRouter(
    initialLocation: auth.homeRoute,
    refreshListenable: Listenable.merge([auth, news]),
    redirect: (context, state) {
      final auth = context.read<AuthProvider>();
      final news = context.read<NewsProvider>();
      final loc = state.matchedLocation;

      if (!news.languageOnboardingCompleted) {
        if (loc != '/select-language') return '/select-language';
        return null;
      }
      if (loc == '/select-language') {
        return auth.homeRoute;
      }

      final loggedIn = auth.isLoggedIn;

      final goingToAuth = loc == '/login' || loc == '/register';
      final goingToAdmin = loc.startsWith('/admin');
      final goingToReporter = loc.startsWith('/reporter');
      final goingToUserRoute = loc == '/feed' ||
          loc == '/bookmarks' ||
          loc == '/settings' ||
          loc == '/profile' ||
          loc == '/privacy-policy' ||
          loc.startsWith('/article/');

      if (!loggedIn && goingToUserRoute) return null;

      if (!loggedIn && goingToAuth) return null;

      if (!loggedIn && (goingToAdmin || goingToReporter)) return '/login';

      if (loggedIn && goingToAuth) return auth.homeRoute;

      if (loggedIn && goingToAdmin && !auth.isAdmin) return auth.homeRoute;
      if (loggedIn && goingToReporter && !auth.isReporter && !auth.isAdmin) {
        return auth.homeRoute;
      }

      return null;
    },
    routes: [
        // Default web entrypoint (/) → user feed.
        // This prevents "Could not navigate to initial route" when the app is opened at /
        // or when the browser reloads on an unknown path.
        GoRoute(
          path: '/',
          redirect: (_, __) => '/feed',
        ),

        GoRoute(
          path: '/select-language',
          pageBuilder: (context, state) => _smoothAppPage(
            state: state,
            child: const SelectLanguageScreen(),
          ),
        ),

        // ── Auth ──────────────────────────────────────────────
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) =>
              _smoothAppPage(state: state, child: const LoginScreen()),
        ),
        GoRoute(
          path: '/register',
          pageBuilder: (context, state) =>
              _smoothAppPage(state: state, child: const RegisterScreen()),
        ),

        // ── End User ──────────────────────────────────────────
        ShellRoute(
          builder: (context, state, child) => UserShell(child: child),
          routes: [
            GoRoute(
              path: '/feed',
              pageBuilder: (context, state) =>
                  _smoothAppPage(state: state, child: const FeedScreen()),
            ),
            GoRoute(
              path: '/article/:id',
              pageBuilder: (context, state) => _smoothAppPage(
                state: state,
                child: ArticleDetailScreen(postId: state.pathParameters['id']!),
              ),
            ),
            GoRoute(
              path: '/bookmarks',
              pageBuilder: (context, state) =>
                  _smoothAppPage(state: state, child: const BookmarksScreen()),
            ),
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) =>
                  _smoothAppPage(state: state, child: const ProfileScreen()),
            ),
            // Backward-compatible route
            GoRoute(
              path: '/profile',
              redirect: (_, __) => '/settings',
            ),
            GoRoute(
              path: '/privacy-policy',
              pageBuilder: (context, state) => _smoothAppPage(
                state: state,
                child: const PrivacyPolicyScreen(),
              ),
            ),
          ],
        ),

        // ── Reporter ──────────────────────────────────────────
        ShellRoute(
          builder: (context, state, child) => ReporterShell(child: child),
          routes: [
            GoRoute(
              path: '/reporter',
              pageBuilder: (context, state) => _smoothAppPage(
                state: state,
                child: const ReporterDashboardScreen(),
              ),
            ),
            GoRoute(
              path: '/reporter/new',
              pageBuilder: (context, state) =>
                  _smoothAppPage(state: state, child: const CreatePostScreen()),
            ),
            GoRoute(
              path: '/reporter/posts',
              pageBuilder: (context, state) =>
                  _smoothAppPage(state: state, child: const MyPostsScreen()),
            ),
            // Reporter profile reuses the user profile screen
            GoRoute(
              path: '/reporter/settings',
              pageBuilder: (context, state) =>
                  _smoothAppPage(state: state, child: const ProfileScreen()),
            ),
            // Backward-compatible route
            GoRoute(
              path: '/reporter/profile',
              redirect: (_, __) => '/reporter/settings',
            ),
          ],
        ),

        // ── Admin ─────────────────────────────────────────────
        ShellRoute(
          builder: (context, state, child) => AdminShell(child: child),
          routes: [
            GoRoute(
              path: '/admin',
              pageBuilder: (context, state) => _smoothAppPage(
                  state: state, child: const AdminDashboardScreen()),
            ),
            GoRoute(
              path: '/admin/pending',
              pageBuilder: (context, state) =>
                  _smoothAppPage(state: state, child: const PendingPostsScreen()),
            ),
            GoRoute(
              path: '/admin/users',
              pageBuilder: (context, state) =>
                  _smoothAppPage(state: state, child: const ManageUsersScreen()),
            ),
            // Admin profile reuses the user profile screen
            GoRoute(
              path: '/admin/settings',
              pageBuilder: (context, state) =>
                  _smoothAppPage(state: state, child: const ProfileScreen()),
            ),
            // Backward-compatible route
            GoRoute(
              path: '/admin/profile',
              redirect: (_, __) => '/admin/settings',
            ),
          ],
        ),
      ],
  );
}

class NewsApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  const NewsApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => NewsProvider()..init()),
        ChangeNotifierProvider(create: (_) => ReporterProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: Consumer2<AuthProvider, NewsProvider>(
        builder: (context, auth, news, _) {
          if (!auth.initialized || !news.prefsLoaded) {
            return Consumer<ThemeProvider>(
              builder: (context, theme, _) => MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                themeMode: theme.themeMode,
                home: const Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
            );
          }
          return const _AuthenticatedAppShell();
        },
      ),
    );
  }
}

class _AuthenticatedAppShell extends StatefulWidget {
  const _AuthenticatedAppShell();
  @override
  State<_AuthenticatedAppShell> createState() =>
      _AuthenticatedAppShellState();
}

class _AuthenticatedAppShellState extends State<_AuthenticatedAppShell> {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(context);
  }

  @override
  void reassemble() {
    // Hot reload: rebuild router so newly added routes (e.g. /settings) apply
    // without requiring a full restart.
    super.reassemble();
    _router = createAppRouter(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: theme.themeMode,
      routerConfig: _router!,
      debugShowCheckedModeBanner: false,
    );
  }
}

// ─── Bottom Nav Shells ────────────────────────────────────────────────────────

/// Horizontal fling switches between [tabRoutes] (only when [matchedLocation] equals one of them).
class _HorizontalShellSwipe extends StatelessWidget {
  final Widget child;
  final List<String> tabRoutes;

  const _HorizontalShellSwipe({
    required this.child,
    required this.tabRoutes,
  });

  int? _tabIndex(String loc) {
    for (var i = 0; i < tabRoutes.length; i++) {
      if (loc == tabRoutes[i]) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final loc = GoRouterState.of(context).matchedLocation;
        final i = _tabIndex(loc);
        if (i == null) return;
        final v = details.primaryVelocity ?? 0;
        if (v.abs() < 320) return;
        if (v > 0 && i > 0) {
          context.go(tabRoutes[i - 1]);
        } else if (v < 0 && i < tabRoutes.length - 1) {
          context.go(tabRoutes[i + 1]);
        }
      },
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}

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
    final p = context.palette;
    final isLight = Theme.of(context).brightness == Brightness.light;
    int idx = 0;
    if (loc == '/bookmarks') idx = 1;
    if (loc == '/settings') idx = 2;
    final isTabRoute = loc == '/feed' || loc == '/bookmarks' || loc == '/settings';

    return Scaffold(
      extendBody: true,
      body: GlassBackground(
        child: _HorizontalShellSwipe(
          tabRoutes: const ['/feed', '/bookmarks', '/settings'],
          // Only animate between bottom tabs. For pushed pages (e.g. /article/:id),
          // animating the shell causes visible "flash" when popping back.
          child: isTabRoute
              ? AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey(loc),
                    child: child,
                  ),
                )
              : child,
        ),
      ),
      // Search is available in the Feed top bar; avoid duplicate floating button.
      floatingActionButton: null,
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isLight ? Colors.white : p.surface.withValues(alpha: 0.70),
            border: Border(
              top: BorderSide(color: p.cardBorder.withValues(alpha: isLight ? 1.0 : 0.55)),
            ),
          ),
          child: isLight
              ? _buildNavBar(context, loc, idx)
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: _buildNavBar(context, loc, idx),
                ),
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context, String loc, int idx) {
    final p = context.palette;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return SafeArea(
      top: false,
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 66,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          indicatorColor: p.primary.withValues(alpha: isLight ? 0.16 : 0.20),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 26,
              color: selected ? p.primary : p.navUnselected,
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? p.primary : p.navUnselected,
            );
          }),
        ),
        child: NavigationBar(
          animationDuration: const Duration(milliseconds: 220),
          selectedIndex: idx,
          backgroundColor: Colors.transparent,
          elevation: 0,
          onDestinationSelected: (i) {
            switch (i) {
              case 0:
                _goIfNeeded(context, loc, '/feed');
                return;
              case 1:
                _goIfNeeded(context, loc, '/bookmarks');
                return;
              case 2:
                _goIfNeeded(context, loc, '/settings');
                return;
            }
          },
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: I18n.t(context, 'tab_feed'),
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_outline),
              selectedIcon: Icon(Icons.bookmark_rounded),
              label: I18n.t(context, 'tab_saved'),
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: I18n.t(context, 'tab_settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DockNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = selected ? p.primary : p.textHint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? p.primary.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Icon(
                  selected ? activeIcon : icon,
                  key: ValueKey(selected),
                  color: c,
                  size: 26,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: c,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
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
    final p = context.palette;
    int sel = 0;
    if (loc == '/reporter/posts') {
      sel = 1;
    } else if (loc == '/reporter/settings') {
      sel = 2;
    } else if (loc == '/reporter/new') {
      sel = -1;
    } else {
      sel = 0;
    }

    return Scaffold(
      extendBody: true,
      body: GlassBackground(
        child: _HorizontalShellSwipe(
          tabRoutes: const ['/reporter', '/reporter/posts', '/reporter/settings'],
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey(loc),
              child: child,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _goIfNeeded(context, loc, '/reporter/new'),
        elevation: 4,
        backgroundColor: p.accentGreen,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        height: 58,
        shape: const CircularNotchedRectangle(),
        notchMargin: 7,
        child: Row(
          children: [
            Expanded(
              child: _DockNavItem(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard_rounded,
                label: I18n.t(context, 'tab_home'),
                selected: sel == 0,
                onTap: () => _goIfNeeded(context, loc, '/reporter'),
              ),
            ),
            const SizedBox(width: 78),
            Expanded(
              child: _DockNavItem(
                icon: Icons.article_outlined,
                activeIcon: Icons.article_rounded,
                label: I18n.t(context, 'tab_my_posts'),
                selected: sel == 1,
                onTap: () => _goIfNeeded(context, loc, '/reporter/posts'),
              ),
            ),
            Expanded(
              child: _DockNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person_rounded,
                label: I18n.t(context, 'tab_settings'),
                selected: sel == 2,
                onTap: () => _goIfNeeded(context, loc, '/reporter/settings'),
              ),
            ),
          ],
        ),
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
    final p = context.palette;
    int idx = 0;
    if (loc == '/admin/pending') idx = 1;
    if (loc == '/admin/users') idx = 2;
    if (loc == '/admin/settings') idx = 3;

    return Scaffold(
      body: GlassBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey(loc),
            child: child,
          ),
        ),
      ),
      extendBody: true,
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: p.surface.withValues(alpha: 0.70),
              border: Border(
                top: BorderSide(color: p.cardBorder.withValues(alpha: 0.55)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  height: 66,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  indicatorColor: p.primary.withValues(alpha: 0.20),
                  indicatorShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    final selected = states.contains(WidgetState.selected);
                    return IconThemeData(
                      size: 26,
                      color: selected ? p.primary : p.textHint,
                    );
                  }),
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    final selected = states.contains(WidgetState.selected);
                    return TextStyle(
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? p.primary : p.textHint,
                    );
                  }),
                ),
                child: NavigationBar(
                  animationDuration: const Duration(milliseconds: 220),
                  selectedIndex: idx,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  onDestinationSelected: (i) {
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
                        _goIfNeeded(context, loc, '/admin/settings');
                        return;
                    }
                  },
                  destinations: [
                    NavigationDestination(
                      icon: Icon(Icons.bar_chart_outlined),
                      selectedIcon: Icon(Icons.bar_chart),
                      label: I18n.t(context, 'tab_dashboard'),
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.pending_outlined),
                      selectedIcon: Icon(Icons.pending),
                      label: I18n.t(context, 'tab_pending'),
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: I18n.t(context, 'tab_users'),
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: I18n.t(context, 'tab_settings'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
