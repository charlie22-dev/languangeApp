import '../../core/localization/lingo_localizations.dart';
import '../../core/theme/lingo_tokens.dart';

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
      LessonAvailability.locked => context.l10n.text('uia798882f1c'),
      LessonAvailability.available => context.l10n.text('ui567bfc4dad'),
      LessonAvailability.completed => context.l10n.text('ui1798b3ba42'),
    };
    final foreground = completed
        ? colors.onTertiaryContainer
        : colors.onPrimary;
    return Semantics(
      label: context.l10n.text('ui1e23c12d37', {
        'arg0': (number),
        'arg1': (entry.lesson.title),
        'arg2': (label),
        'arg3': (completed
            ? context.l10n.text('starsSuffix', {'count': entry.stars})
            : ''),
      }),
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
                  shape: CircleBorder(
                    side: BorderSide(
                      color: colors.outline,
                      width: LingoSpace.border,
                    ),
                  ),
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
            const SizedBox(height: LingoSpace.s8),
            Text(
              entry.lesson.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: LingoSpace.s8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            if (completed)
              Padding(
                padding: const EdgeInsets.only(top: LingoSpace.s8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    3,
                    (index) => Icon(
                      index < entry.stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 24,
                      color: colors.onSurface,
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
