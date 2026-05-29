import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:news_app/services/auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('homeRoute returns role-specific paths', () async {
      final auth = AuthProvider();
      expect(auth.homeRoute, '/feed');

      await auth.loginWithToken('token-admin', {
        '_id': '1',
        'name': 'Admin',
        'email': 'admin@test.com',
        'role': 'admin',
      });
      expect(auth.homeRoute, '/admin');
      expect(auth.isAdmin, isTrue);

      await auth.loginWithToken('token-reporter', {
        '_id': '2',
        'name': 'Reporter',
        'email': 'rep@test.com',
        'role': 'reporter',
      });
      expect(auth.homeRoute, '/reporter');
      expect(auth.isReporter, isTrue);
    });

    test('logout clears user state', () async {
      final auth = AuthProvider();
      await auth.loginWithToken('token', {
        '_id': '3',
        'name': 'User',
        'email': 'user@test.com',
        'role': 'user',
      });
      expect(auth.isLoggedIn, isTrue);

      await auth.logout();
      expect(auth.isLoggedIn, isFalse);
      expect(auth.user, isNull);
    });
  });
}
