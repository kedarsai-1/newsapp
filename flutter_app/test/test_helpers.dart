import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:news_app/providers/news_provider.dart';

/// Loads dotenv for tests that touch [AppConstants] or screens using I18n.
Future<void> initTestEnv() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (dotenv.isInitialized) return;
  try {
    await dotenv.load(fileName: 'assets/.env');
  } catch (_) {
    dotenv.testLoad(
      fileInput: '''
APP_NAME=NewsNow
API_BASE_URL=http://127.0.0.1:5001/api
SHARE_WEB_BASE_URL=http://127.0.0.1:5001
''',
    );
  }
}

/// Avoid ink_sparkle.frag SkSL/Vulkan failures on headless Linux CI.
Widget testMaterialApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    ),
    home: child,
  );
}

/// Wraps screens that call [I18n.t] (requires [NewsProvider]).
Widget wrapForScreenTest(Widget child, {NewsProvider? newsProvider}) {
  return ChangeNotifierProvider<NewsProvider>.value(
    value: newsProvider ?? NewsProvider(),
    child: MaterialApp(home: child),
  );
}

/// Wraps screens that use [GoRouterState] (e.g. register deep links).
Widget wrapRegisterRouter(Widget registerScreen, {NewsProvider? newsProvider}) {
  return ChangeNotifierProvider<NewsProvider>.value(
    value: newsProvider ?? NewsProvider(),
    child: MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/register',
            builder: (context, state) => registerScreen,
          ),
        ],
        initialLocation: '/register',
      ),
    ),
  );
}
