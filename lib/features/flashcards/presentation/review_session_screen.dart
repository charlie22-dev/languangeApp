import '../../../shared/widgets/lingo_components.dart';
import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';

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
          title: Text(context.l10n.text('ui2c6822cced')),
          leading: IconButton(
            tooltip: context.l10n.text('ui8507ba7328'),
            onPressed: saving ? null : leave,
            icon: const Icon(Icons.close),
          ),
        ),
        body: value.when(
          skipLoadingOnRefresh: false,
          loading: () => AsyncStatusView(
            message: context.l10n.text('uieb0ecb146f'),
            loading: true,
          ),
          error: (error, stack) => AsyncStatusView(
            message: context.l10n.text('uia080fcba8d'),
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
                          const SizedBox(height: LingoSpace.s24),
                          LingoButton(
                            onPressed: leave,
                            child: Text(context.l10n.text('ui3ace0446ed')),
                          ),
                        ],
                      ),
                    ),
                    loading: () => AsyncStatusView(
                      message: context.l10n.text('uia61bcca965'),
                      loading: true,
                    ),
                    error: (error, stack) => AsyncStatusView(
                      message: context.l10n.text('ui08f0cc3fbf'),
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
          context.l10n.text('ui7f3a3a5bec', {
            'arg0': (session.index + 1),
            'arg1': (session.cards.length),
          }),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: LingoSpace.s8),
        LingoProgress(
          value: session.index / session.cards.length,
          label: context.l10n.text('uiafc2256d66'),
        ),
        const SizedBox(height: LingoSpace.s24),
        FlippableFlashcard(
          key: ValueKey(session.currentCard!.id),
          word: session.currentCard!,
          revealed: session.revealed,
          onFlip: session.saving ? null : controller.flip,
        ),
        const SizedBox(height: LingoSpace.s24),
        if (session.error != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              session.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          const SizedBox(height: LingoSpace.s16),
        ],
        Text(
          session.saving
              ? context.l10n.text('ui1cd1afe475')
              : session.revealed
              ? context.l10n.text('ui9f7659076f')
              : context.l10n.text('ui389a938659'),
        ),
        const SizedBox(height: LingoSpace.s16),
        ReviewRatingButtons(
          enabled: session.revealed && !session.saving,
          onRating: controller.rate,
        ),
      ],
    );
  }
}
