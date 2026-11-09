import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final status = ref.watch(syncStatusProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your account',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              account?.email ?? '',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text(switch (status) {
              SyncStatus.idle => 'Sync ready',
              SyncStatus.syncing => 'Syncing your progress...',
              SyncStatus.offline =>
                'Offline. Changes are saved on this device.',
            }),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: status == SyncStatus.syncing
                  ? null
                  : () => ref.read(syncServiceProvider)?.request(),
              child: const Text('Sync now'),
            ),
            const SizedBox(height: 24),
            if (action.error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  action.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton.tonal(
              onPressed: action.busy
                  ? null
                  : ref.read(accountControllerProvider.notifier).signOut,
              child: Text(action.busy ? 'Signing out...' : 'Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
