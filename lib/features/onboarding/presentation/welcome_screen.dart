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
    final colors = Theme.of(context).colorScheme;
    return OnboardingFrame(
      step: 1,
      title: config.appName,
      subtitle: 'A new language. A little practice. Every day.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.translate,
                size: 48,
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            config.hasLanguagePair
                ? 'Learn ${config.targetLanguage} with guidance in ${config.nativeLanguage}.'
                : 'Start a learning habit that fits your life.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => context.go(AppRoutes.languages),
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }
}
