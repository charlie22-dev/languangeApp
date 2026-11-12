import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';
import '../../../shared/widgets/pip_mascot.dart';
import '../../../shared/widgets/lingo_components.dart';
import '../../../shared/widgets/stat_badge.dart';
import '../../home/data/home_providers.dart';
import 'profile_display_provider.dart';

import '../../../shared/widgets/responsive_body.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/account_controller.dart';
import '../../sync/data/sync_service.dart';
import '../../sync/presentation/sync_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authStateProvider).asData?.value;
    final action = ref.watch(accountControllerProvider);
    final display = ref.watch(profileDisplayProvider).asData?.value;
    final stats = ref.watch(userStatsProvider);
    final course = ref.watch(selectedCourseProvider).asData?.value;
    final status = ref.watch(syncStatusProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.text('uiff4fc0276e')),
        actions: [
          IconButton(
            tooltip: context.l10n.text('settings'),
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: PipMascot()),
            if (display?.name?.trim().isNotEmpty ?? false)
              Text(
                display!.name!,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            Text(
              context.l10n.text('ui4ab2910209'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: LingoSpace.s16),
            Text(
              account?.email ?? '',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: LingoSpace.s24),
            if (course != null)
              Text(
                course.targetLanguage,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            const SizedBox(height: LingoSpace.s16),
            stats.when(
              data: (value) => Wrap(
                spacing: LingoSpace.s8,
                runSpacing: LingoSpace.s8,
                children: [
                  StatBadge(
                    icon: Icons.bolt,
                    label: context.l10n.text('ui122bc8d96b', {
                      'arg0': (value.xp),
                    }),
                  ),
                  StatBadge(
                    icon: Icons.local_fire_department_outlined,
                    label: context.l10n.text('streakDays', {
                      'count': value.streak,
                    }),
                  ),
                  if (display != null)
                    StatBadge(
                      icon: Icons.style_outlined,
                      label: context.l10n.text('wordsInReview', {
                        'count': display.words,
                      }),
                    ),
                ],
              ),
              loading: () => const LingoSkeleton(),
              error: (e, s) =>
                  Text(context.l10n.text('profileStatsUnavailable')),
            ),
            const SizedBox(height: LingoSpace.s24),
            LingoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.text('weeklyActivity'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: LingoSpace.s16),
                  Text(context.l10n.text('activityUnavailable')),
                ],
              ),
            ),
            const SizedBox(height: LingoSpace.s24),
            Text(switch (status) {
              SyncStatus.idle => context.l10n.text('uid58fb3ff7c'),
              SyncStatus.syncing => context.l10n.text('ui507ccad9a4'),
              SyncStatus.offline => context.l10n.text('uide7ff3fdf2'),
            }),
            const SizedBox(height: LingoSpace.s8),
            LingoButton.outlined(
              onPressed: status == SyncStatus.syncing
                  ? null
                  : () => ref.read(syncServiceProvider)?.request(),
              child: Text(context.l10n.text('ui2b7d938e67')),
            ),
            const SizedBox(height: LingoSpace.s24),
            if (action.error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  context.l10n.message(action.error!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            LingoButton.tonal(
              onPressed: action.busy
                  ? null
                  : ref.read(accountControllerProvider.notifier).signOut,
              child: Text(
                action.busy
                    ? context.l10n.text('signingOut')
                    : context.l10n.text('uidc1649a16c'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
