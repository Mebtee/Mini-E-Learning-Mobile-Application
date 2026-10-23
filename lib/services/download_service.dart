import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/course.dart';

enum DownloadStatus { notDownloaded, downloading, completed, failed, cancelled }

@immutable
class DownloadState {
  const DownloadState({
    required this.status,
    this.receivedBytes = 0,
    this.totalBytes,
    this.errorMessage,
  });

  static const DownloadState initial = DownloadState(
    status: DownloadStatus.notDownloaded,
  );

  final DownloadStatus status;
  final int receivedBytes;
  final int? totalBytes;
  final String? errorMessage;

  double? get progress {
    final int? total = totalBytes;
    if (total == null || total <= 0) {
      return null;
    }
    return (receivedBytes / total).clamp(0, 1);
  }

  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isCompleted => status == DownloadStatus.completed;
}

class DownloadException implements Exception {
  const DownloadException(this.message);

  final String message;

  @override
  String toString() => 'DownloadException: $message';
}

class DownloadCancelledException extends DownloadException {
  const DownloadCancelledException() : super('Download cancelled.');
}

class DownloadedContent {
  const DownloadedContent({this.contentType});

  final String? contentType;
}

typedef DownloadProgress = void Function(int receivedBytes, int totalBytes);

abstract class VideoDownloader {
  Future<DownloadedContent> download({
    required Uri url,
    required File destination,
    required CancelToken cancelToken,
    DownloadProgress? onProgress,
  });
}

class DioVideoDownloader implements VideoDownloader {
  DioVideoDownloader({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<DownloadedContent> download({
    required Uri url,
    required File destination,
    required CancelToken cancelToken,
    DownloadProgress? onProgress,
  }) async {
    final Response<dynamic> response = await _dio.download(
      url.toString(),
      destination.path,
      cancelToken: cancelToken,
      onReceiveProgress: onProgress,
      options: Options(
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 5),
      ),
    );

    return DownloadedContent(
      contentType: response.headers.value(Headers.contentTypeHeader),
    );
  }
}

typedef DownloadDirectoryProvider = Future<Directory> Function();

/// Downloads and tracks lesson videos that are available without a connection.
///
/// A single instance is shared by the app so an in-progress download keeps
/// running when the user navigates away from a lesson.
class DownloadService extends ChangeNotifier {
  DownloadService({
    VideoDownloader? downloader,
    DownloadDirectoryProvider? directoryProvider,
  }) : _downloader = downloader ?? DioVideoDownloader(),
       _directoryProvider = directoryProvider ?? _defaultDirectoryProvider;

  final VideoDownloader _downloader;
  final DownloadDirectoryProvider _directoryProvider;

  final Map<String, DownloadState> _states = <String, DownloadState>{};
  final Map<String, Future<File>> _activeDownloads = <String, Future<File>>{};
  final Map<String, CancelToken> _cancelTokens = <String, CancelToken>{};
  final Set<String> _initializedLessons = <String>{};
  bool _isDisposed = false;

  static Future<Directory> _defaultDirectoryProvider() async {
    final Directory supportDirectory = await getApplicationSupportDirectory();
    return Directory(
      '${supportDirectory.path}${Platform.pathSeparator}lesson_videos',
    );
  }

  DownloadState stateFor(String lessonId) {
    return _states[lessonId] ?? DownloadState.initial;
  }

  Future<DownloadState> initialize(Lesson lesson) async {
    if (_initializedLessons.contains(lesson.id)) {
      return stateFor(lesson.id);
    }
    _initializedLessons.add(lesson.id);

    if (stateFor(lesson.id).isDownloading ||
        _activeDownloads.containsKey(lesson.id)) {
      return stateFor(lesson.id);
    }

    try {
      final File file = await localFileFor(lesson);
      final bool isAvailable = await file.exists() && await file.length() > 0;
      _setState(
        lesson.id,
        isAvailable
            ? const DownloadState(status: DownloadStatus.completed)
            : DownloadState.initial,
      );
    } catch (_) {
      _setState(
        lesson.id,
        const DownloadState(
          status: DownloadStatus.failed,
          errorMessage: 'Could not check for a saved video on this device.',
        ),
      );
    }

    return stateFor(lesson.id);
  }

  Future<File> localFileFor(Lesson lesson) async {
    final Directory directory = await _directoryProvider();
    final String extension = _videoExtension(lesson);
    return File(
      '${directory.path}${Platform.pathSeparator}'
      'lesson_${_safeFileName(lesson.id)}.$extension',
    );
  }

  Future<File?> downloadedFileFor(Lesson lesson) async {
    final DownloadState state = await initialize(lesson);
    if (!state.isCompleted) {
      return null;
    }

    final File file = await localFileFor(lesson);
    return await file.exists() ? file : null;
  }

  Future<File> download(Lesson lesson) {
    final Future<File>? activeDownload = _activeDownloads[lesson.id];
    if (activeDownload != null) {
      return activeDownload;
    }

    late final Future<File> downloadFuture;
    downloadFuture = _runDownload(lesson).whenComplete(() {
      if (identical(_activeDownloads[lesson.id], downloadFuture)) {
        _activeDownloads.remove(lesson.id);
      }
    });
    _activeDownloads[lesson.id] = downloadFuture;
    return downloadFuture;
  }

