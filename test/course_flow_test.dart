import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mini_e_learning/main.dart';
import 'package:mini_e_learning/models/course.dart';
import 'package:mini_e_learning/services/auth_service.dart';
import 'package:mini_e_learning/services/course_service.dart';

import 'support/fakes.dart';

class _TestCourseService extends CourseService {
  _TestCourseService(this.courses);

  final List<Course> courses;

  @override
  Future<List<Course>> loadCourses() async => courses;
}

class _RetryCourseService extends CourseService {
  _RetryCourseService(this.courses);

  final List<Course> courses;
  int calls = 0;

  @override
  Future<List<Course>> loadCourses() async {
    calls++;
    if (calls == 1) {
      throw const CourseLoadException(
        'The course catalog could not be opened. Please try again.',
      );
    }
    return courses;
  }
}

List<Course> _loadCoursesFromFile() {
  final String rawJson = File('assets/data/courses.json').readAsStringSync();
  final Map<String, dynamic> decoded =
      jsonDecode(rawJson) as Map<String, dynamic>;
  final List<dynamic> rawCourses = decoded['courses'] as List<dynamic>;

  return rawCourses
      .whereType<Map<String, dynamic>>()
      .map(Course.tryFromJson)
      .whereType<Course>()
      .toList();
}

Future<void> _signIn() async {
  final AuthService authService = AuthService();
  final AuthResult registration = await authService.register(
    name: 'Hana Test',
    email: 'hana@example.com',
    password: 'secret123',
  );
  expect(registration.isSuccess, isTrue);

  final AuthResult login = await authService.login(
    email: 'hana@example.com',
    password: 'secret123',
  );
  expect(login.isSuccess, isTrue);
}

late FakeDownloadService _downloadService;

Future<void> _pumpSignedInApp(WidgetTester tester) async {
  await _signIn();
  await tester.pumpWidget(
    ELearningApp(
      courseService: _TestCourseService(_loadCoursesFromFile()),
      downloadService: _downloadService,
      videoControllerFactory: createFakeVideoControllerFactory(
        <FakeLessonVideoController>[],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _downloadService = FakeDownloadService();
  });

  tearDown(() {
    _downloadService.dispose();
  });

  testWidgets('course dashboard lists courses and filters with search', (
    WidgetTester tester,
  ) async {
    await _pumpSignedInApp(tester);

    expect(find.text('Hana Test'), findsOneWidget);
    expect(find.text('Explore courses'), findsOneWidget);
    expect(find.text('4 courses'), findsOneWidget);
    expect(find.text('Flutter Fundamentals'), findsOneWidget);
    expect(find.text('Python for Data Analysis'), findsOneWidget);
    expect(find.text('UI/UX Design Essentials'), findsOneWidget);
    expect(find.text('JavaScript Web Development'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('courseSearchField')),
      'data science',
    );
    await tester.pumpAndSettle();

    expect(find.text('Python for Data Analysis'), findsOneWidget);
    expect(find.text('Flutter Fundamentals'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('courseSearchField')),
      'Tamene Behailu',
    );
    await tester.pumpAndSettle();

    expect(find.text('UI/UX Design Essentials'), findsOneWidget);
    expect(find.text('Python for Data Analysis'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('courseSearchField')),
      'quantum knitting',
    );
    await tester.pumpAndSettle();

    expect(find.text('No courses found'), findsOneWidget);
    expect(find.text('Python for Data Analysis'), findsNothing);

    final Finder clearSearch = find.text('Clear search');
    await tester.ensureVisible(clearSearch);
    await tester.pumpAndSettle();
    await tester.tap(clearSearch);
    await tester.pumpAndSettle();

    expect(find.text('Flutter Fundamentals'), findsOneWidget);
  });

  testWidgets('opens a course, lists chapters, and opens a lesson preview', (
    WidgetTester tester,
  ) async {
    await _pumpSignedInApp(tester);

    final Finder courseCard = find.byKey(
      const Key('courseCard-flutter-fundamentals'),
    );
    await tester.ensureVisible(courseCard);
    await tester.pumpAndSettle();
    await tester.tap(courseCard);
    await tester.pumpAndSettle();

    expect(find.text('Course details'), findsOneWidget);
    expect(find.text('Flutter Fundamentals'), findsOneWidget);
    expect(find.text('Getting Started with Flutter'), findsOneWidget);
    expect(find.text('Layouts and Navigation'), findsOneWidget);
    expect(find.text('What is Flutter?'), findsOneWidget);
    expect(find.text('Your First Widget'), findsOneWidget);
    expect(find.text('Building Responsive Layouts'), findsOneWidget);
    expect(find.text('Navigating Between Screens'), findsOneWidget);

    final Finder lessonTile = find.byKey(
      const Key('lessonTile-flutter-1-1'),
    );
    await tester.ensureVisible(lessonTile);
    await tester.pumpAndSettle();
    await tester.tap(lessonTile);
    await tester.pumpAndSettle();

    expect(find.text('Lesson'), findsOneWidget);
    expect(find.text('What is Flutter?'), findsOneWidget);
    expect(find.text('18 min'), findsWidgets);
    expect(find.byKey(const Key('fakeVideoView')), findsOneWidget);
    expect(find.byKey(const Key('lessonDownloadButton')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Course details'), findsOneWidget);
    expect(find.text('What is Flutter?'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Explore courses'), findsOneWidget);
  });

  testWidgets('shows a load error and retries the course request', (
    WidgetTester tester,
  ) async {
    await _signIn();
    final _RetryCourseService courseService = _RetryCourseService(
      _loadCoursesFromFile(),
    );

    await tester.pumpWidget(
      ELearningApp(
        courseService: courseService,
        downloadService: _downloadService,
        videoControllerFactory: createFakeVideoControllerFactory(
          <FakeLessonVideoController>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load courses'), findsOneWidget);
    final Finder retryButton = find.byKey(const Key('courseRetryButton'));
    expect(retryButton, findsOneWidget);
    await tester.ensureVisible(retryButton);
    await tester.pumpAndSettle();
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(courseService.calls, 2);
    expect(find.text('Flutter Fundamentals'), findsOneWidget);
    expect(find.text('Could not load courses'), findsNothing);
  });
}
