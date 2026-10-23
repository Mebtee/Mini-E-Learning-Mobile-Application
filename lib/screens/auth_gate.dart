import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../services/auth_service.dart';
import '../services/course_service.dart';
import '../services/download_service.dart';
import '../services/lesson_video_controller.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';

/// Decides which screen to show based on the restored login session.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.courseService,
    this.downloadService,
    this.videoControllerFactory,
  });

  final CourseService? courseService;
  final DownloadService? downloadService;
  final LessonVideoControllerFactory? videoControllerFactory;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();

  late final DownloadService _downloadService;
  late final bool _ownsDownloadService;

  AuthUser? _currentUser;
  bool _isRestoringSession = true;

  @override
  void initState() {
    super.initState();
    _ownsDownloadService = widget.downloadService == null;
    _downloadService = widget.downloadService ?? DownloadService();
    _restoreSession();
  }

  @override
  void dispose() {
    if (_ownsDownloadService) {
      _downloadService.dispose();
    }
    super.dispose();
  }

  Future<void> _restoreSession() async {
    AuthUser? user;

    try {
      user = await _authService.restoreSession();
    } catch (error) {
      debugPrint('Could not restore the login session: $error');
      user = null;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _currentUser = user;
      _isRestoringSession = false;
    });
  }

  void _handleLoggedIn(AuthUser user) {
    setState(() => _currentUser = user);
  }

  void _handleLoggedOut() {
    setState(() => _currentUser = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_isRestoringSession) {
      return const WelcomeScreen();
    }

    final AuthUser? user = _currentUser;
    if (user == null) {
      return LoginScreen(onLoggedIn: _handleLoggedIn);
    }

    return HomeScreen(
      user: user,
      onLoggedOut: _handleLoggedOut,
      courseService: widget.courseService,
      downloadService: _downloadService,
      videoControllerFactory: widget.videoControllerFactory,
    );
  }
}
