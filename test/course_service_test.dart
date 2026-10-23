import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mini_e_learning/models/course.dart';
import 'package:mini_e_learning/services/course_service.dart';

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this.contents);

  final String contents;

  @override
  Future<ByteData> load(String key) async {
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(contents)));
  }
}

class _FailingAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    throw Exception('Asset not found: $key');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String validCourseJson = '''
  {
    "courses": [
      {
        "id": "course-1",
        "title": "Test Course",
        "description": "A course used by unit tests.",
        "instructor": "Test Instructor",
        "category": "Testing",
        "thumbnail": "assets/images/courses/test.png",
        "totalDurationMinutes": 30,
        "chapters": [
          {
            "id": "chapter-1",
            "title": "Chapter one",
            "lessons": [
              {
                "id": "lesson-1",
                "title": "Lesson one",
                "durationMinutes": 15,
                "videoUrl": "https://example.com/video.mp4",
                "videoType": "mp4"
              },
              {
                "id": "lesson-2",
                "title": "Lesson two",
                "durationMinutes": 15,
                "videoUrl": "https://example.com/video2.mp4",
                "videoType": "mp4"
              }
            ]
          }
        ]
      }
    ]
  }
  ''';

  group('CourseService', () {
    test('loads and parses courses from a JSON asset', () async {
      final CourseService service = CourseService(
        assetBundle: _FakeAssetBundle(validCourseJson),
      );

      final List<Course> courses = await service.loadCourses();

      expect(courses, hasLength(1));
      expect(courses.first.title, 'Test Course');
      expect(courses.first.chapters.first.lessons, hasLength(2));
    });

    test('accepts a top-level JSON list as well as an object wrapper', () async {
      final Object? decoded = jsonDecode(validCourseJson);
      final String listJson = jsonEncode(
        (decoded as Map<String, dynamic>)['courses'],
      );

      final CourseService service = CourseService(
        assetBundle: _FakeAssetBundle(listJson),
      );

      final List<Course> courses = await service.loadCourses();

      expect(courses, hasLength(1));
    });

    test('skips malformed entries and fails when no valid course remains', () {
      final CourseService service = CourseService(
        assetBundle: _FakeAssetBundle('{"courses":[{"id":"broken"}]}'),
      );

      expect(
        service.loadCourses(),
        throwsA(
          isA<CourseLoadException>().having(
            (CourseLoadException error) => error.message,
            'message',
            contains('No valid courses'),
          ),
        ),
      );
    });

    test('reports unreadable or malformed assets clearly', () async {
      final CourseService service = CourseService(
        assetBundle: _FailingAssetBundle(),
      );

      expect(
        service.loadCourses(),
        throwsA(
          isA<CourseLoadException>().having(
            (CourseLoadException error) => error.message,
            'message',
            contains('could not be opened'),
          ),
        ),
      );

      final CourseService malformedService = CourseService(
        assetBundle: _FakeAssetBundle('not json'),
      );

      expect(
        malformedService.loadCourses(),
        throwsA(isA<CourseLoadException>()),
      );
    });

    test('loads the real bundled catalog with the expected shape', () async {
      final List<Course> courses = await CourseService().loadCourses();

      expect(courses, hasLength(4));
      for (final Course course in courses) {
        expect(course.chapters, hasLength(2));
        for (final Chapter chapter in course.chapters) {
          expect(chapter.lessons, hasLength(2));
        }
      }

      final Set<String> courseIds = courses.map((c) => c.id).toSet();
      final Set<String> lessonIds = courses
          .expand((course) => course.chapters)
          .expand((chapter) => chapter.lessons)
          .map((lesson) => lesson.id)
          .toSet();

      expect(courseIds, hasLength(courses.length));
      expect(lessonIds, hasLength(16));
    });
  });
}
