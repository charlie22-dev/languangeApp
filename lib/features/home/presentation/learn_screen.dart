import '../../../core/localization/lingo_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/widgets/async_status_view.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import '../data/home_providers.dart';
import 'learning_path_view.dart';
import 'user_stats_bar.dart';

class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(learningPathProvider);
    final goal = ref.watch(onboardingProvider).value?.goalMinutes ?? 10;
    return Scaffold(
      appBar: AppBar(title: Text(ref.watch(appConfigProvider).appName)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const UserStatsBar(),
            Expanded(
              child: path.when(
                skipLoadingOnRefresh: false,
                loading: () => AsyncStatusView(
                  message: context.l10n.text('uiabcf5894a9'),
                  loading: true,
                ),
                error: (error, stack) => AsyncStatusView(
                  message: context.l10n.text('ui36d5d2cea8'),
                  onRetry: () => retryLearningPath(ref),
                ),
                data: (path) => path.lessons.isEmpty
                    ? AsyncStatusView(
                        message: context.l10n.text('uib2fc8d4d68'),
                      )
                    : LearningPathView(path: path, goalMinutes: goal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
