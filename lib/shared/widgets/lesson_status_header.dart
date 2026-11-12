import 'lingo_components.dart';
import '../../core/localization/lingo_localizations.dart';
import '../../core/theme/lingo_tokens.dart';

import 'package:flutter/material.dart';

class LessonStatusHeader extends StatelessWidget {
  const LessonStatusHeader({
    super.key,
    required this.cleared,
    required this.total,
    required this.hearts,
  });
  final int cleared;
  final int total;
  final int hearts;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LingoSpace.s24,
      LingoSpace.s8,
      LingoSpace.s24,
      LingoSpace.s8,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LingoProgress(
                value: total == 0 ? 0 : cleared / total,
                label: context.l10n.text('ui8fcc5d670c', {
                  'arg0': (cleared),
                  'arg1': (total),
                }),
              ),
            ),
            const SizedBox(width: LingoSpace.s16),
            Semantics(
              label: context.l10n.text('uif241f57f2b', {'arg0': (hearts)}),
              liveRegion: true,
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    3,
                    (index) => Icon(
                      index < hearts ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: LingoSpace.s8),
        Text(
          context.l10n.text('uib3432c3193', {
            'arg0': (cleared),
            'arg1': (total),
          }),
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    ),
  );
}
