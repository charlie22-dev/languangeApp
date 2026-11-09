import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_status_view.dart';
import '../../sync/presentation/sync_providers.dart';
import '../data/auth_repository.dart';

class AuthLoadingScreen extends ConsumerWidget {
  const AuthLoadingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(authStateProvider).asData?.value;
    final ready = identity == null
        ? const AsyncLoading<void>()
        : ref.watch(accountReadyProvider);
    return Scaffold(
      body: AsyncStatusView(
        loading: !ready.hasError,
        message: ready.hasError
            ? 'Your local progress could not be opened.'
            : 'Opening your local progress…',
        onRetry: ready.hasError
            ? () => ref.invalidate(accountReadyProvider)
            : null,
      ),
    );
  }
}
