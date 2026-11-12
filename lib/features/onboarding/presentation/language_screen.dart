import '../../../shared/widgets/lingo_components.dart';
import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';

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
      title: context.l10n.text('ui19a3d02735'),
      subtitle: context.l10n.text('ui0edffe822e'),
      onBack: () => context.go(AppRoutes.welcome),
      child: courses.when(
        skipLoadingOnRefresh: false,
        loading: () => AsyncStatusView(
          message: context.l10n.text('ui6a0080099f'),
          loading: true,
        ),
        error: (error, stack) => AsyncStatusView(
          message: context.l10n.text('ui5241cba79b'),
          onRetry: () => ref.invalidate(courseCatalogProvider),
        ),
        data: (items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (items.isEmpty) Text(context.l10n.text('ui7e0cbe2650')),
            for (final course in items)
              ChoiceCard(
                key: ValueKey('language-${course.id}'),
                title: course.targetLanguage,
                subtitle: context.l10n.text('uief93d6c6a2', {
                  'arg0': (course.nativeLanguage),
                }),
                selected: course.id == selectedId,
                onTap: () => ref
                    .read(onboardingFlowProvider.notifier)
                    .selectCourse(course.id),
              ),
            const SizedBox(height: LingoSpace.s8),
            LingoButton(
              onPressed: items.any((course) => course.id == selectedId)
                  ? () => context.go(AppRoutes.dailyGoal)
                  : null,
              child: Text(context.l10n.text('ui2e02623966')),
            ),
          ],
        ),
      ),
    );
  }
}
