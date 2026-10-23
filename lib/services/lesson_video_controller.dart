import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

abstract class LessonVideoController extends ChangeNotifier {
  bool get isInitialized;
  bool get isInitializing;
  bool get isPlaying;
  bool get isBuffering;
  bool get hasEnded;
  Duration get position;
  Duration get duration;
  double get aspectRatio;
  String? get errorMessage;
  Widget get view;

  Future<void> initialize();
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
}

typedef LessonVideoControllerFactory = LessonVideoController Function({
  required Uri remoteUri,
  File? localFile,
});

LessonVideoController createLessonVideoController({
  required Uri remoteUri,
  File? localFile,
}) {
  return VideoPlayerLessonController(
    remoteUri: remoteUri,
    localFile: localFile,
  );
}

class VideoPlayerLessonController extends LessonVideoController {
  VideoPlayerLessonController({required this.remoteUri, this.localFile})
    : _player = _createPlayer(remoteUri, localFile) {
    _player.addListener(_handlePlayerChanged);
  }

  final Uri remoteUri;
  final File? localFile;
  final VideoPlayerController _player;

  bool _isInitializing = false;
  bool _isDisposed = false;
  String? _errorMessage;

  static VideoPlayerController _createPlayer(Uri remoteUri, File? localFile) {
    if (localFile != null) {
      return VideoPlayerController.file(localFile);
    }
    return VideoPlayerController.networkUrl(remoteUri);
  }

  @override
  bool get isInitialized => _player.value.isInitialized;

  @override
  bool get isInitializing => _isInitializing;

  @override
  bool get isPlaying => _player.value.isPlaying;

  @override
  bool get isBuffering => _player.value.isBuffering;

  @override
  bool get hasEnded => _player.value.isCompleted;

  @override
  Duration get position => _player.value.position;

  @override
  Duration get duration => _player.value.duration;

  @override
  double get aspectRatio {
    final double ratio = _player.value.aspectRatio;
    return ratio > 0 ? ratio : 16 / 9;
  }

  @override
  String? get errorMessage => _errorMessage;

  @override
  Widget get view {
    if (!isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    return VideoPlayer(_player);
  }

  @override
  Future<void> initialize() async {
    if (_isInitializing || isInitialized) {
      return;
    }

    _isInitializing = true;
    _errorMessage = null;
    _notifyListeners();

    try {
      await _player.initialize();
    } catch (_) {
      _errorMessage = localFile == null
          ? 'The video could not be loaded. Check your connection and try again.'
          : 'The saved video could not be opened. Please download it again.';
    } finally {
      _isInitializing = false;
      _notifyListeners();
    }
  }

  @override
  Future<void> play() async {
    if (!isInitialized) {
      return;
    }
    if (hasEnded) {
      await _player.seekTo(Duration.zero);
    }
    await _player.play();
  }

  @override
  Future<void> pause() async {
    if (isInitialized) {
      await _player.pause();
    }
  }

  @override
  Future<void> seekTo(Duration position) async {
    if (!isInitialized) {
      return;
    }
    final Duration clamped = position < Duration.zero
        ? Duration.zero
        : position > duration
        ? duration
        : position;
    await _player.seekTo(clamped);
  }

  void _handlePlayerChanged() {
    _notifyListeners();
  }

  void _notifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _player.removeListener(_handlePlayerChanged);
    unawaited(_player.dispose());
    super.dispose();
  }
}
