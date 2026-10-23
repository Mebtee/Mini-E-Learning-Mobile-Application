import 'package:flutter/material.dart';

import '../models/course.dart';

/// Displays the course thumbnail asset with a graceful icon fallback.
class CourseThumbnail extends StatelessWidget {
  const CourseThumbnail({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      course.thumbnail,
      fit: BoxFit.cover,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return _ThumbnailFallback(category: course.category);
      },
    );
  }
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primaryContainer,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _iconForCategory(category),
          size: 56,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }

  IconData _iconForCategory(String category) {
    final String value = category.toLowerCase();
    if (value.contains('mobile')) {
      return Icons.phone_android_rounded;
    }
    if (value.contains('data')) {
      return Icons.insights_rounded;
    }
    if (value.contains('design')) {
      return Icons.palette_rounded;
    }
    if (value.contains('web')) {
      return Icons.language_rounded;
    }
    return Icons.school_rounded;
  }
}
