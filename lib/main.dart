import 'package:flutter/material.dart';

import 'screens/auth_gate.dart';
import 'services/course_service.dart';
import 'services/download_service.dart';
import 'services/lesson_video_controller.dart';

void main() {
  runApp(const ELearningApp());
}

class ELearningApp extends StatelessWidget {
  const ELearningApp({
    super.key,
    this.courseService,
    this.downloadService,
    this.videoControllerFactory,
  });

  /// Optional injection points for tests; production uses the default loaders.
  final CourseService? courseService;
  final DownloadService? downloadService;
  final LessonVideoControllerFactory? videoControllerFactory;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mini E-Learning',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1565C0),
          elevation: 0,
          centerTitle: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F8FF),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD7E3F4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD7E3F4)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF1565C0),
              width: 1.6,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB3261E)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFB3261E),
              width: 1.6,
            ),
          ),
        ),
      ),
      home: AuthGate(
        courseService: courseService,
        downloadService: downloadService,
        videoControllerFactory: videoControllerFactory,
      ),
    );
  }
}
