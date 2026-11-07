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
      title: 'Make a little time for learning',
      subtitle: 'Choose a daily goal that fits your day.',
      onBack: draft.saving ? null : () => context.go(AppRoutes.languages),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final minutes in dailyGoalMinutes)
            ChoiceCard(
              key: ValueKey('goal-$minutes'),
              title: '$minutes minutes',
              subtitle: switch (minutes) {
                5 => 'Start small',
                10 => 'Build a steady habit',
                _ => 'Make more time to practice',
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
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: draft.saving
                ? null
                : () => ref.read(onboardingFlowProvider.notifier).finish(),
            child: Text(draft.saving ? 'Saving…' : 'Start learning'),
          ),
        ],
      ),
    );
  }
}
