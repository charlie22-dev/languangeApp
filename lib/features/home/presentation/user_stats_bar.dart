import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/stat_badge.dart';
import '../data/home_providers.dart';

class UserStatsBar extends ConsumerWidget {
  const UserStatsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
    child: ref
        .watch(userStatsProvider)
        .when(
          skipLoadingOnRefresh: false,
          loading: () => const LinearProgressIndicator(
            semanticsLabel: 'Loading streak and XP',
          ),
          error: (error, stack) => Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              const Text('Stats could not be loaded.'),
              TextButton(
                onPressed: () => ref.invalidate(userStatsProvider),
                child: const Text('Retry stats'),
              ),
            ],
          ),
          data: (stats) => Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              StatBadge(
                icon: Icons.local_fire_department_outlined,
                label:
                    '${stats.streak} ${stats.streak == 1 ? 'day' : 'days'} streak',
              ),
              StatBadge(icon: Icons.bolt, label: '${stats.xp} XP'),
            ],
          ),
        ),
  );
}
