import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_status_view.dart';
import 'onboarding_controller.dart';

class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(onboardingProvider);
    return Scaffold(
      body: AsyncStatusView(
        message: settings.hasError
            ? 'Your preferences could not be loaded.'
            : 'Getting ready…',
        loading: !settings.hasError,
        onRetry: settings.hasError
            ? () => ref.invalidate(onboardingProvider)
            : null,
      ),
    );
  }
}
