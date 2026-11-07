import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/json_reader.dart';
import '../domain/course.dart';

final courseAssetPathProvider = Provider<String>(
  (ref) => const String.fromEnvironment(
    'COURSE_ASSET',
    defaultValue: 'assets/courses/japanese_basics.json',
  ),
);

final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => CourseRepository(bundle: rootBundle),
);

final courseProvider = FutureProvider<Course>((ref) {
  return ref
      .watch(courseRepositoryProvider)
      .loadCourse(ref.watch(courseAssetPathProvider));
});

class CourseRepository {
  const CourseRepository({required this.bundle});

  final AssetBundle bundle;

  Future<Course> loadCourse(String assetPath) async {
    final content = await bundle.loadString(assetPath);
    try {
      return Course.fromJson(JsonReader.object(jsonDecode(content), 'course'));
    } on FormatException catch (error) {
      throw FormatException(
        'Invalid course asset $assetPath: ${error.message}',
      );
    }
  }
}
