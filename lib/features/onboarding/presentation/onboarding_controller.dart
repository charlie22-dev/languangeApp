import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/course_catalog.dart';
import '../data/onboarding_repository.dart';
import '../domain/onboarding_settings.dart';

final onboardingProvider =
    AsyncNotifierProvider<OnboardingController, OnboardingSettings?>(
      OnboardingController.new,
      retry: (count, error) => null,
    );

class OnboardingController extends AsyncNotifier<OnboardingSettings?> {
  @override
  Future<OnboardingSettings?> build() =>
      ref.watch(onboardingRepositoryProvider).load();

  Future<void> complete(OnboardingSettings settings) async {
    await ref.read(onboardingRepositoryProvider).save(settings);
    if (ref.mounted) state = AsyncData(settings);
  }
}

final class OnboardingDraft {
  const OnboardingDraft({
    this.courseId,
    this.goalMinutes = 10,
    this.saving = false,
    this.error,
  });
  final String? courseId;
  final int goalMinutes;
  final bool saving;
  final String? error;
}

final onboardingFlowProvider =
    NotifierProvider<OnboardingFlowController, OnboardingDraft>(
      OnboardingFlowController.new,
    );

class OnboardingFlowController extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => const OnboardingDraft();

  void selectCourse(String courseId) {
    if (!state.saving) {
      state = OnboardingDraft(
        courseId: courseId,
        goalMinutes: state.goalMinutes,
      );
    }
  }

  void selectGoal(int minutes) {
    if (!state.saving && dailyGoalMinutes.contains(minutes)) {
      state = OnboardingDraft(courseId: state.courseId, goalMinutes: minutes);
    }
  }

  Future<void> finish() async {
    final draft = state;
    if (draft.saving || draft.courseId == null) return;
    state = OnboardingDraft(
      courseId: draft.courseId,
      goalMinutes: draft.goalMinutes,
      saving: true,
    );
    try {
      final courses = await ref.read(courseCatalogProvider.future);
      if (!courses.any((course) => course.id == draft.courseId)) {
        throw StateError('Selected course is unavailable');
      }
      await ref
          .read(onboardingProvider.notifier)
          .complete(
            OnboardingSettings(
              courseId: draft.courseId!,
              goalMinutes: draft.goalMinutes,
            ),
          );
      if (ref.mounted) {
        state = OnboardingDraft(
          courseId: draft.courseId,
          goalMinutes: draft.goalMinutes,
        );
      }
    } catch (_) {
      if (ref.mounted) {
        state = OnboardingDraft(
          courseId: draft.courseId,
          goalMinutes: draft.goalMinutes,
          error: 'Your choices could not be saved. Please try again.',
        );
      }
    }
  }
}
