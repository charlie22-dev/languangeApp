import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/async_status_view.dart';
import '../../../shared/widgets/choice_card.dart';
import '../data/course_catalog.dart';
import 'onboarding_controller.dart';
import 'onboarding_frame.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(courseCatalogProvider);
    final selectedId = ref.watch(onboardingFlowProvider).courseId;
    return OnboardingFrame(
      step: 2,
      title: 'What would you like to learn?',
      subtitle: 'Choose a language to begin your journey.',
      onBack: () => context.go(AppRoutes.welcome),
      child: courses.when(
        skipLoadingOnRefresh: false,
        loading: () => const AsyncStatusView(
          message: 'Finding your languages…',
          loading: true,
        ),
        error: (error, stack) => AsyncStatusView(
          message: 'Languages could not be loaded.',
          onRetry: () => ref.invalidate(courseCatalogProvider),
        ),
        data: (items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (items.isEmpty)
              const Text('There are no languages available yet.'),
            for (final course in items)
              ChoiceCard(
                key: ValueKey('language-${course.id}'),
                title: course.targetLanguage,
                subtitle: 'For ${course.nativeLanguage} speakers',
                selected: course.id == selectedId,
                onTap: () => ref
                    .read(onboardingFlowProvider.notifier)
                    .selectCourse(course.id),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: items.any((course) => course.id == selectedId)
                  ? () => context.go(AppRoutes.dailyGoal)
                  : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
