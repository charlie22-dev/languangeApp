import 'package:flutter/material.dart';

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
        title: const Text('Results'),
        leading: IconButton(
          tooltip: 'Close results',
          onPressed: session.saving ? null : onClose,
          icon: const Icon(Icons.close),
        ),
      ),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              result.success
                  ? Icons.emoji_events_outlined
                  : Icons.favorite_border,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              result.success ? 'Lesson complete!' : 'Out of hearts',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              result.success
                  ? 'Your practice is paying off.'
                  : 'A fresh start is another chance to learn.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            _ResultMetric(label: 'Accuracy', value: '${result.score}%'),
            _ResultMetric(label: 'XP earned', value: '${result.xp} XP'),
            _ResultMetric(
              label: 'Correct attempts',
              value: '${result.correctCount} / ${result.attempts}',
            ),
            if (result.success)
              Text(
                '10 base XP + 5 × ${result.perfectCount} first-try exercises',
              ),
            const SizedBox(height: 24),
            if (session.saving)
              Semantics(
                liveRegion: true,
                child: const Text('Saving your progress…'),
              ),
            if (session.saveError != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  session.saveError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Retry saving'),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: !result.success || session.saved ? onContinue : null,
              child: const Text('Continue'),
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
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
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
