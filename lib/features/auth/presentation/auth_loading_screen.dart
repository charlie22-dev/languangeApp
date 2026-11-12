import '../../../core/localization/lingo_localizations.dart';

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
            ? context.l10n.text('uif6021dbc0e')
            : context.l10n.text('uidfa9ed40fe'),
        onRetry: ready.hasError
            ? () => ref.invalidate(accountReadyProvider)
            : null,
      ),
    );
  }
}
