import '../../../shared/widgets/lingo_components.dart';
import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/choice_card.dart';
import '../domain/onboarding_settings.dart';
import 'onboarding_controller.dart';
import 'onboarding_frame.dart';

class DailyGoalScreen extends ConsumerWidget {
  const DailyGoalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingFlowProvider);
    return OnboardingFrame(
      step: 3,
      title: context.l10n.text('ui761beeaed8'),
      subtitle: context.l10n.text('ui59db5ecbf3'),
      onBack: draft.saving ? null : () => context.go(AppRoutes.languages),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final minutes in dailyGoalMinutes)
            ChoiceCard(
              key: ValueKey('goal-$minutes'),
              title: context.l10n.text('uia1e6de2a3f', {'arg0': (minutes)}),
              subtitle: switch (minutes) {
                5 => context.l10n.text('uib1a59fc993'),
                10 => context.l10n.text('uic07031fb73'),
                _ => context.l10n.text('uif3c636e0ef'),
              },
              icon: Icons.schedule,
              selected: minutes == draft.goalMinutes,
              onTap: draft.saving
                  ? null
                  : () => ref
                        .read(onboardingFlowProvider.notifier)
                        .selectGoal(minutes),
            ),
          if (draft.error != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                draft.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            const SizedBox(height: LingoSpace.s16),
          ],
          const SizedBox(height: LingoSpace.s8),
          LingoButton(
            onPressed: draft.saving
                ? null
                : () => ref.read(onboardingFlowProvider.notifier).finish(),
            child: Text(
              draft.saving
                  ? context.l10n.text('saving')
                  : context.l10n.text('ui02d279ce2f'),
            ),
          ),
        ],
      ),
    );
  }
}
