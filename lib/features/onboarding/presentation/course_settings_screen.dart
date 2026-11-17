import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';
import '../../../shared/widgets/async_status_view.dart';
import '../../../shared/widgets/choice_card.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../data/course_catalog.dart';
import 'course_selection_controller.dart';
import 'onboarding_controller.dart';

class CourseSettingsScreen extends ConsumerWidget {
  const CourseSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(courseCatalogProvider);
    final action = ref.watch(courseSelectionProvider);
    final selected = ref.watch(onboardingProvider).asData?.value?.courseId;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.text('learningLanguage'))),
      body: ResponsiveBody(
        child: catalog.when(
          loading: () => AsyncStatusView(
            message: context.l10n.text('ui6a0080099f'),
            loading: true,
          ),
          error: (_, _) => AsyncStatusView(
            message: context.l10n.text('ui5241cba79b'),
            onRetry: () => ref.invalidate(courseCatalogProvider),
          ),
          data: (courses) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.text('languageProgressPreserved')),
              const SizedBox(height: LingoSpace.s16),
              if (action.isLoading) const LinearProgressIndicator(),
              if (action.hasError)
                Text(
                  context.l10n.text('languageSaveError'),
                  semanticsLabel: context.l10n.text('languageSaveError'),
                ),
              if (courses.isEmpty) Text(context.l10n.text('ui7e0cbe2650')),
              for (final course in courses)
                ChoiceCard(
                  key: ValueKey('switch-${course.id}'),
                  title: course.targetLanguage,
                  subtitle: context.l10n.text('uief93d6c6a2', {
                    'arg0': course.nativeLanguage,
                  }),
                  selected: selected == course.id,
                  onTap: action.isLoading
                      ? null
                      : () => ref
                            .read(courseSelectionProvider.notifier)
                            .select(course.id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
