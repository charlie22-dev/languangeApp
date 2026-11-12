import '../../../core/theme/lingo_tokens.dart';
import '../../../shared/widgets/lingo_components.dart';
import '../../../core/localization/lingo_localizations.dart';

import 'package:flutter/material.dart';

import '../domain/review_session.dart';

class ReviewRatingButtons extends StatelessWidget {
  const ReviewRatingButtons({
    super.key,
    required this.enabled,
    required this.onRating,
  });
  final bool enabled;
  final ValueChanged<ReviewRating> onRating;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: LingoSpace.s16,
      runSpacing: LingoSpace.s16,
      children: [
        for (final rating in ReviewRating.values)
          SizedBox(
            width: (constraints.maxWidth - LingoSpace.s16) / 2,
            child: LingoButton.outlined(
              key: ValueKey('rate-${rating.name}'),
              onPressed: enabled ? () => onRating(rating) : null,
              style: OutlinedButton.styleFrom(
                backgroundColor: switch (rating) {
                  ReviewRating.again => Theme.of(
                    context,
                  ).colorScheme.errorContainer,
                  ReviewRating.hard => Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  ReviewRating.good => Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  ReviewRating.easy => context.lingo.success,
                },
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                disabledBackgroundColor: context.lingo.disabled,
                disabledForegroundColor: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
              child: Text(
                context.l10n.message(rating.label),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    ),
  );
}
