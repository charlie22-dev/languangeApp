import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/answer_option.dart';
import '../domain/exercise.dart';

class FillInBlankView extends StatelessWidget {
  const FillInBlankView({
    super.key,
    required this.exercise,
    required this.selectedIndex,
    required this.enabled,
    required this.onSelected,
    this.feedbackCorrect,
  });
  final FillInBlank exercise;
  final int? selectedIndex;
  final bool? feedbackCorrect;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.l10n.text('ui4ea8375c1d'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: LingoSpace.s16),
      Text(
        exercise.sentenceWithBlank,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: LingoSpace.s24),
      for (var i = 0; i < exercise.choices.length; i++)
        AnswerOption(
          key: ValueKey('choice-$i'),
          label: exercise.choices[i],
          selected: selectedIndex == i,
          status: selectedIndex != i || feedbackCorrect == null
              ? AnswerVisualState.normal
              : feedbackCorrect!
              ? AnswerVisualState.correct
              : AnswerVisualState.wrong,
          onTap: enabled ? () => onSelected(i) : null,
        ),
    ],
  );
}
