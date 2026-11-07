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
  });
  final FillInBlank exercise;
  final int? selectedIndex;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Fill in the blank',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      Text(
        exercise.sentenceWithBlank,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 24),
      for (var i = 0; i < exercise.choices.length; i++)
        AnswerOption(
          key: ValueKey('choice-$i'),
          label: exercise.choices[i],
          selected: selectedIndex == i,
          onTap: enabled ? () => onSelected(i) : null,
        ),
    ],
  );
}