  void cancel(String lessonId) {
    _cancelTokens.remove(lessonId)?.cancel('Cancelled by the user.');
  }

  Future<File> _runDownload(Lesson lesson) async {
    File? partialFile;
    final CancelToken cancelToken = CancelToken();
    _cancelTokens[lesson.id] = cancelToken;

    try {
      final Directory directory = await _directoryProvider();
      await directory.create(recursive: true);

      final File destination = await localFileFor(lesson);
      if (await destination.exists() && await destination.length() > 0) {
        _setState(
          lesson.id,
          const DownloadState(status: DownloadStatus.completed),
        );
        return destination;
      }

      partialFile = File('${destination.path}.part');
      if (await partialFile.exists()) {
        await partialFile.delete();
      }

      if (cancelToken.isCancelled) {
        throw const DownloadCancelledException();
      }

      _setState(
        lesson.id,
        const DownloadState(status: DownloadStatus.downloading),
      );

      final DownloadedContent content = await _downloader.download(
        url: Uri.parse(lesson.videoUrl),
        destination: partialFile,
        cancelToken: cancelToken,
        onProgress: (int receivedBytes, int totalBytes) {
          _setState(
            lesson.id,
            DownloadState(
              status: DownloadStatus.downloading,
              receivedBytes: receivedBytes,
              totalBytes: totalBytes > 0 ? totalBytes : null,
            ),
          );
        },
      );

      _validateContentType(content);
      if (!await partialFile.exists() || await partialFile.length() == 0) {
        throw const DownloadException(
          'The downloaded video file is empty. Please try again.',
        );
      }

      if (await destination.exists()) {
        await destination.delete();
      }
      await partialFile.rename(destination.path);

      _setState(
        lesson.id,
        const DownloadState(status: DownloadStatus.completed),
      );
      return destination;
    } on DownloadCancelledException {
      await _deleteIfPresent(partialFile);
      _setState(
        lesson.id,
        const DownloadState(status: DownloadStatus.cancelled),
      );
      rethrow;
    } on DioException catch (error) {
      await _deleteIfPresent(partialFile);
      if (CancelToken.isCancel(error)) {
        _setState(
          lesson.id,
          const DownloadState(status: DownloadStatus.cancelled),
        );
        throw const DownloadCancelledException();
      }

      final String message = _messageForDioError(error);
      _setState(
        lesson.id,
        DownloadState(status: DownloadStatus.failed, errorMessage: message),
      );
      throw DownloadException(message);
    } catch (error) {
      await _deleteIfPresent(partialFile);
      final String message = error is FileSystemException
          ? 'The video could not be saved on this device.'
          : error is DownloadException
          ? error.message
          : 'The video could not be downloaded. Please try again.';
      _setState(
        lesson.id,
        DownloadState(status: DownloadStatus.failed, errorMessage: message),
      );
      if (error is DownloadException) {
        rethrow;
      }
      throw DownloadException(message);
    } finally {
      _cancelTokens.remove(lesson.id);
    }
  }

  void _validateContentType(DownloadedContent content) {
    final String type = content.contentType?.toLowerCase() ?? '';
    if (type.contains('text/html') || type.contains('application/json')) {
      throw const DownloadException(
        'The server did not return a video file. Please try again.',
      );
    }
  }

  String _messageForDioError(DioException error) {
    final int? statusCode = error.response?.statusCode;
    if (statusCode == 404) {
      return 'The video file could not be found (HTTP 404).';
    }
    if (statusCode != null && statusCode >= 400) {
      return 'The video could not be downloaded (HTTP $statusCode).';
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The download timed out. Check your connection and try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Check your network and try again.';
      default:
        return 'The video could not be downloaded. Please try again.';
    }
  }

  Future<void> _deleteIfPresent(File? file) async {
    if (file == null) {
      return;
    }
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // A stale partial file can be cleaned up by the next download attempt.
    }
  }

  void _setState(String lessonId, DownloadState state) {
    _states[lessonId] = state;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  String _videoExtension(Lesson lesson) {
    final Uri? uri = Uri.tryParse(lesson.videoUrl);
    final String lastSegment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : '';
    final int dotIndex = lastSegment.lastIndexOf('.');
    if (dotIndex >= 0 && dotIndex < lastSegment.length - 1) {
      final String extension = lastSegment
          .substring(dotIndex + 1)
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (RegExp(r'^[a-z0-9]{2,5}$').hasMatch(extension)) {
        return extension;
      }
    }

    final String typeExtension = lesson.videoType.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    if (RegExp(r'^[a-z0-9]{2,5}$').hasMatch(typeExtension)) {
      return typeExtension;
    }
    return 'mp4';
  }

  String _safeFileName(String value) {
    final String sanitized = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'^[._]+'), '');
    if (sanitized.isEmpty) {
      return 'video';
    }
    return sanitized.length > 80 ? sanitized.substring(0, 80) : sanitized;
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (final CancelToken token in _cancelTokens.values) {
      token.cancel('The download service was closed.');
    }
    _cancelTokens.clear();
    _activeDownloads.clear();
    super.dispose();
  }
}
