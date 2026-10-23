import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/course.dart';
import '../services/download_service.dart';
import '../services/lesson_video_controller.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.lesson,
    required this.courseTitle,
    this.downloadService,
    this.videoControllerFactory,
  });

  final Lesson lesson;
  final String courseTitle;
  final DownloadService? downloadService;
  final LessonVideoControllerFactory? videoControllerFactory;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  late final DownloadService _downloadService;
  late final bool _ownsDownloadService;
  late final LessonVideoControllerFactory _videoControllerFactory;

  LessonVideoController? _videoController;
  DownloadState _downloadState = DownloadState.initial;
  File? _localFile;
  bool _isPreparingVideo = true;
  String? _playbackError;

  @override
  void initState() {
    super.initState();
    _ownsDownloadService = widget.downloadService == null;
    _downloadService = widget.downloadService ?? DownloadService();
    _videoControllerFactory =
        widget.videoControllerFactory ?? createLessonVideoController;
    _downloadService.addListener(_handleDownloadChanged);
    unawaited(_prepareLesson());
  }

  Future<void> _prepareLesson() async {
    DownloadState state = DownloadState.initial;
    File? localFile;

    try {
      state = await _downloadService.initialize(widget.lesson);
      if (state.isCompleted) {
        localFile = await _downloadService.downloadedFileFor(widget.lesson);
      }
    } catch (_) {
      state = const DownloadState(
        status: DownloadStatus.failed,
        errorMessage: 'Could not check for a saved video on this device.',
      );
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _downloadState = state;
      _localFile = localFile;
    });

    await _createVideoController(localFile);
  }

  Future<void> _createVideoController(
    File? localFile, {
    bool allowNetworkFallback = true,
  }) async {
    final LessonVideoController? previousController = _videoController;
    if (previousController != null) {
      previousController.removeListener(_handleVideoChanged);
      previousController.dispose();
    }

    late final LessonVideoController controller;
    try {
      controller = _videoControllerFactory(
        remoteUri: Uri.parse(widget.lesson.videoUrl),
        localFile: localFile,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _videoController = null;
        _isPreparingVideo = false;
        _playbackError = 'The video player could not be started.';
      });
      return;
    }

    controller.addListener(_handleVideoChanged);
    if (mounted) {
      setState(() {
        _videoController = controller;
        _isPreparingVideo = true;
        _playbackError = null;
      });
    }

    await controller.initialize();

    if (!mounted || !identical(_videoController, controller)) {
      return;
    }

    if (localFile != null &&
        allowNetworkFallback &&
        controller.errorMessage != null) {
      controller.removeListener(_handleVideoChanged);
      controller.dispose();
      _videoController = null;
      await _createVideoController(null, allowNetworkFallback: false);
      return;
    }

    setState(() {
      _isPreparingVideo = false;
      _playbackError = controller.errorMessage;
    });
  }

  void _handleVideoChanged() {
    final LessonVideoController? controller = _videoController;
    if (!mounted || controller == null) {
      return;
    }
    setState(() {});
  }

  void _handleDownloadChanged() {
    if (!mounted) {
      return;
    }

    final DownloadState state = _downloadService.stateFor(widget.lesson.id);
    setState(() => _downloadState = state);

    if (state.isCompleted) {
      unawaited(_refreshLocalFile());
    }
  }

  Future<void> _refreshLocalFile() async {
    final File? file = await _downloadService.downloadedFileFor(widget.lesson);
    if (mounted && file != null) {
      setState(() => _localFile = file);
    }
  }

  Future<void> _downloadVideo() async {
    try {
      await _downloadService.download(widget.lesson);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lesson saved for offline viewing.')),
        );
      }
    } on DownloadCancelledException {
      // The download card reflects the cancelled state.
    } on DownloadException {
      // The download card displays the failure message.
    }
  }

  void _cancelDownload() {
    _downloadService.cancel(widget.lesson.id);
  }

  @override
  void dispose() {
    _downloadService.removeListener(_handleDownloadChanged);
    _videoController?.removeListener(_handleVideoChanged);
    _videoController?.dispose();
    if (_ownsDownloadService) {
      _downloadService.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LessonVideoController? controller = _videoController;
    final bool showVideo = controller?.isInitialized == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Lesson')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: showVideo ? controller!.aspectRatio : 16 / 9,
                      child: ColoredBox(
                        color: Colors.black,
                        child: _buildVideoArea(theme, controller),
                      ),
                    ),
                  ),
                  if (showVideo) ...[
                    const SizedBox(height: 12),
                    _buildPlaybackControls(theme, controller!),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    widget.lesson.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.courseTitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _LessonChip(
                        icon: Icons.schedule_rounded,
                        label: widget.lesson.durationLabel,
                      ),
                      _LessonChip(
                        icon: Icons.movie_outlined,
                        label: widget.lesson.videoType.toUpperCase(),
                      ),
                      if (_downloadState.isCompleted)
                        _LessonChip(
                          icon: Icons.offline_pin_rounded,
                          label: 'Available offline',
                          highlighted: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDownloadCard(theme),
                  const SizedBox(height: 20),
                  Text(
                    'Streaming requires an internet connection. Download the '
                    'lesson to keep watching when you are offline.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back to course'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoArea(ThemeData theme, LessonVideoController? controller) {
    if (_isPreparingVideo ||
        (controller != null && controller.isInitializing)) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text('Loading video...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    final String? error = _playbackError ?? controller?.errorMessage;
    if (controller == null || !controller.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_rounded,
                size: 36,
                color: Colors.white70,
              ),
              const SizedBox(height: 6),
              Text(
                error ?? 'The video is not available right now.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  height: 1.3,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('lessonVideoRetryButton'),
                onPressed: () => _createVideoController(_localFile),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry video'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: controller.view),
        if (controller.isBuffering && controller.isPlaying)
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        if (!controller.isPlaying)
          IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaybackControls(
    ThemeData theme,
    LessonVideoController controller,
  ) {
    final int durationMs = math.max(controller.duration.inMilliseconds, 1);
    final int positionMs = controller.position.inMilliseconds.clamp(
      0,
      durationMs,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          IconButton.filled(
            key: const Key('lessonPlayPauseButton'),
            tooltip: controller.isPlaying ? 'Pause' : 'Play',
            onPressed: () {
              if (controller.isPlaying) {
                unawaited(controller.pause());
              } else {
                unawaited(controller.play());
              }
            },
            icon: Icon(
              controller.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _formatPlaybackDuration(controller.position),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Expanded(
            child: Slider(
              value: positionMs.toDouble(),
              max: durationMs.toDouble(),
              onChanged: (double value) {
                unawaited(
                  controller.seekTo(Duration(milliseconds: value.round())),
                );
              },
            ),
          ),
          Text(
            _formatPlaybackDuration(controller.duration),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadCard(ThemeData theme) {
    final bool isDownloading = _downloadState.isDownloading;
    final String title;
    final String message;
    final IconData icon;

    switch (_downloadState.status) {
      case DownloadStatus.notDownloaded:
        title = 'Save for offline viewing';
        message =
            'Download this lesson to watch it without an internet connection.';
        icon = Icons.download_rounded;
      case DownloadStatus.downloading:
        title = 'Downloading video';
        final double? progress = _downloadState.progress;
        message = progress == null
            ? 'Starting download...'
            : '${(progress * 100).round()}% of '
                  '${_formatBytes(_downloadState.totalBytes!)}';
        icon = Icons.downloading_rounded;
      case DownloadStatus.completed:
        title = 'Available offline';
        message = 'This lesson is saved on your device.';
        icon = Icons.offline_pin_rounded;
      case DownloadStatus.failed:
        title = 'Download failed';
        message =
            _downloadState.errorMessage ??
            'The video could not be downloaded. Please try again.';
        icon = Icons.error_outline_rounded;
      case DownloadStatus.cancelled:
        title = 'Download cancelled';
        message = 'You can start the download again at any time.';
        icon = Icons.cancel_outlined;
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: const Color(0xFFF7FAFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _downloadState.isCompleted
                        ? const Color(0xFFE4F4E8)
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: _downloadState.isCompleted
                        ? const Color(0xFF1B7A3D)
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isDownloading) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _downloadState.progress,
                  minHeight: 7,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const Key('lessonCancelDownloadButton'),
                  onPressed: _cancelDownload,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancel download'),
                ),
              ),
            ] else if (_downloadState.status == DownloadStatus.failed ||
                _downloadState.status == DownloadStatus.cancelled) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('lessonRetryDownloadButton'),
                onPressed: _downloadVideo,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try download again'),
              ),
            ] else if (!_downloadState.isCompleted) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('lessonDownloadButton'),
                onPressed: _downloadVideo,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download video'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatPlaybackDuration(Duration duration) {
  final int totalSeconds = math.max(duration.inSeconds, 0);
  final int hours = totalSeconds ~/ 3600;
  final int minutes = (totalSeconds % 3600) ~/ 60;
  final int seconds = totalSeconds % 60;

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).round()} KB';
  }
  return '$bytes B';
}

class _LessonChip extends StatelessWidget {
  const _LessonChip({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color foreground = highlighted
        ? const Color(0xFF1B7A3D)
        : theme.colorScheme.onSurfaceVariant;
    final Color background = highlighted
        ? const Color(0xFFE4F4E8)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
