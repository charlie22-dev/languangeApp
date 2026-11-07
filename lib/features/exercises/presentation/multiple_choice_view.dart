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
  });
  final MultipleChoice exercise;
  final int? selectedIndex;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(exercise.prompt, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 24),
      for (var i = 0; i < exercise.options.length; i++)
        AnswerOption(
          key: ValueKey('choice-$i'),
          label: exercise.options[i],
          selected: selectedIndex == i,
          onTap: enabled ? () => onSelected(i) : null,
        ),
    ],
  );
}
