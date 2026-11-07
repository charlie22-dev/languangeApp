import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lessons/data/course_repository.dart';
import '../../lessons/domain/course.dart';

// Register additional bundled assets here to extend the language picker.
final courseCatalogPathsProvider = Provider<List<String>>(
  (ref) => [ref.watch(courseAssetPathProvider)],
);

final courseCatalogProvider = FutureProvider<List<Course>>((ref) async {
  final paths = ref.watch(courseCatalogPathsProvider);
  final repository = ref.watch(courseRepositoryProvider);
  return Future.wait(paths.map(repository.loadCourse));
}, retry: (count, error) => null);
