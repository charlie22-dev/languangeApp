import '../../../shared/widgets/lingo_components.dart';
import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/stat_badge.dart';
import '../data/home_providers.dart';

class UserStatsBar extends ConsumerWidget {
  const UserStatsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LingoSpace.s16,
      LingoSpace.s8,
      LingoSpace.s16,
      LingoSpace.s8,
    ),
    child: ref
        .watch(userStatsProvider)
        .when(
          skipLoadingOnRefresh: false,
          loading: () => LinearProgressIndicator(
            semanticsLabel: context.l10n.text('ui57d516df69'),
          ),
          error: (error, stack) => Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: LingoSpace.s8,
            children: [
              Text(context.l10n.text('uid53bd88ff7')),
              LingoButton.ghost(
                onPressed: () => ref.invalidate(userStatsProvider),
                child: Text(context.l10n.text('ui694b8bb261')),
              ),
            ],
          ),
          data: (stats) => Wrap(
            spacing: LingoSpace.s8,
            runSpacing: LingoSpace.s8,
            children: [
              StatBadge(
                icon: Icons.local_fire_department_outlined,
                label: context.l10n.text(
                  stats.streak == 1 ? 'streakDay' : 'streakDays',
                  {'count': stats.streak},
                ),
              ),
              StatBadge(
                icon: Icons.bolt,
                label: context.l10n.text('ui122bc8d96b', {'arg0': (stats.xp)}),
              ),
            ],
          ),
        ),
  );
}
