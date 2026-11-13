import '../../activity/data/activity_providers.dart';
import '../../activity/domain/streak.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../lessons/domain/course.dart';
import '../../onboarding/data/course_catalog.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import '../domain/learning_path.dart';

final selectedCourseProvider = FutureProvider<Course>((ref) async {
  final settings = await ref.watch(onboardingProvider.future);
  final courses = await ref.watch(courseCatalogProvider.future);
  for (final course in courses) {
    if (course.id == settings?.courseId) return course;
  }
  throw StateError('The selected course is unavailable');
}, retry: (count, error) => null);

final lessonProgressProvider = StreamProvider<List<LessonRecord>>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return database
      .select(database.lessonProgress)
      .watch()
      .map(
        (rows) => rows
            .map(
              (row) => LessonRecord(
                lessonId: row.lessonId,
                completed: row.completed,
                bestScore: row.bestScore,
              ),
            )
            .toList(),
      );
}, retry: (count, error) => null);

final userStatsProvider = StreamProvider<UserStatsRow>((ref) {
  final today = ref.watch(localTodayProvider);
  final database = ref.watch(appDatabaseProvider);
  return (database.select(
    database.userStats,
  )..where((table) => table.id.equals(1))).watchSingle().map(
    (row) => row.copyWith(
      streak: Streak.visible(row.streak, row.lastActiveDate?.toLocal(), today),
    ),
  );
}, retry: (count, error) => null);

final learningPathProvider = Provider<AsyncValue<LearningPath>>((ref) {
  final course = ref.watch(selectedCourseProvider);
  final progress = ref.watch(lessonProgressProvider);
  return course.when(
    skipLoadingOnRefresh: false,
    data: (course) => progress.when(
      skipLoadingOnRefresh: false,
      data: (records) => AsyncData(LearningPath.fromCourse(course, records)),
      error: (error, stack) => AsyncError(error, stack),
      loading: () => const AsyncLoading(),
    ),
    error: (error, stack) => AsyncError(error, stack),
    loading: () => const AsyncLoading(),
  );
});

void retryLearningPath(WidgetRef ref) {
  ref.invalidate(courseCatalogProvider);
  ref.invalidate(lessonProgressProvider);
}
