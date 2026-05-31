import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'services/auth_provider.dart';
import 'providers/news_provider.dart';
import 'providers/onboarding_draft_provider.dart';
import 'providers/shorts_provider.dart';
import 'providers/political_videos_provider.dart';
import 'providers/shorts_playback_controller.dart';
import 'providers/sports_provider.dart';
import 'models/sports_models.dart';
import 'providers/reporter_provider.dart';
import 'providers/admin_provider.dart';
import 'constants.dart';
import 'providers/theme_provider.dart';

import 'screens/onboarding/dailyhunt_splash_screen.dart';
import 'screens/onboarding/onboarding_interests_screen.dart';
import 'screens/onboarding/onboarding_language_screen.dart';
import 'screens/onboarding/onboarding_location_screen.dart';
import 'screens/onboarding/onboarding_notifications_screen.dart';
import 'screens/onboarding/onboarding_welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_verify_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/user/feed_screen.dart' show FeedScreen;
import 'theme/xpresso_app_theme.dart';
import 'widgets/feed/feed_xpresso_theme.dart';
import 'widgets/dailyhunt/xpresso_bottom_nav_bar.dart';
import 'widgets/dailyhunt/xpresso_menu_scope.dart';
import 'widgets/dailyhunt/xpresso_side_menu.dart';
import 'screens/user/dailyhunt_home_screen.dart';
import 'screens/user/shorts_news_screen.dart';
import 'screens/user/political_reels_screen.dart';
import 'screens/user/quick_news_screen.dart';
import 'screens/user/categories_screen.dart';
import 'screens/user/sports/sports_home_screen.dart';
import 'screens/user/sports/match_detail_screen.dart';
import 'screens/user/article_detail_screen.dart';
import 'screens/user/bookmarks_screen.dart';
import 'screens/user/profile_screen.dart';
import 'screens/user/privacy_policy_screen.dart';
import 'utils/i18n.dart';
import 'screens/reporter/reporter_dashboard_screen.dart';
import 'screens/reporter/reporter_profile_screen.dart';
import 'screens/reporter/create_post_screen.dart';
import 'screens/reporter/my_posts_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/pending_posts_screen.dart';
import 'screens/admin/manage_users_screen.dart';
import 'services/push_notifications.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env');
  await PushNotifications.bootstrap();
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
    transitionDuration: const Duration(milliseconds: 120),
    reverseTransitionDuration: const Duration(milliseconds: 100),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

CustomTransitionPage<void> _onboardingFadePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: fade, child: child);
    },
  );
}

