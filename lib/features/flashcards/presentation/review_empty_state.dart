import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/pip_mascot.dart';

import 'package:intl/intl.dart';

import '../domain/review_session.dart';

class ReviewEmptyState extends StatelessWidget {
  const ReviewEmptyState({super.key, required this.overview});
  final ReviewOverview overview;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PipMascot(mood: PipMood.sleepy),
      const SizedBox(height: LingoSpace.s24),
      Text(
        overview.totalCards == 0
            ? context.l10n.text('ui7e2591d7d8')
            : context.l10n.text('uieeaebc0f53'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: LingoSpace.s8),
      Text(
        overview.nextDue == null
            ? context.l10n.text('uicb3d733d34')
            : context.l10n.text('ui067601e75f', {
                'arg0': (DateFormat('EEE, MMM d, y • h:mm a')
                    .format(overview.nextDue!.toLocal())),
              }),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ],
  );
}
