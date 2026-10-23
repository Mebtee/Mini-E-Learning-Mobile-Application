import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mini_e_learning/main.dart';
import 'package:mini_e_learning/services/auth_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows the login screen when there is no saved session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ELearningApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const Key('loginEmailField')), findsOneWidget);
    expect(find.byKey(const Key('loginPasswordField')), findsOneWidget);
  });

  testWidgets('register, log in, and log out flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ELearningApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('loginRegisterButton')));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('registerNameField')),
      'Abebe Kebede',
    );
    await tester.enterText(
      find.byKey(const Key('registerEmailField')),
      'abebe@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('registerPasswordField')),
      'secret123',
    );
    await tester.enterText(
      find.byKey(const Key('registerConfirmPasswordField')),
      'secret123',
    );
    final Finder registerButton = find.byKey(
      const Key('registerSubmitButton'),
    );
    await tester.ensureVisible(registerButton);
    await tester.pumpAndSettle();
    await tester.tap(registerButton);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(
      find.text(
        'Account created successfully. Please log in with your new account.',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('loginEmailField')),
      'abebe@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('loginPasswordField')),
      'secret123',
    );
    final Finder loginButton = find.byKey(const Key('loginSubmitButton'));
    await tester.ensureVisible(loginButton);
    await tester.pumpAndSettle();
    await tester.tap(loginButton);
    await tester.pumpAndSettle();

    expect(find.text('Abebe Kebede'), findsOneWidget);
    expect(find.text('Explore courses'), findsOneWidget);

    // Let the registration SnackBar expire so it cannot cover the button.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    final Finder logoutButton = find.byKey(const Key('homeLogoutButton'));
    await tester.tap(logoutButton);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('shows a save-session error message for wrong credentials', (
    WidgetTester tester,
  ) async {
    await AuthService().register(
      name: 'Abebe Kebede',
      email: 'abebe@example.com',
      password: 'secret123',
    );

    await tester.pumpWidget(const ELearningApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('loginEmailField')),
      'abebe@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('loginPasswordField')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const Key('loginSubmitButton')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Invalid email or password. Please check your details and try again.',
      ),
      findsOneWidget,
    );
  });
}
