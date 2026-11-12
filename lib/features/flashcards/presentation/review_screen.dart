import '../../../shared/widgets/lingo_components.dart';
import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';

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
    appBar: AppBar(title: Text(context.l10n.text('uie29a79fe0c'))),
    body: ref
        .watch(reviewOverviewProvider)
        .when(
          skipLoadingOnRefresh: false,
          loading: () => AsyncStatusView(
            message: context.l10n.text('uia255804c0f'),
            loading: true,
          ),
          error: (error, stack) => AsyncStatusView(
            message: context.l10n.text('ui0168f01327'),
            onRetry: () => retryReviewData(ref),
          ),
          data: (overview) => ResponsiveBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.text(
                    overview.dueCount == 1 ? 'cardDue' : 'cardsDue',
                    {'count': overview.dueCount},
                  ),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: LingoSpace.s8),
                Text(context.l10n.text('uibf6e7b0ea9')),
                const SizedBox(height: LingoSpace.s32),
                if (overview.dueCount == 0)
                  ReviewEmptyState(overview: overview)
                else ...[
                  Text(
                    context.l10n.text('ui141dbef819'),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: LingoSpace.s24),
                  LingoButton(
                    key: const ValueKey('start-review'),
                    onPressed: () => context.push(AppRoutes.reviewSession),
                    child: Text(context.l10n.text('ui952f375412')),
                  ),
                ],
              ],
            ),
          ),
        ),
  );
}
