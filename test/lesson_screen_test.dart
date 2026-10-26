import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mini_e_learning/models/course.dart';
import 'package:mini_e_learning/screens/lesson_screen.dart';
import 'package:mini_e_learning/services/download_service.dart';
import 'package:mini_e_learning/services/lesson_video_controller.dart';
import 'package:mini_e_learning/services/progress_service.dart';

import 'support/fakes.dart';

Lesson _lesson({String id = 'flutter-1-1', String title = 'What is Flutter?'}) {
  return Lesson(
    id: id,
    title: title,
    durationMinutes: 18,
    videoUrl: 'https://example.com/videos/flutter.mp4',
    videoType: 'mp4',
  );
}

Course _course() {
  return Course(
    id: 'flutter-fundamentals',
    title: 'Flutter Fundamentals',
    description: 'A course used by lesson tests.',
    instructor: 'Tamene Behailu',
    category: 'Mobile Development',
    thumbnail: 'assets/images/courses/flutter_fundamentals.png',
    totalDurationMinutes: 54,
    chapters: <Chapter>[
      Chapter(
        id: 'chapter-1',
        title: 'Chapter one',
        lessons: <Lesson>[
          _lesson(id: 'flutter-1-1', title: 'What is Flutter?'),
          _lesson(id: 'flutter-1-2', title: 'Your First Widget'),
          _lesson(id: 'flutter-1-3', title: 'Layout Basics'),
        ],
      ),
    ],
  );
}

