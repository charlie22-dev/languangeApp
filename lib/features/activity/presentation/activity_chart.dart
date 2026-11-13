import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';
import '../data/activity_providers.dart';

class ActivityChart extends StatelessWidget {
  const ActivityChart({super.key, required this.summary});
  final ActivitySummary summary;
  @override
  Widget build(BuildContext context) {
    final maximum = max(1, summary.xpByDay.reduce(max));
    final colors = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Semantics(
                  label: context.l10n.text('activityDayLabel', {
                    'day': DateFormat.yMMMd(locale).format(summary.days[i]),
                    'xp': summary.xpByDay[i],
                  }),
                  child: Tooltip(
                    message: '${summary.xpByDay[i]}',
                    child: ExcludeSemantics(
                      child: Column(
                        children: [
                          SizedBox(
                            height: LingoSpace.node,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: LingoSpace.s16,
                                height: summary.xpByDay[i] == 0
                                    ? LingoSpace.border
                                    : LingoSpace.node *
                                          summary.xpByDay[i] /
                                          maximum,
                                decoration: BoxDecoration(
                                  color: colors.secondaryContainer,
                                  border: Border.all(
                                    color: colors.outline,
                                    width: LingoSpace.border,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    LingoRadii.pill,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: LingoSpace.s8),
                          Text(
                            DateFormat('EEEEE', locale).format(summary.days[i]),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: LingoSpace.s16),
        Text(
          context.l10n.text('weeklyXpTotal', {
            'xp': summary.xpByDay.fold<int>(0, (a, b) => a + b),
          }),
        ),
      ],
    );
  }
}
