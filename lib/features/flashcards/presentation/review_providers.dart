import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/data/home_providers.dart';
import '../../onboarding/data/course_catalog.dart';
import '../data/review_repository.dart';
import '../domain/review_session.dart';

void retryReviewData(WidgetRef ref, {bool session = false}) {
  ref.invalidate(courseCatalogProvider);
  ref.invalidate(reviewOverviewProvider);
  if (session) ref.invalidate(reviewSessionProvider);
}

final reviewOverviewProvider = StreamProvider.autoDispose<ReviewOverview>((
  ref,
) async* {
  final repository = ref.watch(reviewRepositoryProvider);
  final course = await ref.watch(selectedCourseProvider.future);
  if (!ref.mounted) return;
  // Backfill cards from lessons completed before Phase 5 was installed.
  await repository.enrollCompletedLessons(course);
  if (!ref.mounted) return;
  yield* repository.watchOverview(course);
}, retry: (count, error) => null);

final reviewSessionProvider =
    AsyncNotifierProvider.autoDispose<ReviewSessionController, ReviewSession>(
      ReviewSessionController.new,
      retry: (count, error) => null,
    );

class ReviewSessionController extends AsyncNotifier<ReviewSession> {
  @override
  Future<ReviewSession> build() async {
    final repository = ref.watch(reviewRepositoryProvider);
    final course = await ref.watch(selectedCourseProvider.future);
    await repository.enrollCompletedLessons(course);
    return ReviewSession(cards: await repository.loadDueCards(course));
  }

  void flip() {
    final session = state.asData?.value;
    if (session == null || session.finished || session.saving) return;
    state = AsyncData(
      session.copyWith(revealed: !session.revealed, error: session.error),
    );
  }

  Future<void> rate(ReviewRating rating) async {
    final session = state.asData?.value;
    if (session == null ||
        session.finished ||
        !session.revealed ||
        session.saving) {
      return;
    }
    state = AsyncData(session.copyWith(saving: true));
    try {
      await ref
          .read(reviewRepositoryProvider)
          .rate(session.currentCard!.id, rating.quality);
      if (ref.mounted) {
        state = AsyncData(
          session.copyWith(
            index: session.index + 1,
            revealed: false,
            saving: false,
            ratings: {
              ...session.ratings,
              rating: (session.ratings[rating] ?? 0) + 1,
            },
          ),
        );
      }
    } catch (_) {
      if (ref.mounted) {
        state = AsyncData(
          session.copyWith(
            saving: false,
            error: 'This rating could not be saved. Please try again.',
          ),
        );
      }
    }
  }
}
