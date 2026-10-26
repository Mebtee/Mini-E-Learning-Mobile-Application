import 'package:flutter/material.dart';

import '../models/course.dart';
import '../services/download_service.dart';
import '../services/lesson_video_controller.dart';
import '../services/progress_service.dart';
import '../widgets/course_thumbnail.dart';
import 'lesson_screen.dart';

class CourseDetailsScreen extends StatelessWidget {
  const CourseDetailsScreen({
    super.key,
    required this.course,
    required this.downloadService,
    required this.progressService,
    this.videoControllerFactory,
  });

  final Course course;
  final DownloadService downloadService;
  final ProgressService progressService;
  final LessonVideoControllerFactory? videoControllerFactory;

  void _openLesson(BuildContext context, Lesson lesson) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return LessonScreen(
            lesson: lesson,
            course: course,
            courseTitle: course.title,
            downloadService: downloadService,
            videoControllerFactory: videoControllerFactory,
            progressService: progressService,
          );
        },
      ),
    );
  }

  void _continueCourse(BuildContext context) {
    final Lesson? nextIncomplete = progressService.nextIncompleteLesson(course);
    final Lesson? firstLesson = course.chapters.isEmpty
        ? null
        : course.chapters.first.lessons.isEmpty
        ? null
        : course.chapters.first.lessons.first;
    final Lesson? lesson = nextIncomplete ?? firstLesson;

    if (lesson != null) {
      _openLesson(context, lesson);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Course details')),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: progressService,
          builder: (BuildContext context, Widget? child) {
            final int completedLessons = progressService.completedCount(course);
            final double progress = progressService.completionFor(course);
            final bool courseComplete = progressService.isCourseComplete(
              course,
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Hero(
                            tag: 'course-thumbnail-${course.id}',
                            child: CourseThumbnail(course: course),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetaChip(
                            icon: Icons.category_outlined,
                            label: course.category,
                            highlighted: true,
                          ),
                          _MetaChip(
                            icon: Icons.schedule_rounded,
                            label: course.durationLabel,
                          ),
                          _MetaChip(
                            icon: Icons.play_lesson_outlined,
                            label: '${course.lessonCount} lessons',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        course.title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Taught by ${course.instructor}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  courseComplete
                                      ? Icons.verified_rounded
                                      : Icons.trending_up_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    courseComplete
                                        ? 'Course completed'
                                        : 'Your progress',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(progress * 100).round()}%',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$completedLessons of ${course.lessonCount} lessons '
                              'completed',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: const Key('courseContinueButton'),
                        onPressed: () => _continueCourse(context),
                        icon: Icon(
                          courseComplete
                              ? Icons.replay_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(
                          courseComplete
                              ? 'Review course'
                              : completedLessons == 0
                              ? 'Start learning'
                              : 'Continue learning',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        course.description,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Course content',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${course.chapters.length} chapters • '
                        '${course.lessonCount} lessons',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (
                        int index = 0;
                        index < course.chapters.length;
                        index++
                      ) ...[
                        _ChapterCard(
                          chapter: course.chapters[index],
                          chapterNumber: index + 1,
                          progressService: progressService,
                          onLessonTap: (Lesson lesson) {
                            _openLesson(context, lesson);
                          },
                        ),
                        if (index < course.chapters.length - 1)
                          const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
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
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;
    final Color background = highlighted
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);

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

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.chapter,
    required this.chapterNumber,
    required this.progressService,
    required this.onLessonTap,
  });

  final Chapter chapter;
  final int chapterNumber;
  final ProgressService progressService;
  final ValueChanged<Lesson> onLessonTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chapter $chapterNumber',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        chapter.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  chapter.durationLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: theme.colorScheme.outlineVariant, height: 1),
            const SizedBox(height: 4),
            for (int index = 0; index < chapter.lessons.length; index++)
              _LessonTile(
                lesson: chapter.lessons[index],
                lessonNumber: index + 1,
                completed: progressService.isCompleted(
                  chapter.lessons[index].id,
                ),
                onTap: () => onLessonTap(chapter.lessons[index]),
              ),
          ],
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.lessonNumber,
    required this.completed,
    required this.onTap,
  });

  final Lesson lesson;
  final int lessonNumber;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      key: Key('lessonTile-${lesson.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                '$lessonNumber',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${lesson.durationLabel} • '
                    '${lesson.videoType.toUpperCase()}'
                    '${completed ? ' • Completed' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: completed
                          ? const Color(0xFF1B7A3D)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              completed
                  ? Icons.check_circle_rounded
                  : Icons.play_circle_outline_rounded,
              color: completed
                  ? const Color(0xFF1B7A3D)
                  : theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
