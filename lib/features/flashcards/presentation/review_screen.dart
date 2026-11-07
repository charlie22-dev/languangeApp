import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/async_status_view.dart';
import '../../../shared/widgets/responsive_body.dart';
import 'review_empty_state.dart';
import 'review_providers.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(reviewOverviewProvider);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review')),
    body: ref
        .watch(reviewOverviewProvider)
        .when(
          skipLoadingOnRefresh: false,
          loading: () => const AsyncStatusView(
            message: 'Checking your review deck...',
            loading: true,
          ),
          error: (error, stack) => AsyncStatusView(
            message: 'Your review deck could not be loaded.',
            onRetry: () => retryReviewData(ref),
          ),
          data: (overview) => ResponsiveBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${overview.dueCount} ${overview.dueCount == 1 ? 'card' : 'cards'} due today',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Includes overdue cards. Cards become available at their scheduled time.',
                ),
                const SizedBox(height: 32),
                if (overview.dueCount == 0)
                  ReviewEmptyState(overview: overview)
                else ...[
                  Text(
                    'A little review helps your words stay with you.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const ValueKey('start-review'),
                    onPressed: () => context.push(AppRoutes.reviewSession),
                    child: const Text('Start'),
                  ),
                ],
              ],
            ),
          ),
        ),
  );
}