/// Single [GoRouter] for the app lifetime. Must not be recreated in [build] —
/// [NewsProvider] notifies often (feed loads) and a new router each time tanks performance.
GoRouter createAppRouter(BuildContext context) {
  final auth = context.read<AuthProvider>();
  final news = context.read<NewsProvider>();
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: auth.isLoggedIn && (auth.isAdmin || auth.isReporter)
        ? auth.homeRoute
        : '/splash',
    refreshListenable: Listenable.merge([auth, news]),
    redirect: (context, state) {
      final auth = context.read<AuthProvider>();
      final news = context.read<NewsProvider>();
      final loc = state.matchedLocation;

      // Keep deep links (e.g. /shorts) while auth/prefs hydrate — avoids MaterialApp home mismatch on web.
      if (!auth.initialized || !news.prefsLoaded) return null;

      if (loc == '/select-language') return '/onboarding/language';

      if (auth.isLoggedIn && (auth.isAdmin || auth.isReporter)) {
        if (loc == '/splash' || loc.startsWith('/onboarding')) {
          return auth.homeRoute;
        }
      }

      final guestIncomplete =
          !auth.isLoggedIn && !news.languageOnboardingCompleted;

      if (guestIncomplete) {
        const allowed = {
          '/splash',
          '/onboarding/language',
          '/onboarding/interests',
          '/onboarding/location',
          '/onboarding/notifications',
          '/onboarding/welcome',
          '/login',
          '/login/otp',
          '/register',
        };
        if (!allowed.contains(loc)) return '/splash';
      }

      if (!auth.isLoggedIn &&
          news.languageOnboardingCompleted &&
          loc.startsWith('/onboarding')) {
        return '/feed';
      }

      final loggedIn = auth.isLoggedIn;

      final goingToAuth = loc == '/login' ||
          loc == '/login/otp' ||
          loc == '/register';
      final goingToAdmin = loc.startsWith('/admin');
      final goingToReporter = loc.startsWith('/reporter');
      final goingToUserRoute = loc == '/feed' ||
          loc == '/shorts' ||
          loc == '/political-reels' ||
          loc == '/home' ||
          loc == '/quick-news' ||
          loc == '/categories' ||
          loc == '/sports' ||
          loc.startsWith('/sports/') ||
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

      if (loggedIn &&
          auth.isReporter &&
          !auth.isAdmin &&
          goingToUserRoute) {
        return '/reporter';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) {
          final auth = context.read<AuthProvider>();
          final news = context.read<NewsProvider>();
          if (auth.isLoggedIn && (auth.isAdmin || auth.isReporter)) {
            return auth.homeRoute;
          }
          if (!news.languageOnboardingCompleted) return '/splash';
          return '/feed';
        },
      ),

      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const DailyhuntSplashScreen(),
        ),
      ),

      GoRoute(
        path: '/onboarding/language',
        pageBuilder: (context, state) => _onboardingFadePage(
          state: state,
          child: const OnboardingLanguageScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding/interests',
        pageBuilder: (context, state) => _onboardingFadePage(
          state: state,
          child: const OnboardingInterestsScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding/location',
        pageBuilder: (context, state) => _onboardingFadePage(
          state: state,
          child: const OnboardingLocationScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding/notifications',
        pageBuilder: (context, state) => _onboardingFadePage(
          state: state,
          child: const OnboardingNotificationsScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding/welcome',
        pageBuilder: (context, state) => _onboardingFadePage(
          state: state,
          child: const OnboardingWelcomeScreen(),
        ),
      ),

      // ── Auth ──────────────────────────────────────────────
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) =>
            _smoothAppPage(state: state, child: const LoginScreen()),
      ),
      GoRoute(
        path: '/login/otp',
        pageBuilder: (context, state) {
          final extra = state.extra;
          final target = (extra is Map && extra['target'] is String)
              ? extra['target'] as String
              : '';
          return _smoothAppPage(
            state: state,
            child: OtpVerifyScreen(target: target),
          );
        },
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
            path: '/shorts',
            pageBuilder: (context, state) => _smoothAppPage(
              state: state,
              child: const ShortsNewsScreen(),
            ),
          ),
          GoRoute(
            path: '/political-reels',
            pageBuilder: (context, state) => _smoothAppPage(
              state: state,
              child: const PoliticalReelsScreen(),
            ),
          ),
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => _smoothAppPage(
              state: state,
              child: const DailyhuntHomeScreen(),
            ),
          ),
          GoRoute(
            path: '/quick-news',
            pageBuilder: (context, state) =>
                _smoothAppPage(state: state, child: const QuickNewsScreen()),
          ),
          GoRoute(
            path: '/categories',
            pageBuilder: (context, state) =>
                _smoothAppPage(state: state, child: const CategoriesScreen()),
          ),
          GoRoute(
            path: '/sports',
            pageBuilder: (context, state) =>
                _smoothAppPage(state: state, child: const SportsHomeScreen()),
          ),
          GoRoute(
            path: '/sports/match/:id',
            pageBuilder: (context, state) => _smoothAppPage(
              state: state,
              child: MatchDetailScreen(
                matchId: state.pathParameters['id']!,
                initialMatch: state.extra is SportsMatch ? state.extra as SportsMatch : null,
              ),
            ),
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
            path: '/reporter/edit/:id',
            pageBuilder: (context, state) => _smoothAppPage(
              state: state,
              child: CreatePostScreen(
                postId: state.pathParameters['id'],
              ),
            ),
          ),
          GoRoute(
            path: '/reporter/posts',
            pageBuilder: (context, state) =>
                _smoothAppPage(state: state, child: const MyPostsScreen()),
          ),
          // Reporter profile reuses the user profile screen
          GoRoute(
            path: '/reporter/settings',
            pageBuilder: (context, state) => _smoothAppPage(
              state: state,
              child: const ReporterProfileScreen(),
            ),
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
        ChangeNotifierProvider(create: (_) => OnboardingDraftProvider()),
        ChangeNotifierProvider(create: (_) => ShortsProvider()),
        ChangeNotifierProvider(create: (_) => PoliticalVideosProvider()),
        ChangeNotifierProvider(create: (_) => ShortsPlaybackController()),
        ChangeNotifierProvider(create: (_) => SportsProvider()),
        ChangeNotifierProvider(create: (_) => ReporterProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: const _AuthenticatedAppShell(),
    );
  }
}

