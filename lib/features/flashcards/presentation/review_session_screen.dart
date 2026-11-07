import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/async_status_view.dart';
import '../../../shared/widgets/flippable_flashcard.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../domain/review_session.dart';
import 'review_empty_state.dart';
import 'review_providers.dart';
import 'review_rating_buttons.dart';
import 'review_summary.dart';

class ReviewSessionScreen extends ConsumerWidget {
  const ReviewSessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(reviewSessionProvider);
    final saving = value.asData?.value.saving ?? false;
    void leave() {
      if (!(ref.read(reviewSessionProvider).asData?.value.saving ?? false)) {
        context.go(AppRoutes.review);
      }
    }

    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Flashcards'),
          leading: IconButton(
            tooltip: 'Close review',
            onPressed: saving ? null : leave,
            icon: const Icon(Icons.close),
          ),
        ),
        body: value.when(
          skipLoadingOnRefresh: false,
          loading: () => const AsyncStatusView(
            message: 'Loading your flashcards…',
            loading: true,
          ),
          error: (error, stack) => AsyncStatusView(
            message: 'Your flashcards could not be loaded.',
            onRetry: () => retryReviewData(ref, session: true),
          ),
          data: (session) {
            if (session.cards.isEmpty) {
              return ref
                  .watch(reviewOverviewProvider)
                  .when(
                    data: (overview) => ResponsiveBody(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ReviewEmptyState(overview: overview),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: leave,
                            child: const Text('Back to Review'),
                          ),
                        ],
                      ),
                    ),
                    loading: () => const AsyncStatusView(
                      message: 'Checking your next review…',
                      loading: true,
                    ),
                    error: (error, stack) => AsyncStatusView(
                      message: 'Your next review could not be loaded.',
                      onRetry: () => retryReviewData(ref),
                    ),
                  );
            }
            if (session.finished) {
              return ResponsiveBody(
                child: ReviewSummary(session: session, onContinue: leave),
              );
            }
            return ResponsiveBody(child: _ReviewCardContent(session: session));
          },
        ),
      ),
    );
  }
}

class _ReviewCardContent extends ConsumerWidget {
  const _ReviewCardContent({required this.session});
  final ReviewSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(reviewSessionProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Card ${session.index + 1} of ${session.cards.length}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: session.index / session.cards.length,
          semanticsLabel: 'Review progress',
        ),
        const SizedBox(height: 24),
        FlippableFlashcard(
          key: ValueKey(session.currentCard!.id),
          word: session.currentCard!,
          revealed: session.revealed,
          onFlip: session.saving ? null : controller.flip,
        ),
        const SizedBox(height: 24),
        if (session.error != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              session.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          session.saving
              ? 'Saving rating…'
              : session.revealed
              ? 'How well did you remember?'
              : 'Reveal the answer before choosing a rating.',
        ),
        const SizedBox(height: 16),
        ReviewRatingButtons(
          enabled: session.revealed && !session.saving,
          onRating: controller.rate,
        ),
      ],
    );
  }
}
