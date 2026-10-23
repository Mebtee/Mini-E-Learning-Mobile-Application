import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:mini_e_learning/models/course.dart';
import 'package:mini_e_learning/services/download_service.dart';
import 'package:mini_e_learning/services/lesson_video_controller.dart';

class FakeLessonVideoController extends LessonVideoController {
  FakeLessonVideoController({
    required this.remoteUri,
    this.localFile,
    this.failInitialization = false,
    this.videoDuration = const Duration(minutes: 2),
  });

  final Uri remoteUri;
  final File? localFile;
  final bool failInitialization;
  final Duration videoDuration;

  bool _isInitialized = false;
  bool _isInitializing = true;
  bool _isPlaying = false;
  final bool _isBuffering = false;
  bool _hasEnded = false;
  Duration _position = Duration.zero;
  String? _errorMessage;
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isInitializing => _isInitializing;

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isBuffering => _isBuffering;

  @override
  bool get hasEnded => _hasEnded;

  @override
  Duration get position => _position;

  @override
  Duration get duration => videoDuration;

  @override
  double get aspectRatio => 16 / 9;

  @override
  String? get errorMessage => _errorMessage;

  @override
  Widget get view {
    return const ColoredBox(key: Key('fakeVideoView'), color: Colors.black);
  }

  @override
  Future<void> initialize() async {
    await Future<void>.delayed(Duration.zero);
    _isInitializing = false;
    if (failInitialization) {
      _errorMessage = 'The video could not be loaded.';
    } else {
      _isInitialized = true;
    }
    notifyListeners();
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
    _hasEnded = false;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    notifyListeners();
  }

  @override
  Future<void> seekTo(Duration position) async {
    _position = position;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

LessonVideoControllerFactory createFakeVideoControllerFactory(
  List<FakeLessonVideoController> created, {
  bool failInitialization = false,
}) {
  return ({required Uri remoteUri, File? localFile}) {
    final FakeLessonVideoController controller = FakeLessonVideoController(
      remoteUri: remoteUri,
      localFile: localFile,
      failInitialization: failInitialization,
    );
    created.add(controller);
    return controller;
  };
}

class FakeDownloadService extends DownloadService {
  FakeDownloadService({
    DownloadState initialState = DownloadState.initial,
    this.savedFile,
    this.downloadGate,
  }) : _state = initialState;

  DownloadState _state;
  final File? savedFile;
  final Completer<void>? downloadGate;
  int downloadCalls = 0;

  @override
  DownloadState stateFor(String lessonId) => _state;

  @override
  Future<DownloadState> initialize(Lesson lesson) async => _state;

  @override
  Future<File?> downloadedFileFor(Lesson lesson) async {
    return _state.isCompleted ? savedFile : null;
  }

  @override
  Future<File> download(Lesson lesson) async {
    downloadCalls++;
    _setState(
      const DownloadState(
        status: DownloadStatus.downloading,
        receivedBytes: 50,
        totalBytes: 100,
      ),
    );

    final Completer<void>? gate = downloadGate;
    if (gate != null) {
      await gate.future;
    }

    _setState(const DownloadState(status: DownloadStatus.completed));
    return savedFile ?? File('${lesson.id}.mp4');
  }

  @override
  void cancel(String lessonId) {
    _setState(const DownloadState(status: DownloadStatus.cancelled));
  }

  void _setState(DownloadState state) {
    _state = state;
    notifyListeners();
  }
}
