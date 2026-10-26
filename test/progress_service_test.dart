import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mini_e_learning/models/course.dart';
import 'package:mini_e_learning/services/progress_service.dart';

Lesson _lesson(String id) {
  return Lesson(
    id: id,
    title: 'Lesson $id',
    durationMinutes: 10,
    videoUrl: 'https://example.com/$id.mp4',
    videoType: 'mp4',
  );
}

Course _course() {
  return Course(
    id: 'course-1',
    title: 'Test Course',
    description: 'A course used by progress tests.',
    instructor: 'Tamene Behailu',
    category: 'Testing',
    thumbnail: 'assets/images/courses/test.png',
    totalDurationMinutes: 40,
    chapters: <Chapter>[
      Chapter(
        id: 'chapter-1',
        title: 'Chapter one',
        lessons: <Lesson>[_lesson('lesson-1'), _lesson('lesson-2')],
      ),
      Chapter(
        id: 'chapter-2',
        title: 'Chapter two',
        lessons: <Lesson>[_lesson('lesson-3'), _lesson('lesson-4')],
      ),
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('marks a lesson complete once and persists it for that user', () async {
    final ProgressService service = ProgressService(
      userKey: 'Student@Example.com',
    );
    await service.load();

    expect(service.isLoaded, isTrue);
    expect(service.isCompleted('lesson-1'), isFalse);
    expect(await service.markCompleted('lesson-1'), isTrue);
    expect(await service.markCompleted('lesson-1'), isFalse);
    expect(service.completedCount(_course()), 1);
    expect(service.completionFor(_course()), 0.25);

    final ProgressService reloaded = ProgressService(
      userKey: 'student@example.com',
    );
    await reloaded.load();

    expect(reloaded.isCompleted('lesson-1'), isTrue);
    expect(reloaded.completedLessonIds, <String>{'lesson-1'});
  });

  test('ignores corrupt or missing saved progress', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'completed_lessons_student@example.com': 'not valid json',
    });

    final ProgressService service = ProgressService(
      userKey: 'student@example.com',
    );
    await service.load();

    expect(service.isLoaded, isTrue);
    expect(service.completedLessonIds, isEmpty);
    expect(service.completionFor(_course()), 0);
  });

  test('filters invalid entries from saved progress', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'completed_lessons_student@example.com': jsonEncode(<Object>[
        'lesson-1',
        42,
        '',
        '  lesson-2  ',
      ]),
    });

    final ProgressService service = ProgressService(
      userKey: 'student@example.com',
    );
    await service.load();

    expect(service.completedLessonIds, <String>{'lesson-1', 'lesson-2'});
    expect(service.completedCount(_course()), 2);
  });

  test(
    'finds the next incomplete lesson and detects course completion',
    () async {
      final ProgressService service = ProgressService(
        userKey: 'student@example.com',
      );
      await service.load();
      final Course course = _course();

      expect(service.nextIncompleteLesson(course)?.id, 'lesson-1');

      await service.markCompleted('lesson-1');
      expect(service.nextIncompleteLesson(course)?.id, 'lesson-2');

      await service.markCompleted('lesson-2');
      await service.markCompleted('lesson-3');
      await service.markCompleted('lesson-4');

      expect(service.nextIncompleteLesson(course), isNull);
      expect(service.isCourseComplete(course), isTrue);
      expect(service.completionFor(course), 1);
    },
  );

  test('keeps progress separate between users', () async {
    final ProgressService firstUser = ProgressService(
      userKey: 'first@test.com',
    );
    final ProgressService secondUser = ProgressService(
      userKey: 'second@test.com',
    );
    await firstUser.load();
    await secondUser.load();

    await firstUser.markCompleted('lesson-1');

    expect(firstUser.isCompleted('lesson-1'), isTrue);
    expect(secondUser.isCompleted('lesson-1'), isFalse);
  });
}
