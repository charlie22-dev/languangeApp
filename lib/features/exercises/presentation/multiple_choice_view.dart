import '../../../core/theme/lingo_tokens.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/answer_option.dart';
import '../domain/exercise.dart';

class MultipleChoiceView extends StatelessWidget {
  const MultipleChoiceView({
    super.key,
    required this.exercise,
    required this.selectedIndex,
    required this.enabled,
    required this.onSelected,
    this.feedbackCorrect,
  });
  final MultipleChoice exercise;
  final int? selectedIndex;
  final bool? feedbackCorrect;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(exercise.prompt, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: LingoSpace.s24),
      for (var i = 0; i < exercise.options.length; i++)
        AnswerOption(
          key: ValueKey('choice-$i'),
          label: exercise.options[i],
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
