import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lessons/data/course_repository.dart';
import '../../lessons/domain/course.dart';

const additionalCourseAssets = [
  'assets/courses/spanish_basics.json',
  'assets/courses/french_basics.json',
  'assets/courses/german_basics.json',
  'assets/courses/italian_basics.json',
  'assets/courses/portuguese_basics.json',
];

// Keep the configurable original course first; avoid duplicate asset loads.
final courseCatalogPathsProvider = Provider<List<String>>(
  (ref) =>
      {ref.watch(courseAssetPathProvider), ...additionalCourseAssets}.toList(),
);

final courseCatalogProvider = FutureProvider<List<Course>>((ref) async {
  final paths = ref.watch(courseCatalogPathsProvider);
  final repository = ref.watch(courseRepositoryProvider);
  return Future.wait(paths.map(repository.loadCourse));
}, retry: (count, error) => null);
