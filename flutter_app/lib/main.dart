import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'services/auth_provider.dart';
import 'services/history_service.dart';
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
import 'screens/onboarding/enhanced_onboarding_language_screen.dart';
import 'screens/onboarding/onboarding_location_screen.dart';
import 'screens/onboarding/onboarding_notifications_screen.dart';
import 'screens/onboarding/onboarding_welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_verify_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/user/way2news_feed_screen.dart';
import 'theme/xpresso_app_theme.dart';
import 'widgets/feed/feed_xpresso_theme.dart';
import 'widgets/feed/enhanced_theme.dart';
import 'widgets/feed/feed_xpresso_palette_enhanced.dart';
import 'widgets/dailyhunt/xpresso_bottom_nav_bar.dart';
import 'widgets/dailyhunt/enhanced_xpresso_bottom_nav_bar.dart';
import 'widgets/dailyhunt/xpresso_menu_scope.dart';
import 'widgets/dailyhunt/xpresso_side_menu.dart';
import 'screens/user/shorts_news_screen.dart';
import 'screens/user/political_reels_screen.dart';
import 'screens/user/quick_news_screen.dart';
import 'screens/user/categories_screen.dart';
import 'screens/user/trending_screen.dart';
import 'screens/user/video_playlist_screen.dart';
import 'screens/user/sports/sports_home_screen.dart';
import 'screens/user/sports/leaderboard_screen.dart';
import 'screens/user/sports/match_detail_screen.dart';
import 'screens/user/weather_screen.dart';
import 'screens/user/article_detail_screen.dart';
import 'screens/user/ai_chat_screen.dart';
import 'screens/user/bookmarks_screen.dart';
import 'screens/user/profile_screen.dart';
import 'screens/user/privacy_policy_screen.dart';
import 'screens/user/history_screen.dart';
import 'screens/user/language_settings_screen.dart';
import 'screens/user/layout_mode_screen.dart';
import 'screens/user/terms_of_service_screen.dart';
import 'screens/user/contact_us_screen.dart';
import 'utils/i18n.dart';
import 'screens/reporter/reporter_dashboard_screen.dart';
import 'screens/reporter/reporter_profile_screen.dart';
import 'screens/reporter/create_post_screen.dart';
import 'screens/reporter/my_posts_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/pending_posts_screen.dart';
import 'screens/admin/manage_users_screen.dart';
import 'services/push_notifications.dart';
import 'services/api_runtime_config.dart';
import 'theme/indic_fonts.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Re-run [GoRouter] redirects only when auth or onboarding prefs change — not on every feed page.
class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable(AuthProvider auth, NewsProvider news) {
    _auth = auth;
    _news = news;
    _prefsLoaded = news.prefsLoaded;
    _languageOnboardingCompleted = news.languageOnboardingCompleted;
    auth.addListener(_onAuth);
    news.addListener(_onNews);
  }

  late final AuthProvider _auth;
  late final NewsProvider _news;
  late bool _prefsLoaded;
  late bool _languageOnboardingCompleted;

  void _onAuth() => notifyListeners();

  void _onNews() {
    final prefs = _news.prefsLoaded;
    final onboarding = _news.languageOnboardingCompleted;
    if (prefs == _prefsLoaded && onboarding == _languageOnboardingCompleted) {
      return;
    }
    _prefsLoaded = prefs;
    _languageOnboardingCompleted = onboarding;
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuth);
    _news.removeListener(_onNews);
    super.dispose();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/.env');
  await ApiRuntimeConfig.ensureResolved();
  try {
    await PushNotifications.bootstrap();
  } catch (e, st) {
    debugPrint('[Push] bootstrap skipped: $e\n$st');
  }
  final themeProvider = ThemeProvider();
  await themeProvider.load();
  await IndicFonts.preload();
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
    refreshListenable: _RouterRefreshListenable(auth, news),
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
          loc == '/way2news' ||
          loc == '/shorts' ||
          loc == '/political-reels' ||
          loc == '/home' ||
          loc == '/quick-news' ||
          loc == '/categories' ||
          loc == '/sports' ||
          loc.startsWith('/sports/') ||
          loc == '/weather' ||
          loc == '/bookmarks' ||
          loc == '/settings' ||
          loc == '/profile' ||
          loc == '/privacy-policy' ||
          loc == '/ai-chat' ||
          loc == '/weather' ||
          loc == '/sports/leaderboard' ||
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
          child: const EnhancedOnboardingLanguageScreen(),
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
            pageBuilder: (context, state) => _smoothAppPage(
              state: state,
              child: const Way2NewsFeedScreen(),
            ),
          ),
          GoRoute(
            path: '/way2news',
            pageBuilder: (context, state) => _smoothAppPage(
              state: state,
              child: const Way2NewsFeedScreen(),
            ),
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
            redirect: (_, __) => '/feed',
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
            path: '/trending',
            pageBuilder: (context, state) =>
                _smoothAppPage(state: state, child: const TrendingScreen()),
          ),
          GoRoute(
            path: '/weather',
            pageBuilder: (context, state) =>
                _smoothAppPage(state: state, child: const WeatherScreen()),
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
            path: '/sports/leaderboard',
            pageBuilder: (context, state) => _smoothAppPage(
              state: state,
              child: const LeaderboardScreen(),
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
            path: '/ai-chat',
            pageBuilder: (context, state) => _smoothAppPage(
              state: state,
              child: const AiChatScreen(),
            ),
          ),
          GoRoute(
            path: '/bookmarks',
            pageBuilder: (context, state) =>
                _smoothAppPage(state: state, child: const BookmarksScreen()),
          ),
          GoRoute(
            path: '/watch-later',
            pageBuilder: (context, state) =>
                _smoothAppPage(state: state, child: const VideoPlaylistScreen()),
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
          GoRoute(
            path: '/history',
            pageBuilder: (context, state) => _smoothAppPage(
              state: state,
              child: const HistoryScreen(),
            ),
          ),
          GoRoute(
            path: '/language',
            pageBuilder: (context, state) => _smoothAppPage(
              state: state,
              child: const LanguageSettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/layout-mode',
            pageBuilder: (context, state) => _smoothAppPage(
              state: state,
              child: const LayoutModeScreen(),
            ),
          ),
          GoRoute(
            path: '/terms-of-service',
            pageBuilder: (context, state) => _smoothAppPage(
              state: state,
              child: const TermsOfServiceScreen(),
            ),
          ),
          GoRoute(
            path: '/contact',
            pageBuilder: (context, state) => _smoothAppPage(
              state: state,
              child: const ContactUsScreen(),
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
        ChangeNotifierProvider(create: (_) => HistoryService()..init()),
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
    final booting = context.select<AuthProvider, bool>(
          (a) => !a.initialized,
        ) ||
        context.select<NewsProvider, bool>((n) => !n.prefsLoaded);

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
class _HorizontalShellSwipe extends StatefulWidget {
  final Widget child;
  final List<String> tabRoutes;

  const _HorizontalShellSwipe({
    required this.child,
    required this.tabRoutes,
  });

  @override
  State<_HorizontalShellSwipe> createState() => _HorizontalShellSwipeState();
}

class _HorizontalShellSwipeState extends State<_HorizontalShellSwipe> {
  int? _tabIndex(String loc) {
    for (var i = 0; i < widget.tabRoutes.length; i++) {
      if (loc == widget.tabRoutes[i]) return i;
    }
    return null;
  }

  bool _shellSwipeEnabled(BuildContext context, String loc) {
    if (loc != '/feed') return true;
    final mode = context.read<NewsProvider>().layoutMode;
    return mode != AppLayoutMode.carouselWheel && mode != AppLayoutMode.dualDeck;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final loc = GoRouterState.of(context).matchedLocation;
        if (!_shellSwipeEnabled(context, loc)) return;
        final i = _tabIndex(loc);
        if (i == null) return;
        final v = details.primaryVelocity ?? 0;
        if (v.abs() < 320) return;
        if (v > 0 && i > 0) {
          context.go(widget.tabRoutes[i - 1]);
        } else if (v < 0 && i < widget.tabRoutes.length - 1) {
          context.go(widget.tabRoutes[i + 1]);
        }
      },
      behavior: HitTestBehavior.translucent,
      child: widget.child,
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
  bool _shortsPrefetched = false;

  FeedXpressoPaletteEnhanced _getEnhancedPalette(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? FeedXpressoPaletteEnhanced.dark
        : FeedXpressoPaletteEnhanced.light;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefetchShorts());
  }

  void _prefetchShorts() {
    if (!mounted || _shortsPrefetched) return;
    final news = context.read<NewsProvider>();
    if (!news.prefsLoaded) {
      news.addListener(_prefetchShorts);
      return;
    }
    news.removeListener(_prefetchShorts);
    _shortsPrefetched = true;
    final lang = news.shortsFeedLanguage;
    final shorts = context.read<ShortsProvider>();
    shorts.warmFromDisk(lang);
    shorts.ensureForLanguage(lang);
  }

  @override
  void dispose() {
    try {
      context.read<NewsProvider>().removeListener(_prefetchShorts);
    } catch (_) {}
    super.dispose();
  }

  void _goIfNeeded(BuildContext context, String current, String target) {
    if (current == target) return;
    context.go(target);
  }

  void _openMenu() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final hideBottomNav = loc == '/ai-chat' ||
        loc == '/quick-news' ||
        loc == '/political-reels' ||
        loc == '/weather' ||
        loc.startsWith('/sports');
    int idx = 0;
    if (loc == '/shorts') idx = 1;
    if (loc == '/categories') idx = 2;
    if (loc == '/bookmarks') idx = 3;
    if (loc == '/settings') idx = 4;

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
          bottomNavigationBar: hideBottomNav
              ? null
              : EnhancedXpressoBottomNavBar(
                  currentIndex: idx,
                  onTap: (i) {
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
                  palette: _getEnhancedPalette(context),
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
    final fx = context.fx;
    int idx = 0;
    if (loc == '/admin/pending') idx = 1;
    if (loc == '/admin/users') idx = 2;
    if (loc == '/admin/settings') idx = 3;

    return Scaffold(
      backgroundColor: fx.background,
      body: child,
      bottomNavigationBar: Material(
        color: fx.navBackground,
        elevation: 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: fx.divider),
            ),
          ),
          child: SafeArea(
            top: false,
            child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  height: 66,
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
                  indicatorColor: fx.accentSurface,
                  indicatorShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    final selected = states.contains(WidgetState.selected);
                    return IconThemeData(
                      size: 26,
                      color: selected ? fx.navActiveIcon : fx.navInactiveIcon,
                    );
                  }),
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    final selected = states.contains(WidgetState.selected);
                    return TextStyle(
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? fx.navActiveLabel : fx.navInactiveLabel,
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
