import '../../../shared/widgets/lingo_components.dart';
import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/data/home_providers.dart';
import '../../../shared/widgets/stat_badge.dart';

import '../../../shared/widgets/pip_mascot.dart';

import '../../../shared/widgets/responsive_body.dart';
import '../domain/lesson_session.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    required this.session,
    required this.onContinue,
    required this.onRetry,
    required this.onClose,
  });
  final LessonSession session;
  final VoidCallback onContinue;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final result = session.result!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(context.l10n.text('ui612e12d292')),
        leading: IconButton(
          tooltip: context.l10n.text('uib9a0e74637'),
          onPressed: session.saving ? null : onClose,
          icon: const Icon(Icons.close),
        ),
      ),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PipMascot(mood: result.success ? PipMood.celebrating : PipMood.sad),
            const SizedBox(height: LingoSpace.s24),
            Text(
              result.success
                  ? context.l10n.text('lessonComplete')
                  : context.l10n.text('ui0c169c0cd5'),
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: LingoSpace.s8),
            Text(
              result.success
                  ? context.l10n.text('ui6af0fa544c')
                  : context.l10n.text('ui27bf448b30'),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: LingoSpace.s24),
            _ResultMetric(
              label: context.l10n.text('ui12a3a4f498'),
              value: context.l10n.text('ui6fdde657b8', {
                'arg0': (result.score),
              }),
            ),
            _ResultMetric(
              label: context.l10n.text('ui5e7a5b54d3'),
              value: context.l10n.text('ui122bc8d96b', {'arg0': (result.xp)}),
            ),
            _ResultMetric(
              label: context.l10n.text('ui1fed869b77'),
              value: context.l10n.text('ui3c1eaed8e8', {
                'arg0': (result.correctCount),
                'arg1': (result.attempts),
              }),
            ),
            if (result.success)
              Text(
                context.l10n.text('ui4f01e308ca', {
                  'arg0': (result.perfectCount),
                }),
              ),
            const SizedBox(height: LingoSpace.s24),
            if (result.success && session.saved) const _SavedStreak(),
            if (session.saving)
              Semantics(
                liveRegion: true,
                child: Text(context.l10n.text('ui0884c92a27')),
              ),
            if (session.saveError != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  context.l10n.message(session.saveError!),
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
              ),
              const SizedBox(height: LingoSpace.s8),
              LingoButton.outlined(
                onPressed: onRetry,
                child: Text(context.l10n.text('ui71e1aa94f8')),
              ),
            ],
            const SizedBox(height: LingoSpace.s16),
            LingoButton(
              onPressed: !result.success || session.saved ? onContinue : null,
              child: Text(context.l10n.text('ui2e02623966')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card.filled(
    child: Padding(
      padding: const EdgeInsets.all(LingoSpace.s16),
      child: Wrap(
        spacing: LingoSpace.s16,
        runSpacing: LingoSpace.s8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(label),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    ),
  );
}

class _SavedStreak extends ConsumerWidget {
  const _SavedStreak();
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(userStatsProvider)
      .maybeWhen(
        data: (stats) => Padding(
          padding: const EdgeInsets.only(bottom: LingoSpace.s24),
          child: Center(
            child: CelebrationPulse(
              child: StatBadge(
                icon: Icons.local_fire_department_outlined,
                label: context.l10n.text(
                  stats.streak == 1 ? 'streakDay' : 'streakDays',
                  {'count': stats.streak},
                ),
              ),
            ),
          ),
        ),
        orElse: () => const SizedBox.shrink(),
      );
}
