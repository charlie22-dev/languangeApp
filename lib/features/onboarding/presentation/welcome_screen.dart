import '../../../shared/widgets/lingo_components.dart';
import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_routes.dart';
import 'onboarding_frame.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return OnboardingFrame(
      step: 1,
      title: config.appName,
      subtitle: context.l10n.text('ui1d4123828b'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: LingoSpace.s24),
          Text(
            config.hasLanguagePair
                ? context.l10n.text('ui73e1f9f2e1', {
                    'arg0': (config.targetLanguage),
                    'arg1': (config.nativeLanguage),
                  })
                : context.l10n.text('ui79272f9bd7'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: LingoSpace.s32),
          LingoButton(
            onPressed: () => context.go(AppRoutes.languages),
            child: Text(context.l10n.text('uibd2cb05177')),
          ),
        ],
      ),
    );
  }
}
