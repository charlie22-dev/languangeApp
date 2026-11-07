import 'package:flutter/material.dart';

import '../../features/home/domain/learning_path.dart';

class LessonPathNode extends StatelessWidget {
  const LessonPathNode({
    super.key,
    required this.entry,
    required this.number,
    this.onPressed,
  });
  final LessonPathEntry entry;
  final int number;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final completed = entry.availability == LessonAvailability.completed;
    final locked = entry.availability == LessonAvailability.locked;
    final label = switch (entry.availability) {
      LessonAvailability.locked => 'Locked',
      LessonAvailability.available => 'Up next',
      LessonAvailability.completed => 'Completed',
    };
    final foreground = completed
        ? colors.onTertiaryContainer
        : colors.onPrimary;
    return Semantics(
      label:
          'Lesson $number: ${entry.lesson.title}. $label${completed ? ', ${entry.stars} of 3 stars' : ''}.',
      button: true,
      enabled: !locked,
      onTap: locked ? null : onPressed,
      child: ExcludeSemantics(
        child: Column(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: FilledButton(
                onPressed: locked ? null : onPressed,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  backgroundColor: completed
                      ? colors.tertiaryContainer
                      : colors.primary,
                  foregroundColor: foreground,
                  disabledBackgroundColor: colors.surfaceContainerHighest,
                  disabledForegroundColor: colors.onSurfaceVariant,
                ),
                child: Icon(
                  locked
                      ? Icons.lock_outline
                      : completed
                      ? Icons.check
                      : Icons.play_arrow_rounded,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              entry.lesson.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            if (completed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    3,
                    (index) => Icon(
                      index < entry.stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 24,
                      color: colors.tertiary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