class _AuthenticatedAppShell extends StatefulWidget {
  const _AuthenticatedAppShell();
  @override
  State<_AuthenticatedAppShell> createState() => _AuthenticatedAppShellState();
}

class _AuthenticatedAppShellState extends State<_AuthenticatedAppShell> {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotifications.handlePendingNavigation((postId) {
        if (!mounted) return;
        _router?.go('/article/$postId');
      });
    });
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
    final auth = context.watch<AuthProvider>();
    final news = context.watch<NewsProvider>();
    final booting = !auth.initialized || !news.prefsLoaded;

    final themeMode = context.watch<ThemeProvider>().themeMode;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          MaterialApp.router(
            title: AppConstants.appName,
            theme: XpressoAppTheme.light(),
            darkTheme: XpressoAppTheme.dark(),
            themeMode: themeMode,
            routerConfig: _router!,
            debugShowCheckedModeBanner: false,
          ),
          if (booting)
            Positioned.fill(
              child: Builder(
                builder: (bootCtx) {
                  final isDark = themeMode == ThemeMode.dark ||
                      (themeMode == ThemeMode.system &&
                          MediaQuery.platformBrightnessOf(bootCtx) ==
                              Brightness.dark);
                  final bootPalette =
                      isDark ? FeedXpressoPalette.dark : FeedXpressoPalette.light;
                  return Theme(
                    data: isDark
                        ? XpressoAppTheme.dark()
                        : XpressoAppTheme.light(),
                    child: Material(
                      color: bootPalette.background,
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: bootPalette.accent.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
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

class UserShell extends StatefulWidget {
  final Widget child;
  const UserShell({super.key, required this.child});

  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _goIfNeeded(BuildContext context, String current, String target) {
    if (current == target) return;
    context.go(target);
  }

  void _openMenu() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    int idx = 0;
    if (loc == '/shorts') idx = 1;
    if (loc == '/categories') idx = 2;
    if (loc == '/bookmarks') idx = 3;
    if (loc == '/settings') idx = 4;

    if (loc == '/home') {
      return Scaffold(
        backgroundColor: FeedXpressoTheme.fx(context).background,
        body: widget.child,
      );
    }

    return XpressoMenuScope(
      openMenu: _openMenu,
      child: Scaffold(
          key: _scaffoldKey,
          drawer: const XpressoSideMenu(),
          drawerEnableOpenDragGesture: true,
          drawerEdgeDragWidth: 28,
          backgroundColor: FeedXpressoTheme.fx(context).background,
          body: _HorizontalShellSwipe(
            tabRoutes: const [
              '/feed',
              '/shorts',
              '/categories',
              '/bookmarks',
              '/settings',
            ],
            child: widget.child,
          ),
          bottomNavigationBar: XpressoBottomNavBar(
        selectedIndex: idx,
        onSelected: (i) {
          switch (i) {
            case 0:
              _goIfNeeded(context, loc, '/feed');
              return;
            case 1:
              _goIfNeeded(context, loc, '/shorts');
              return;
            case 2:
              _goIfNeeded(context, loc, '/categories');
              return;
            case 3:
              _goIfNeeded(context, loc, '/bookmarks');
              return;
            case 4:
              _goIfNeeded(context, loc, '/settings');
              return;
          }
        },
        destinations: [
          XpressoNavDestination(
            icon: Icons.dynamic_feed_outlined,
            selectedIcon: Icons.dynamic_feed_rounded,
            label: I18n.t(context, 'tab_feed'),
          ),
          XpressoNavDestination(
            icon: Icons.view_stream_outlined,
            selectedIcon: Icons.view_stream_rounded,
            label: I18n.t(context, 'tab_shorts'),
          ),
          XpressoNavDestination(
            icon: Icons.grid_view_outlined,
            selectedIcon: Icons.grid_view_rounded,
            label: I18n.t(context, 'feed_categories'),
          ),
          XpressoNavDestination(
            icon: Icons.bookmark_outline,
            selectedIcon: Icons.bookmark_rounded,
            label: I18n.t(context, 'tab_saved'),
          ),
          XpressoNavDestination(
            icon: Icons.person_outline,
            selectedIcon: Icons.person_rounded,
            label: I18n.t(context, 'tab_settings'),
          ),
        ],
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
    int idx = 0;
    if (loc == '/reporter/posts') {
      idx = 1;
    } else if (loc == '/reporter/new' || loc.startsWith('/reporter/edit/')) {
      idx = 2;
    } else if (loc == '/reporter/settings') {
      idx = 3;
    }

    final fx = FeedXpressoTheme.fx(context);
    return Scaffold(
      backgroundColor: fx.background,
      body: _HorizontalShellSwipe(
        tabRoutes: const [
          '/reporter',
          '/reporter/posts',
          '/reporter/settings',
        ],
        child: child,
      ),
      bottomNavigationBar: XpressoBottomNavBar(
        selectedIndex: idx,
        onSelected: (i) {
          switch (i) {
            case 0:
              _goIfNeeded(context, loc, '/reporter');
              return;
            case 1:
              _goIfNeeded(context, loc, '/reporter/posts');
              return;
            case 2:
              _goIfNeeded(context, loc, '/reporter/new');
              return;
            case 3:
              _goIfNeeded(context, loc, '/reporter/settings');
              return;
          }
        },
        destinations: [
          XpressoNavDestination(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: I18n.t(context, 'tab_home'),
          ),
          XpressoNavDestination(
            icon: Icons.article_outlined,
            selectedIcon: Icons.article_rounded,
            label: I18n.t(context, 'tab_my_posts'),
          ),
          XpressoNavDestination(
            icon: Icons.add_circle_outline,
            selectedIcon: Icons.add_circle_rounded,
            label: I18n.t(context, 'tab_create_story'),
          ),
          XpressoNavDestination(
            icon: Icons.person_outline,
            selectedIcon: Icons.person_rounded,
            label: I18n.t(context, 'tab_settings'),
          ),
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
    final p = context.palette;
    int idx = 0;
    if (loc == '/admin/pending') idx = 1;
    if (loc == '/admin/users') idx = 2;
    if (loc == '/admin/settings') idx = 3;

    return Scaffold(
      backgroundColor: Colors.white,
      body: child,
      bottomNavigationBar: Material(
        color: p.surface,
        elevation: 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: p.cardBorder.withValues(alpha: 0.35)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  height: 66,
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
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
                  animationDuration: const Duration(milliseconds: 80),
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
    );
  }
}
