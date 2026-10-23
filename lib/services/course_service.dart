import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/course.dart';

/// A user-facing failure while loading the local course catalog.
class CourseLoadException implements Exception {
  const CourseLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Loads and parses the course catalog from a bundled JSON asset.
class CourseService {
  CourseService({
    AssetBundle? assetBundle,
    this.assetPath = defaultAssetPath,
  }) : _assetBundle = assetBundle ?? rootBundle;

  static const String defaultAssetPath = 'assets/data/courses.json';

  final AssetBundle _assetBundle;
  final String assetPath;

  Future<List<Course>> loadCourses() async {
    final String rawJson;

    try {
      rawJson = await _assetBundle.loadString(assetPath);
    } catch (_) {
      throw const CourseLoadException(
        'The course catalog could not be opened. Please try again.',
      );
    }

    try {
      final Object? decoded = jsonDecode(rawJson);
      final List<dynamic> rawCourses;

      if (decoded is List) {
        rawCourses = decoded;
      } else if (decoded is Map<String, dynamic> && decoded['courses'] is List) {
        rawCourses = decoded['courses'] as List<dynamic>;
      } else {
        throw const FormatException('Unexpected course catalog structure.');
      }

      final List<Course> courses = rawCourses
          .whereType<Map<String, dynamic>>()
          .map(Course.tryFromJson)
          .whereType<Course>()
          .toList();

      if (courses.isEmpty) {
        throw const CourseLoadException(
          'No valid courses were found in the catalog.',
        );
      }

      return courses;
    } on CourseLoadException {
      rethrow;
    } catch (_) {
      throw const CourseLoadException(
        'The course catalog is malformed and could not be read.',
      );
    }
  }
}
