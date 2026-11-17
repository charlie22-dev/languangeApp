import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/course_catalog.dart';
import '../domain/onboarding_settings.dart';
import 'onboarding_controller.dart';

final courseSelectionProvider =
    AsyncNotifierProvider.autoDispose<CourseSelectionController, void>(
      CourseSelectionController.new,
    );

/// Changing courses preserves the daily goal and all course-specific progress.
class CourseSelectionController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<bool> select(String courseId) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      final courses = await ref.read(courseCatalogProvider.future);
      if (!ref.mounted) return false;
      final settings = ref.read(onboardingProvider).requireValue;
      if (settings == null || !courses.any((course) => course.id == courseId)) {
        throw StateError('Course selection is unavailable');
      }
      await ref
          .read(onboardingProvider.notifier)
          .complete(
            OnboardingSettings(
              courseId: courseId,
              goalMinutes: settings.goalMinutes,
            ),
          );
      if (!ref.mounted) return false;
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(error, stack);
      return false;
    }
  }
}
