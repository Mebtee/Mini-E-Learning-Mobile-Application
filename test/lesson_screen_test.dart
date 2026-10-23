import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mini_e_learning/models/course.dart';
import 'package:mini_e_learning/screens/lesson_screen.dart';
import 'package:mini_e_learning/services/download_service.dart';
import 'package:mini_e_learning/services/lesson_video_controller.dart';

import 'support/fakes.dart';

Lesson _lesson({String id = 'flutter-1-1'}) {
  return Lesson(
    id: id,
    title: 'What is Flutter?',
    durationMinutes: 18,
    videoUrl: 'https://example.com/videos/flutter.mp4',
    videoType: 'mp4',
  );
}

Future<void> _pumpLesson(
  WidgetTester tester, {
  required DownloadService downloadService,
  required LessonVideoControllerFactory videoControllerFactory,
  Lesson? lesson,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LessonScreen(
        lesson: lesson ?? _lesson(),
        courseTitle: 'Flutter Fundamentals',
        downloadService: downloadService,
        videoControllerFactory: videoControllerFactory,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
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
}
