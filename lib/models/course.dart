/// A single lesson inside a chapter.
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.videoUrl,
    required this.videoType,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      durationMinutes: _requiredPositiveInt(json, 'durationMinutes'),
      videoUrl: _requiredVideoUrl(json, 'videoUrl'),
      videoType: _requiredString(json, 'videoType'),
    );
  }

  /// Returns null instead of throwing when a lesson entry is malformed.
  static Lesson? tryFromJson(Map<String, dynamic> json) {
    try {
      return Lesson.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  final String id;
  final String title;
  final int durationMinutes;
  final String videoUrl;
  final String videoType;

  String get durationLabel => _formatDuration(durationMinutes);
}

/// A chapter groups the lessons that belong together.
class Chapter {
  const Chapter({
    required this.id,
    required this.title,
    required this.lessons,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    final Object? rawLessons = json['lessons'];
    if (rawLessons is! List) {
      throw const FormatException('Expected "lessons" to be a list.');
    }

    final List<Lesson> lessons = rawLessons
        .whereType<Map<String, dynamic>>()
        .map(Lesson.tryFromJson)
        .whereType<Lesson>()
        .toList();

    return Chapter(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      lessons: lessons,
    );
  }

  static Chapter? tryFromJson(Map<String, dynamic> json) {
    try {
      return Chapter.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  final String id;
  final String title;
  final List<Lesson> lessons;

  int get durationMinutes {
    return lessons.fold<int>(
      0,
      (int total, Lesson lesson) => total + lesson.durationMinutes,
    );
  }

  String get durationLabel => _formatDuration(durationMinutes);
}

/// A course loaded from the local course catalog asset.
class Course {
  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.instructor,
    required this.category,
    required this.thumbnail,
    required this.totalDurationMinutes,
    required this.chapters,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    final Object? rawChapters = json['chapters'];
    if (rawChapters is! List) {
      throw const FormatException('Expected "chapters" to be a list.');
    }

    final List<Chapter> chapters = rawChapters
        .whereType<Map<String, dynamic>>()
        .map(Chapter.tryFromJson)
        .whereType<Chapter>()
        .where((Chapter chapter) => chapter.lessons.isNotEmpty)
        .toList();

    return Course(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      description: _requiredString(json, 'description'),
      instructor: _requiredString(json, 'instructor'),
      category: _requiredString(json, 'category'),
      thumbnail: _requiredString(json, 'thumbnail'),
      totalDurationMinutes: _requiredPositiveInt(
        json,
        'totalDurationMinutes',
      ),
      chapters: chapters,
    );
  }

  /// Returns null instead of throwing when a course entry is malformed.
  static Course? tryFromJson(Map<String, dynamic> json) {
    try {
      return Course.fromJson(json);
    } on FormatException {
      return null;
    }
  }

  final String id;
  final String title;
  final String description;
  final String instructor;
  final String category;
  final String thumbnail;
  final int totalDurationMinutes;
  final List<Chapter> chapters;

  int get lessonCount {
    return chapters.fold<int>(
      0,
      (int total, Chapter chapter) => total + chapter.lessons.length,
    );
  }

  String get durationLabel => _formatDuration(totalDurationMinutes);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw FormatException('Expected a non-empty string for "$key".');
}

int _requiredPositiveInt(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is int && value > 0) {
    return value;
  }
  throw FormatException('Expected a positive integer for "$key".');
}

String _requiredVideoUrl(Map<String, dynamic> json, String key) {
  final String value = _requiredString(json, key);
  final Uri? uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    throw FormatException('Expected an HTTP(S) video URL for "$key".');
  }
  return value;
}

String _formatDuration(int totalMinutes) {
  final int hours = totalMinutes ~/ 60;
  final int minutes = totalMinutes % 60;

  if (hours == 0) {
    return '$minutes min';
  }
  if (minutes == 0) {
    return '$hours hr';
  }
  return '$hours hr $minutes min';
}
