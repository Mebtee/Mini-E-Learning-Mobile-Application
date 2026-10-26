import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';

/// Stores the lessons a user has completed, scoped to that user's account.
///
/// Progress is kept in [SharedPreferences] as a JSON list of lesson IDs. User
/// keys are sanitized so invalid or missing local data can never break startup.
class ProgressService extends ChangeNotifier {
  ProgressService({required String userKey})
    : _storageKey = '$_storagePrefix${_sanitizeUserKey(userKey)}';

  static const String _storagePrefix = 'completed_lessons_';

  final String _storageKey;
  final Set<String> _completedLessonIds = <String>{};

  bool _isLoaded = false;
  bool _isDisposed = false;

  bool get isLoaded => _isLoaded;

  Set<String> get completedLessonIds =>
      Set<String>.unmodifiable(_completedLessonIds);

  /// Loads saved progress. Corrupt or missing data is treated as empty.
  Future<void> load() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String? rawProgress = preferences.getString(_storageKey);

      if (rawProgress != null && rawProgress.isNotEmpty) {
        final Object? decoded = jsonDecode(rawProgress);
        if (decoded is List) {
          _completedLessonIds
            ..clear()
            ..addAll(
              decoded
                  .whereType<String>()
                  .map((String id) => id.trim())
                  .where((String id) => id.isNotEmpty),
            );
        }
      }
    } catch (_) {
      _completedLessonIds.clear();
    } finally {
      _isLoaded = true;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  bool isCompleted(String lessonId) {
    return _completedLessonIds.contains(lessonId);
  }

  int completedCount(Course course) {
    return course.chapters
        .expand((Chapter chapter) => chapter.lessons)
        .where((Lesson lesson) => isCompleted(lesson.id))
        .length;
  }

  double completionFor(Course course) {
    if (course.lessonCount == 0) {
      return 0;
    }
    return completedCount(course) / course.lessonCount;
  }

  bool isCourseComplete(Course course) {
    return course.lessonCount > 0 &&
        completedCount(course) == course.lessonCount;
  }

  /// Returns false when the lesson was already completed or the ID is empty.
  Future<bool> markCompleted(String lessonId) async {
    final String normalizedId = lessonId.trim();
    if (normalizedId.isEmpty || !_completedLessonIds.add(normalizedId)) {
      return false;
    }

    if (!_isDisposed) {
      notifyListeners();
    }
    await _persist();
    return true;
  }

  Future<bool> markIncomplete(String lessonId) async {
    if (!_completedLessonIds.remove(lessonId.trim())) {
      return false;
    }

    if (!_isDisposed) {
      notifyListeners();
    }
    await _persist();
    return true;
  }

  /// The first lesson that has not been completed, or null when finished.
  Lesson? nextIncompleteLesson(Course course) {
    for (final Chapter chapter in course.chapters) {
      for (final Lesson lesson in chapter.lessons) {
        if (!isCompleted(lesson.id)) {
          return lesson;
        }
      }
    }
    return null;
  }

  Future<void> _persist() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final List<String> sortedIds = _completedLessonIds.toList()..sort();
      await preferences.setString(_storageKey, jsonEncode(sortedIds));
    } catch (_) {
      // Progress remains available in memory if local storage is unavailable.
    }
  }

  static String _sanitizeUserKey(String userKey) {
    final String normalized = userKey.trim().toLowerCase();
    final String sanitized = normalized.replaceAll(
      RegExp(r'[^a-z0-9@._-]'),
      '_',
    );
    return sanitized.isEmpty ? 'guest' : sanitized;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
