import '../../../shared/widgets/lingo_components.dart';
import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/pip_mascot.dart';

import '../domain/review_session.dart';

class ReviewSummary extends StatelessWidget {
  const ReviewSummary({
    super.key,
    required this.session,
    required this.onContinue,
  });
  final ReviewSession session;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PipMascot(mood: PipMood.celebrating),
      const SizedBox(height: LingoSpace.s24),
      Text(
        context.l10n.text('ui1155cfbf6f'),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: LingoSpace.s8),
      Text(
        context.l10n.text(
          session.index == 1 ? 'reviewedCard' : 'reviewedCards',
          {'count': session.index},
        ),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: LingoSpace.s24),
      for (final rating in ReviewRating.values)
        Card.filled(
          child: Padding(
            padding: const EdgeInsets.all(LingoSpace.s16),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: LingoSpace.s16,
              runSpacing: LingoSpace.s8,
              children: [
                Text(context.l10n.message(rating.label)),
                Text('${session.ratings[rating] ?? 0}'),
              ],
            ),
          ),
        ),
      const SizedBox(height: LingoSpace.s24),
      LingoButton(
        onPressed: onContinue,
        child: Text(context.l10n.text('ui2e02623966')),
      ),
    ],
  );
}
