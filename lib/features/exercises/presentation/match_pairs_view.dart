import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/answer_option.dart';
import '../domain/exercise.dart';

class MatchPairsView extends StatelessWidget {
  const MatchPairsView({
    super.key,
    required this.exercise,
    required this.matches,
    required this.rightOrder,
    required this.selectedLeft,
    required this.selectedRight,
    required this.enabled,
    required this.onLeft,
    required this.onRight,
  });
  final MatchPairs exercise;
  final Map<int, int> matches;
  final List<int> rightOrder;
  final int? selectedLeft;
  final int? selectedRight;
  final bool enabled;
  final ValueChanged<int> onLeft;
  final ValueChanged<int> onRight;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.l10n.text('uicdc10ab67f'),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: LingoSpace.s8),
      Text(context.l10n.text('ui2f381d8f15')),
      const SizedBox(height: LingoSpace.s24),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < exercise.pairs.length; i++)
                  AnswerOption(
                    key: ValueKey('pair-left-$i'),
                    label: exercise.pairs[i].left,
                    selected: selectedLeft == i || matches.containsKey(i),
                    pairLabel: matches.containsKey(i)
                        ? context.l10n.text('ui0cbf36e177', {'arg0': i + 1})
                        : null,
                    onTap: enabled ? () => onLeft(i) : null,
                  ),
              ],
            ),
          ),
          const SizedBox(width: LingoSpace.s8),
          Expanded(
            child: Column(
              children: [
                for (final i in rightOrder)
                  _RightCard(
                    index: i,
                    exercise: exercise,
                    matches: matches,
                    pending: selectedRight == i,
                    onTap: enabled ? () => onRight(i) : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

class _RightCard extends StatelessWidget {
  const _RightCard({
    required this.index,
    required this.exercise,
    required this.matches,
    required this.pending,
    this.onTap,
  });
  final int index;
  final MatchPairs exercise;
  final Map<int, int> matches;
  final bool pending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final paired = matches.entries
        .where((entry) => entry.value == index)
        .firstOrNull;
    return AnswerOption(
      key: ValueKey('pair-right-$index'),
      label: exercise.pairs[index].right,
      selected: pending || paired != null,
      pairLabel: paired == null
          ? null
          : context.l10n.text('ui0cbf36e177', {'arg0': (paired.key + 1)}),
      onTap: onTap,
    );
  }
}
