import 'package:flutter/material.dart';

import '../../features/exercises/domain/exercise_grader.dart';

class AnswerFeedbackSheet extends StatelessWidget {
  const AnswerFeedbackSheet({super.key, required this.feedback});
  final AnswerFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: theme.brightness,
    );
    final background = feedback.correct
        ? success.primaryContainer
        : theme.colorScheme.errorContainer;
    final foreground = feedback.correct
        ? success.onPrimaryContainer
        : theme.colorScheme.onErrorContainer;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  feedback.correct
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: foreground,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    feedback.correct ? 'Correct!' : 'Not quite',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Correct answer:\n${feedback.correctAnswer}',
              style: theme.textTheme.bodyLarge?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
