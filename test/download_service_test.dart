import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mini_e_learning/models/course.dart';
import 'package:mini_e_learning/services/download_service.dart';

class _FakeVideoDownloader implements VideoDownloader {
  _FakeVideoDownloader({
    this.contentType = 'video/mp4',
    this.waitForCancel = false,
  });

  final String? contentType;
  final List<int> bytes = const <int>[1, 2, 3, 4];
  final bool waitForCancel;

  final Completer<void> started = Completer<void>();
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<DownloadedContent> download({
    required Uri url,
    required File destination,
    required CancelToken cancelToken,
    DownloadProgress? onProgress,
  }) async {
    calls++;
    if (!started.isCompleted) {
      started.complete();
    }

    if (waitForCancel) {
      await cancelToken.whenCancel;
      throw const DownloadCancelledException();
    }

    final Completer<void>? pendingGate = gate;
    if (pendingGate != null) {
      await pendingGate.future;
    }

    await destination.writeAsBytes(bytes);
    onProgress?.call(bytes.length, bytes.length);
    return DownloadedContent(contentType: contentType);
  }
}

Lesson _lesson({String id = 'flutter-1-1'}) {
  return Lesson(
    id: id,
    title: 'What is Flutter?',
    durationMinutes: 18,
    videoUrl: 'https://example.com/videos/flutter.mp4',
    videoType: 'mp4',
  );
}

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'mini_elearning_downloads_',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  DownloadService buildService(VideoDownloader downloader) {
    return DownloadService(
      downloader: downloader,
      directoryProvider: () async => temporaryDirectory,
    );
  }

  test('downloads a lesson and reports progress', () async {
    final _FakeVideoDownloader downloader = _FakeVideoDownloader();
    final DownloadService service = buildService(downloader);
    addTearDown(service.dispose);
    final Lesson lesson = _lesson();
    final List<DownloadState> states = <DownloadState>[];
    service.addListener(() => states.add(service.stateFor(lesson.id)));

    final File file = await service.download(lesson);

    expect(downloader.calls, 1);
    expect(await file.readAsBytes(), downloader.bytes);
    expect(file.path, endsWith('lesson_flutter-1-1.mp4'));
    expect(service.stateFor(lesson.id).status, DownloadStatus.completed);
    expect(states.any((DownloadState state) => state.isDownloading), isTrue);
    expect(states.any((DownloadState state) => state.progress == 1), isTrue);
    expect(await File('${file.path}.part').exists(), isFalse);
  });

  test('rejects a non-video response and removes the partial file', () async {
    final _FakeVideoDownloader downloader = _FakeVideoDownloader(
      contentType: 'text/html; charset=utf-8',
    );
    final DownloadService service = buildService(downloader);
    addTearDown(service.dispose);
    final Lesson lesson = _lesson();

    await expectLater(
      service.download(lesson),
      throwsA(isA<DownloadException>()),
    );

    final DownloadState state = service.stateFor(lesson.id);
    expect(state.status, DownloadStatus.failed);
    expect(state.errorMessage, contains('did not return a video'));
    expect(await temporaryDirectory.list().toList(), isEmpty);
  });

  test('uses an existing download without downloading it again', () async {
    final _FakeVideoDownloader downloader = _FakeVideoDownloader();
    final DownloadService service = buildService(downloader);
    addTearDown(service.dispose);
    final Lesson lesson = _lesson();
    final File destination = await service.localFileFor(lesson);
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(<int>[9, 8, 7]);

    final DownloadState state = await service.initialize(lesson);
    final File? downloadedFile = await service.downloadedFileFor(lesson);

    expect(state.status, DownloadStatus.completed);
    expect(downloadedFile?.path, destination.path);
    expect(downloader.calls, 0);
  });

  test('cancels an active download and clears its state', () async {
    final _FakeVideoDownloader downloader = _FakeVideoDownloader(
      waitForCancel: true,
    );
    final DownloadService service = buildService(downloader);
    addTearDown(service.dispose);
    final Lesson lesson = _lesson();

    final Future<File> pendingDownload = service.download(lesson);
    await downloader.started.future;
    service.cancel(lesson.id);

    await expectLater(
      pendingDownload,
      throwsA(isA<DownloadCancelledException>()),
    );
    expect(service.stateFor(lesson.id).status, DownloadStatus.cancelled);
  });

  test('shares one request when a download is started twice', () async {
    final _FakeVideoDownloader downloader = _FakeVideoDownloader();
    downloader.gate = Completer<void>();
    final DownloadService service = buildService(downloader);
    addTearDown(service.dispose);
    final Lesson lesson = _lesson();

    final Future<File> firstDownload = service.download(lesson);
    await downloader.started.future;
    final Future<File> secondDownload = service.download(lesson);
    expect(identical(firstDownload, secondDownload), isTrue);

    downloader.gate!.complete();
    await Future.wait(<Future<File>>[firstDownload, secondDownload]);

    expect(downloader.calls, 1);
    expect(service.stateFor(lesson.id).status, DownloadStatus.completed);
  });

  test('keeps sanitized lesson IDs inside the download directory', () async {
    final _FakeVideoDownloader downloader = _FakeVideoDownloader();
    final DownloadService service = buildService(downloader);
    addTearDown(service.dispose);
    final Lesson lesson = _lesson(id: '../../outside/video');

    final File file = await service.download(lesson);

    expect(file.parent.path, temporaryDirectory.path);
    expect(file.path, endsWith('lesson_outside_video.mp4'));
  });
}
