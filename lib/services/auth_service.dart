import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_user.dart';
import 'auth_validators.dart';
import 'password_hasher.dart';

/// Result of an authentication attempt.
///
/// Expected failures (wrong password, duplicate email, ...) are returned as a
/// [AuthResult] instead of exceptions so screens can display them directly.
class AuthResult {
  const AuthResult._({this.user, this.message});

  const AuthResult.success(AuthUser user) : this._(user: user);

  const AuthResult.failure(String message) : this._(message: message);

  final AuthUser? user;
  final String? message;

  bool get isSuccess => user != null;
}

/// Local, mock authentication backed by shared_preferences.
///
/// LIMITATIONS: this is an assignment demo, not production authentication.
/// shared_preferences is not encrypted secure storage and has no server-side
/// authority. Passwords are salted and hashed with PBKDF2-HMAC-SHA256, but a
/// real app must authenticate against a backend.
class AuthService {
  static const String _usersKey = 'auth_users';
  static const String _sessionKey = 'auth_session_email';

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final String trimmedName = name.trim();
    final String normalizedEmail = _normalizeEmail(email);

    final String? nameError = AuthValidators.name(trimmedName);
    if (nameError != null) {
      return AuthResult.failure(nameError);
    }

    final String? emailError = AuthValidators.email(normalizedEmail);
    if (emailError != null) {
      return AuthResult.failure(emailError);
    }

    final String? passwordError = AuthValidators.password(password);
    if (passwordError != null) {
      return AuthResult.failure(passwordError);
    }

    final List<Map<String, dynamic>> users = await _loadUsers();
    final bool emailAlreadyExists = users.any(
      (Map<String, dynamic> user) => user['email'] == normalizedEmail,
    );

    if (emailAlreadyExists) {
      return const AuthResult.failure(
        'An account with this email already exists. Try logging in instead.',
      );
    }

    users.add(<String, dynamic>{
      'name': trimmedName,
      'email': normalizedEmail,
      'passwordHash': PasswordHasher.hash(password),
    });

    final SharedPreferences preferences =
        await SharedPreferences.getInstance();
    await preferences.setString(_usersKey, jsonEncode(users));

    return AuthResult.success(
      AuthUser(name: trimmedName, email: normalizedEmail),
    );
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final String normalizedEmail = _normalizeEmail(email);

    if (normalizedEmail.isEmpty || password.isEmpty) {
      return const AuthResult.failure(
        'Please enter both your email and password.',
      );
    }

    final List<Map<String, dynamic>> users = await _loadUsers();
    Map<String, dynamic>? matchedUser;

    for (final Map<String, dynamic> user in users) {
      if (user['email'] == normalizedEmail) {
        matchedUser = user;
        break;
      }
    }

    final String? storedHash = matchedUser?['passwordHash'] as String?;
    final bool passwordIsValid =
        storedHash != null && PasswordHasher.verify(password, storedHash);

    // The same message is used for an unknown email and a wrong password so
    // the app does not reveal which accounts exist.
    if (matchedUser == null || !passwordIsValid) {
      return const AuthResult.failure(
        'Invalid email or password. Please check your details and try again.',
      );
    }

    final SharedPreferences preferences =
        await SharedPreferences.getInstance();
    await preferences.setString(_sessionKey, normalizedEmail);

    return AuthResult.success(AuthUser.fromJson(matchedUser));
  }

  /// Returns the signed-in user, or null when there is no valid session.
  Future<AuthUser?> restoreSession() async {
    final SharedPreferences preferences =
        await SharedPreferences.getInstance();
    final String? sessionEmail = preferences.getString(_sessionKey);

    if (sessionEmail == null || sessionEmail.isEmpty) {
      return null;
    }

    final List<Map<String, dynamic>> users = await _loadUsers();
    for (final Map<String, dynamic> user in users) {
      if (user['email'] == sessionEmail) {
        return AuthUser.fromJson(user);
      }
    }

    // The stored session points to an account that no longer exists.
    await preferences.remove(_sessionKey);
    return null;
  }

  Future<void> logout() async {
    final SharedPreferences preferences =
        await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final SharedPreferences preferences =
        await SharedPreferences.getInstance();
    final String? rawUsers = preferences.getString(_usersKey);

    if (rawUsers == null || rawUsers.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final Object? decoded = jsonDecode(rawUsers);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } on FormatException {
      // Corrupted local data is treated as an empty account list.
    }

    return <Map<String, dynamic>>[];
  }

  String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }
}