Future<void> _pumpLesson(
  WidgetTester tester, {
  required DownloadService downloadService,
  required LessonVideoControllerFactory videoControllerFactory,
  Lesson? lesson,
  Course? course,
  ProgressService? progressService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LessonScreen(
        lesson: lesson ?? _lesson(),
        course: course,
        courseTitle: 'Flutter Fundamentals',
        downloadService: downloadService,
        videoControllerFactory: videoControllerFactory,
        progressService: progressService,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('loads the video and toggles playback', (
    WidgetTester tester,
  ) async {
    final FakeDownloadService downloadService = FakeDownloadService();
    addTearDown(downloadService.dispose);
    final List<FakeLessonVideoController> controllers =
        <FakeLessonVideoController>[];

    await _pumpLesson(
      tester,
      downloadService: downloadService,
      videoControllerFactory: createFakeVideoControllerFactory(controllers),
    );

    expect(find.text('Lesson'), findsOneWidget);
    expect(find.text('What is Flutter?'), findsOneWidget);
    expect(find.byKey(const Key('fakeVideoView')), findsOneWidget);
    expect(controllers, hasLength(1));
    expect(controllers.single.remoteUri.toString(), _lesson().videoUrl);

    await tester.tap(find.byKey(const Key('lessonPlayPauseButton')));
    await tester.pump();

    expect(controllers.single.isPlaying, isTrue);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('lessonPlayPauseButton')));
    await tester.pump();

    expect(controllers.single.isPlaying, isFalse);
  });

  testWidgets('downloads a video and marks the lesson available offline', (
    WidgetTester tester,
  ) async {
    final FakeDownloadService downloadService = FakeDownloadService(
      savedFile: File('offline/flutter-lesson.mp4'),
    );
    addTearDown(downloadService.dispose);
    final List<FakeLessonVideoController> controllers =
        <FakeLessonVideoController>[];

    await _pumpLesson(
      tester,
      downloadService: downloadService,
      videoControllerFactory: createFakeVideoControllerFactory(controllers),
    );

    final Finder downloadButton = find.byKey(const Key('lessonDownloadButton'));
    await tester.ensureVisible(downloadButton);
    await tester.pumpAndSettle();
    await tester.tap(downloadButton);
    await tester.pumpAndSettle();

    expect(downloadService.downloadCalls, 1);
    expect(downloadService.stateFor(_lesson().id).isCompleted, isTrue);
    expect(find.text('Available offline'), findsWidgets);
    expect(find.byKey(const Key('lessonDownloadButton')), findsNothing);
  });

  testWidgets('plays an existing download without starting a new request', (
    WidgetTester tester,
  ) async {
    final File savedFile = File('offline/flutter-lesson.mp4');
    final FakeDownloadService downloadService = FakeDownloadService(
      initialState: const DownloadState(status: DownloadStatus.completed),
      savedFile: savedFile,
    );
    addTearDown(downloadService.dispose);
    final List<FakeLessonVideoController> controllers =
        <FakeLessonVideoController>[];

    await _pumpLesson(
      tester,
      downloadService: downloadService,
      videoControllerFactory: createFakeVideoControllerFactory(controllers),
    );

    expect(controllers.single.localFile?.path, savedFile.path);
    expect(downloadService.downloadCalls, 0);
    expect(find.text('Available offline'), findsWidgets);
    expect(find.byKey(const Key('lessonDownloadButton')), findsNothing);
  });

  testWidgets('marks a lesson complete only once', (WidgetTester tester) async {
    final FakeDownloadService downloadService = FakeDownloadService();
    addTearDown(downloadService.dispose);
    final ProgressService progressService = ProgressService(
      userKey: 'student@example.com',
    );
    addTearDown(progressService.dispose);
    await progressService.load();

    await _pumpLesson(
      tester,
      downloadService: downloadService,
      videoControllerFactory: createFakeVideoControllerFactory(
        <FakeLessonVideoController>[],
      ),
      course: _course(),
      progressService: progressService,
    );

    expect(find.text('Mark as completed'), findsOneWidget);
    final Finder completeButton = find.byKey(
      const Key('lessonCompleteButton'),
    );
    await tester.ensureVisible(completeButton);
    await tester.pumpAndSettle();
    await tester.tap(completeButton);
    await tester.pumpAndSettle();

    expect(progressService.isCompleted('flutter-1-1'), isTrue);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Mark as completed'), findsNothing);
    expect(await progressService.markCompleted('flutter-1-1'), isFalse);
  });

  testWidgets('navigates between lessons and respects course boundaries', (
    WidgetTester tester,
  ) async {
    final FakeDownloadService downloadService = FakeDownloadService();
    addTearDown(downloadService.dispose);
    final ProgressService progressService = ProgressService(
      userKey: 'student@example.com',
    );
    addTearDown(progressService.dispose);
    await progressService.load();
    final Course course = _course();

    await _pumpLesson(
      tester,
      downloadService: downloadService,
      videoControllerFactory: createFakeVideoControllerFactory(
        <FakeLessonVideoController>[],
      ),
      lesson: course.chapters.first.lessons.first,
      course: course,
      progressService: progressService,
    );

    final Finder previousButton = find.byKey(const Key('previousLessonButton'));
    expect(tester.widget<OutlinedButton>(previousButton).onPressed, isNull);

    final Finder nextButton = find.byKey(const Key('nextLessonButton'));
    await tester.ensureVisible(nextButton);
    await tester.pumpAndSettle();
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    expect(find.text('Your First Widget'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('previousLessonButton')))
          .onPressed,
      isNotNull,
    );

    final Finder nextButtonAgain = find.byKey(const Key('nextLessonButton'));
    await tester.ensureVisible(nextButtonAgain);
    await tester.pumpAndSettle();
    await tester.tap(nextButtonAgain);
    await tester.pumpAndSettle();

    expect(find.text('Layout Basics'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('nextLessonButton')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('marks a lesson complete when the video ends and offers next', (
    WidgetTester tester,
  ) async {
    final FakeDownloadService downloadService = FakeDownloadService();
    addTearDown(downloadService.dispose);
    final ProgressService progressService = ProgressService(
      userKey: 'student@example.com',
    );
    addTearDown(progressService.dispose);
    await progressService.load();
    final Course course = _course();
    final List<FakeLessonVideoController> controllers =
        <FakeLessonVideoController>[];

    await _pumpLesson(
      tester,
      downloadService: downloadService,
      videoControllerFactory: createFakeVideoControllerFactory(controllers),
      lesson: course.chapters.first.lessons.first,
      course: course,
      progressService: progressService,
    );

    controllers.single.completePlayback();
    await tester.pumpAndSettle();

    expect(progressService.isCompleted('flutter-1-1'), isTrue);
    expect(find.byType(SnackBarAction), findsOneWidget);

    await tester.tap(find.byType(SnackBarAction));
    await tester.pumpAndSettle();

    expect(find.text('Your First Widget'), findsOneWidget);
  });
}
