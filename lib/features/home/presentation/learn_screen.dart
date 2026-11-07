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
                loading: () => const AsyncStatusView(
                  message: 'Loading your learning path…',
                  loading: true,
                ),
                error: (error, stack) => AsyncStatusView(
                  message: 'Your lessons could not be loaded.',
                  onRetry: () => retryLearningPath(ref),
                ),
                data: (path) => path.lessons.isEmpty
                    ? const AsyncStatusView(
                        message: 'There are no lessons in this course yet.',
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
