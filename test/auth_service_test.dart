import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mini_e_learning/models/auth_user.dart';
import 'package:mini_e_learning/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthService authService;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    authService = AuthService();
  });

  Future<void> registerDefaultUser() async {
    final AuthResult result = await authService.register(
      name: 'Abebe Kebede',
      email: 'abebe@example.com',
      password: 'secret123',
    );
    expect(result.isSuccess, isTrue);
  }

  group('AuthService registration', () {
    test('registers a user and stores a hashed password', () async {
      final AuthResult result = await authService.register(
        name: 'Abebe Kebede',
        email: '  ABEBE@example.com ',
        password: 'secret123',
      );

      expect(result.isSuccess, isTrue);
      expect(result.user?.name, 'Abebe Kebede');
      expect(result.user?.email, 'abebe@example.com');

      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String rawUsers = preferences.getString('auth_users') ?? '';

      expect(rawUsers, contains('abebe@example.com'));
      expect(rawUsers, isNot(contains('secret123')));
      expect(rawUsers, contains('passwordHash'));
    });

    test('rejects duplicate email registration case-insensitively', () async {
      await registerDefaultUser();

      final AuthResult result = await authService.register(
        name: 'Someone Else',
        email: 'ABEBE@example.com',
        password: 'anotherPassword',
      );

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('already exists'));
    });

    test('validates name, email, and password', () async {
      final AuthResult result = await authService.register(
        name: ' ',
        email: 'not-an-email',
        password: '123',
      );

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('full name'));
    });
  });

  group('AuthService login and session', () {
    test('logs in with the correct password and persists a session', () async {
      await registerDefaultUser();

      final AuthResult result = await authService.login(
        email: 'ABEBE@example.com',
        password: 'secret123',
      );

      expect(result.isSuccess, isTrue);
      expect(result.user?.email, 'abebe@example.com');

      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      expect(
        preferences.getString('auth_session_email'),
        'abebe@example.com',
      );

      final AuthUser? restored = await authService.restoreSession();
      expect(restored?.name, 'Abebe Kebede');
    });

    test('rejects an incorrect password without creating a session', () async {
      await registerDefaultUser();

      final AuthResult result = await authService.login(
        email: 'abebe@example.com',
        password: 'wrong-password',
      );

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('Invalid email or password'));

      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      expect(preferences.getString('auth_session_email'), isNull);
    });

    test('rejects an unknown email', () async {
      final AuthResult result = await authService.login(
        email: 'nobody@example.com',
        password: 'secret123',
      );

      expect(result.isSuccess, isFalse);
    });

    test('logout clears the saved session', () async {
      await registerDefaultUser();
      await authService.login(
        email: 'abebe@example.com',
        password: 'secret123',
      );

      await authService.logout();

      expect(await authService.restoreSession(), isNull);
    });

    test('restoreSession removes a session for a deleted account', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'auth_session_email': 'missing@example.com',
        'auth_users': '[]',
      });

      expect(await AuthService().restoreSession(), isNull);

      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      expect(preferences.getString('auth_session_email'), isNull);
    });
  });
}
