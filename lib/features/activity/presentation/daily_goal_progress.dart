import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/lingo_localizations.dart';
import '../../../shared/widgets/lingo_components.dart';
import '../../../shared/widgets/pip_mascot.dart';
import '../../../core/theme/lingo_tokens.dart';
import '../data/activity_providers.dart';

class DailyGoalProgress extends ConsumerWidget {
  const DailyGoalProgress({super.key, required this.minutes});
  final int minutes;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(activitySummaryProvider)
      .when(
        loading: () => const LingoSkeleton(),
        error: (error, stack) => Text(context.l10n.text('activityLoadError')),
        data: (summary) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DailyGoalCard(
              minutes: minutes,
              label: context.l10n.text('dailyXpProgress', {
                'earned': summary.todayXp,
                'target': summary.target,
              }),
              detail: context.l10n.text('dailyGoalMinutes', {
                'minutes': minutes,
              }),
              progress: summary.fraction,
              complete: summary.goalDone,
            ),
            if (summary.goalDone)
              Padding(
                padding: const EdgeInsets.only(top: LingoSpace.s8),
                child: CelebrationPulse(
                  key: ValueKey(summary.days.last),
                  child: Column(
                    children: [
                      const PipMascot(
                        mood: PipMood.celebrating,
                        size: LingoSpace.node,
                      ),
                      Semantics(
                        liveRegion: true,
                        child: Text(context.l10n.text('dailyGoalReached')),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}
