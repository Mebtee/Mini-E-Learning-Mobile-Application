import 'package:flutter_test/flutter_test.dart';

import 'package:mini_e_learning/models/course.dart';

void main() {
  Map<String, dynamic> validLessonJson({
    String id = 'lesson-1',
    String title = 'Lesson one',
    int durationMinutes = 20,
    String videoUrl = 'https://example.com/video.mp4',
  }) {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'durationMinutes': durationMinutes,
      'videoUrl': videoUrl,
      'videoType': 'mp4',
    };
  }

  Map<String, dynamic> validCourseJson() {
    final List<Map<String, dynamic>> chapters = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'chapter-1',
        'title': 'Chapter one',
        'lessons': <Map<String, dynamic>>[
          validLessonJson(id: 'lesson-1', durationMinutes: 20),
          validLessonJson(id: 'lesson-2', durationMinutes: 25),
        ],
      },
      <String, dynamic>{
        'id': 'chapter-2',
        'title': 'Chapter two',
        'lessons': <Map<String, dynamic>>[
          validLessonJson(id: 'lesson-3', durationMinutes: 15),
          validLessonJson(id: 'lesson-4', durationMinutes: 15),
        ],
      },
    ];

    return <String, dynamic>{
      'id': 'course-1',
      'title': 'Test Course',
      'description': 'A course used by unit tests.',
      'instructor': 'Test Instructor',
      'category': 'Testing',
      'thumbnail': 'assets/images/courses/test.png',
      'totalDurationMinutes': 75,
      'chapters': chapters,
    };
  }

  group('Course.fromJson', () {
    test('parses nested chapters and lessons', () {
      final Course course = Course.fromJson(validCourseJson());

      expect(course.title, 'Test Course');
      expect(course.chapters, hasLength(2));
      expect(course.chapters.first.lessons, hasLength(2));
      expect(course.lessonCount, 4);
      expect(course.chapters.first.durationMinutes, 45);
      expect(course.chapters.first.durationLabel, '45 min');
      expect(course.durationLabel, '1 hr 15 min');
      expect(course.chapters.first.lessons.first.videoType, 'mp4');
    });

    test('tryFromJson returns null when a required field is missing', () {
      final Map<String, dynamic> json = validCourseJson()..remove('title');

      expect(Course.tryFromJson(json), isNull);
    });

    test('tryFromJson returns null for an invalid total duration', () {
      final Map<String, dynamic> json = validCourseJson()
        ..['totalDurationMinutes'] = '75';

      expect(Course.tryFromJson(json), isNull);
    });

    test('skips malformed chapters and lessons', () {
      final Map<String, dynamic> json = validCourseJson();
      final List<dynamic> chapters = json['chapters'] as List<dynamic>;
      chapters.add(<String, dynamic>{'id': 'broken-chapter'});
      final Map<String, dynamic> secondChapter =
          chapters[1] as Map<String, dynamic>;
      final List<dynamic> lessons =
          secondChapter['lessons'] as List<dynamic>;
      lessons.add(<String, dynamic>{'id': 'broken-lesson'});

      final Course course = Course.fromJson(json);

      expect(course.chapters, hasLength(2));
      expect(course.lessonCount, 4);
    });

    test('rejects lessons with non-HTTP video URLs', () {
      final Map<String, dynamic> json = validLessonJson(
        videoUrl: 'assets/videos/local.mp4',
      );

      expect(Lesson.tryFromJson(json), isNull);
    });
  });

  group('Duration formatting', () {
    test('formats minutes, whole hours, and mixed durations', () {
      Lesson lesson(int minutes) {
        return Lesson(
          id: 'lesson-$minutes',
          title: 'Lesson',
          durationMinutes: minutes,
          videoUrl: 'https://example.com/video.mp4',
          videoType: 'mp4',
        );
      }

      expect(lesson(45).durationLabel, '45 min');
      expect(lesson(60).durationLabel, '1 hr');
      expect(lesson(125).durationLabel, '2 hr 5 min');
    });
  });
}
