# Phase 5 - flashcards and spaced repetition

SM-2 follows the supplied rules, including nearest-integer interval rounding and the ease-factor formula on every rating. Intervals use the incoming ease factor. Dates are UTC instants and a scheduling day is 24 hours. New lesson words become due immediately. Due today includes overdue cards but excludes future due times. A review session snapshots the due cards at Start; Again schedules one day later. Ratings map Again/Hard/Good/Easy to 1/3/4/5.

Lesson completion enrolls missing WordProgress rows atomically with completion and XP. Existing schedules are preserved, and older completed lessons are backfilled when Review opens. Each review rating saves before the session advances; failures can be retried. The due count updates when scheduled times arrive and on app resume. The flip uses AnimatedSwitcher and Transform, respects reduced motion, and adds no dependencies.

Validation: all 94 tests passed, including 10 SM-2 tests, enrollment/backfill, persistence, timing, session state, error recovery, partial reviews, app resume, reduced motion, and 320px/200% text layouts in both themes. Analysis and formatting passed. An Android emulator run was not performed.

## Created files

- [lib/core/utils/clock.dart](lib/core/utils/clock.dart)
- [lib/features/flashcards/domain/sm2.dart](lib/features/flashcards/domain/sm2.dart)
- [lib/features/flashcards/domain/review_session.dart](lib/features/flashcards/domain/review_session.dart)
- [lib/features/flashcards/data/word_enrollment.dart](lib/features/flashcards/data/word_enrollment.dart)
- [lib/features/flashcards/data/review_repository.dart](lib/features/flashcards/data/review_repository.dart)
- [lib/features/flashcards/presentation/review_providers.dart](lib/features/flashcards/presentation/review_providers.dart)
- [lib/features/flashcards/presentation/review_empty_state.dart](lib/features/flashcards/presentation/review_empty_state.dart)
- [lib/features/flashcards/presentation/review_rating_buttons.dart](lib/features/flashcards/presentation/review_rating_buttons.dart)
- [lib/features/flashcards/presentation/review_summary.dart](lib/features/flashcards/presentation/review_summary.dart)
- [lib/features/flashcards/presentation/review_session_screen.dart](lib/features/flashcards/presentation/review_session_screen.dart)
- [lib/shared/widgets/flippable_flashcard.dart](lib/shared/widgets/flippable_flashcard.dart)
- [test/sm2_test.dart](test/sm2_test.dart)
- [test/review_repository_test.dart](test/review_repository_test.dart)
- [test/review_session_controller_test.dart](test/review_session_controller_test.dart)
- [test/review_widget_test.dart](test/review_widget_test.dart)
- [test/support/review_fixtures.dart](test/support/review_fixtures.dart)
- PHASE5_FILES.md (this manifest and source snapshot)

## Edited files

- [lib/core/constants/app_routes.dart](lib/core/constants/app_routes.dart)
- [lib/core/router/app_router.dart](lib/core/router/app_router.dart)
- [lib/features/flashcards/presentation/review_screen.dart](lib/features/flashcards/presentation/review_screen.dart)
- [lib/features/lessons/data/lesson_completion_repository.dart](lib/features/lessons/data/lesson_completion_repository.dart)
- [lib/features/lessons/presentation/lesson_controller.dart](lib/features/lessons/presentation/lesson_controller.dart)
- [test/lesson_controller_test.dart](test/lesson_controller_test.dart)
- [test/lesson_completion_repository_test.dart](test/lesson_completion_repository_test.dart)
- [test/widget_test.dart](test/widget_test.dart)
- [README.md](README.md)

No dependencies or database migrations were needed. Run commands and manual test steps are in the README section below. Full source follows.

## lib/core/utils/clock.dart

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final clockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);
```

## lib/features/flashcards/domain/sm2.dart

```dart
import 'dart:math';

final class Sm2Schedule {
  const Sm2Schedule({
    required this.repetitions,
    required this.easeFactor,
    required this.intervalDays,
    required this.dueDate,
  });

  final int repetitions;
  final double easeFactor;
  final int intervalDays;
  final DateTime dueDate;
}

/// Uses the incoming ease factor for this interval, then updates it for next time.
/// Dates are absolute UTC instants; one scheduling day is 24 hours.
final class Sm2 {
  const Sm2();

  Sm2Schedule schedule({
    required int quality,
    required int repetitions,
    required double easeFactor,
    required int intervalDays,
    required DateTime reviewedAt,
  }) {
    if (quality < 0 || quality > 5) {
      throw RangeError.range(quality, 0, 5, 'quality');
    }
    if (repetitions < 0 ||
        intervalDays < 0 ||
        (repetitions >= 2 && intervalDays == 0)) {
      throw ArgumentError('Invalid repetition or interval state');
    }
    if (!easeFactor.isFinite || easeFactor < 1.3) {
      throw ArgumentError.value(
        easeFactor,
        'easeFactor',
        'Must be finite and at least 1.3',
      );
    }
    final nextInterval = quality < 3
        ? 1
        : switch (repetitions) {
            0 => 1,
            1 => 6,
            _ => (intervalDays * easeFactor).round(),
          };
    final difference = 5 - quality;
    final nextEase = max(
      1.3,
      easeFactor + 0.1 - difference * (0.08 + difference * 0.02),
    );
    return Sm2Schedule(
      repetitions: quality < 3 ? 0 : repetitions + 1,
      easeFactor: nextEase,
      intervalDays: nextInterval,
      dueDate: reviewedAt.toUtc().add(Duration(days: nextInterval)),
    );
  }
}
```

## lib/features/flashcards/domain/review_session.dart

```dart
import 'word.dart';

enum ReviewRating {
  again(1, 'Again'),
  hard(3, 'Hard'),
  good(4, 'Good'),
  easy(5, 'Easy');

  const ReviewRating(this.quality, this.label);
  final int quality;
  final String label;
}

final class ReviewOverview {
  const ReviewOverview({
    required this.dueCount,
    required this.totalCards,
    this.nextDue,
  });
  final int dueCount;
  final int totalCards;
  final DateTime? nextDue;
}

final class ReviewSession {
  ReviewSession({
    required List<Word> cards,
    this.index = 0,
    this.revealed = false,
    this.saving = false,
    this.error,
    Map<ReviewRating, int> ratings = const {},
  }) : cards = List.unmodifiable(cards),
       ratings = Map.unmodifiable(ratings);

  final List<Word> cards;
  final int index;
  final bool revealed;
  final bool saving;
  final String? error;
  final Map<ReviewRating, int> ratings;

  bool get finished => index >= cards.length;
  Word? get currentCard => finished ? null : cards[index];

  ReviewSession copyWith({
    int? index,
    bool? revealed,
    bool? saving,
    String? error,
    Map<ReviewRating, int>? ratings,
  }) => ReviewSession(
    cards: cards,
    index: index ?? this.index,
    revealed: revealed ?? this.revealed,
    saving: saving ?? this.saving,
    error: error,
    ratings: ratings ?? this.ratings,
  );
}
```

## lib/features/flashcards/data/word_enrollment.dart

```dart
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// The caller owns the transaction. Existing schedules are never overwritten.
Future<void> enrollWords(
  AppDatabase database,
  Iterable<String> wordIds,
  DateTime now,
) async {
  final ids = wordIds.toSet();
  if (ids.isEmpty) return;
  await database.batch(
    (batch) => batch.insertAll(database.wordProgress, [
      for (final id in ids)
        WordProgressCompanion.insert(wordId: id, dueDate: now.toUtc()),
    ], mode: InsertMode.insertOrIgnore),
  );
}
```

## lib/features/flashcards/data/review_repository.dart

```dart
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/clock.dart';
import '../../lessons/domain/course.dart';
import '../domain/review_session.dart';
import '../domain/sm2.dart';
import '../domain/word.dart';
import 'word_enrollment.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

class ReviewRepository {
  ReviewRepository(this.database, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase database;
  final DateTime Function() clock;

  Future<void> enrollCompletedLessons(Course course) async {
    await database.transaction(() async {
      final completed = await (database.select(
        database.lessonProgress,
      )..where((row) => row.completed.equals(true))).get();
      final completedIds = completed.map((row) => row.lessonId).toSet();
      final knownWords = course.words.map((word) => word.id).toSet();
      final ids = course.units
          .expand((unit) => unit.lessons)
          .where((lesson) => completedIds.contains(lesson.id))
          .expand((lesson) => lesson.wordIds)
          .where(knownWords.contains);
      await enrollWords(database, ids, clock());
    });
  }

  SimpleSelectStatement<WordProgress, WordProgressRow> _query(Course course) =>
      database.select(database.wordProgress)
        ..where((row) => row.wordId.isIn(course.words.map((word) => word.id)))
        ..orderBy([
          (row) => OrderingTerm.asc(row.dueDate),
          (row) => OrderingTerm.asc(row.wordId),
        ]);

  Future<List<Word>> loadDueCards(Course course) async {
    final rows = await _query(course).get();
    final now = clock().toUtc();
    final words = {for (final word in course.words) word.id: word};
    return rows
        .where((row) => !row.dueDate.toUtc().isAfter(now))
        .map((row) => words[row.wordId]!)
        .toList(growable: false);
  }

  Stream<ReviewOverview> watchOverview(Course course) {
    late StreamController<ReviewOverview> controller;
    StreamSubscription<List<WordProgressRow>>? subscription;
    Timer? timer;
    List<WordProgressRow>? latest;

    void emit() {
      timer?.cancel();
      final rows = latest;
      if (rows == null || controller.isClosed || controller.isPaused) return;
      final now = clock().toUtc();
      final future = rows.where((row) => row.dueDate.toUtc().isAfter(now));
      final nextDue = future.isEmpty ? null : future.first.dueDate.toUtc();
      controller.add(
        ReviewOverview(
          dueCount: rows.length - future.length,
          totalCards: rows.length,
          nextDue: nextDue,
        ),
      );
      if (nextDue != null) timer = Timer(nextDue.difference(now), emit);
    }

    controller = StreamController<ReviewOverview>(
      onListen: () {
        subscription = _query(course).watch().listen(
          (rows) {
            latest = rows;
            emit();
          },
          onError: (Object error, StackTrace stack) {
            timer?.cancel();
            controller.addError(error, stack);
          },
        );
      },
      onPause: () {
        timer?.cancel();
        subscription?.pause();
      },
      onResume: () {
        subscription?.resume();
        emit();
      },
      onCancel: () async {
        timer?.cancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  Future<Sm2Schedule> rate(String wordId, int quality) =>
      database.transaction(() async {
        final row = await (database.select(
          database.wordProgress,
        )..where((row) => row.wordId.equals(wordId))).getSingle();
        final next = const Sm2().schedule(
          quality: quality,
          repetitions: row.repetitions,
          easeFactor: row.easeFactor,
          intervalDays: row.intervalDays,
          reviewedAt: clock(),
        );
        await (database.update(
          database.wordProgress,
        )..where((row) => row.wordId.equals(wordId))).write(
          WordProgressCompanion(
            repetitions: Value(next.repetitions),
            easeFactor: Value(next.easeFactor),
            intervalDays: Value(next.intervalDays),
            dueDate: Value(next.dueDate),
          ),
        );
        return next;
      });
}
```

## lib/features/flashcards/presentation/review_providers.dart

```dart
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
```

## lib/features/flashcards/presentation/review_empty_state.dart

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/review_session.dart';

class ReviewEmptyState extends StatelessWidget {
  const ReviewEmptyState({super.key, required this.overview});
  final ReviewOverview overview;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Icon(
        Icons.task_alt,
        size: 56,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 24),
      Text(
        overview.totalCards == 0
            ? 'Your review deck is ready to grow.'
            : 'All caught up!',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      Text(
        overview.nextDue == null
            ? 'Complete a lesson to add words to your review deck.'
            : 'Next card due ${DateFormat('EEE, MMM d, y • h:mm a').format(overview.nextDue!.toLocal())}.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ],
  );
}
```

## lib/features/flashcards/presentation/review_rating_buttons.dart

```dart
import 'package:flutter/material.dart';

import '../domain/review_session.dart';

class ReviewRatingButtons extends StatelessWidget {
  const ReviewRatingButtons({
    super.key,
    required this.enabled,
    required this.onRating,
  });
  final bool enabled;
  final ValueChanged<ReviewRating> onRating;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final rating in ReviewRating.values)
          SizedBox(
            width: (constraints.maxWidth - 12) / 2,
            child: OutlinedButton(
              key: ValueKey('rate-${rating.name}'),
              onPressed: enabled ? () => onRating(rating) : null,
              child: Text(rating.label, textAlign: TextAlign.center),
            ),
          ),
      ],
    ),
  );
}
```

## lib/features/flashcards/presentation/review_summary.dart

```dart
import 'package:flutter/material.dart';

import '../domain/review_session.dart';

class ReviewSummary extends StatelessWidget {
  const ReviewSummary({
    super.key,
    required this.session,
    required this.onContinue,
  });
  final ReviewSession session;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Icon(
        Icons.auto_awesome,
        size: 56,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 24),
      Text(
        'Review complete!',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      Text(
        'You reviewed ${session.index} ${session.index == 1 ? 'card' : 'cards'}.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 24),
      for (final rating in ReviewRating.values)
        Card.filled(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(rating.label),
                Text('${session.ratings[rating] ?? 0}'),
              ],
            ),
          ),
        ),
      const SizedBox(height: 24),
      FilledButton(onPressed: onContinue, child: const Text('Continue')),
    ],
  );
}
```

## lib/features/flashcards/presentation/review_session_screen.dart

```dart
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
```

## lib/shared/widgets/flippable_flashcard.dart

```dart
import 'dart:math';

import 'package:flutter/material.dart';

import '../../features/flashcards/domain/word.dart';

class FlippableFlashcard extends StatelessWidget {
  const FlippableFlashcard({
    super.key,
    required this.word,
    required this.revealed,
    required this.onFlip,
  });
  final Word word;
  final bool revealed;
  final VoidCallback? onFlip;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: revealed ? 'Show word' : 'Reveal translation',
      child: Material(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('flashcard-flip'),
          onTap: onFlip,
          child: AnimatedSwitcher(
            duration: reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) => AnimatedBuilder(
              animation: animation,
              child: child,
              builder: (context, child) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY((1 - animation.value) * pi / 2),
                child: Opacity(opacity: animation.value, child: child),
              ),
            ),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.center,
              children: [
                for (final child in previous) ExcludeSemantics(child: child),
                ?current,
              ],
            ),
            child: _CardFace(
              key: ValueKey('${word.id}:$revealed'),
              word: word,
              revealed: revealed,
            ),
          ),
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({super.key, required this.word, required this.revealed});
  final Word word;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimaryContainer;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 240),
      padding: const EdgeInsets.all(24),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: color),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              word.text,
              textAlign: TextAlign.center,
              style:
                  (revealed
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.headlineLarge)
                      ?.copyWith(color: color),
            ),
            if (revealed) ...[
              const SizedBox(height: 16),
              Text(
                word.translation,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(color: color),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                word.example,
                style: theme.textTheme.bodyLarge?.copyWith(color: color),
              ),
              const SizedBox(height: 12),
              Text(word.exampleTranslation),
            ],
            const SizedBox(height: 24),
            Text(
              revealed ? 'Tap to see the word again' : 'Tap to reveal',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
```

## test/sm2_test.dart

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/flashcards/domain/sm2.dart';

void main() {
  const sm2 = Sm2();
  final now = DateTime.utc(2026, 11, 8, 12);

  test('first successful repetition schedules one day', () {
    final next = sm2.schedule(
      quality: 4,
      repetitions: 0,
      easeFactor: 2.5,
      intervalDays: 0,
      reviewedAt: now,
    );
    expect(next.repetitions, 1);
    expect(next.intervalDays, 1);
    expect(next.easeFactor, closeTo(2.5, 1e-10));
    expect(next.dueDate, now.add(const Duration(days: 1)));
  });

  test('second successful repetition schedules six days', () {
    final next = sm2.schedule(
      quality: 4,
      repetitions: 1,
      easeFactor: 2.5,
      intervalDays: 1,
      reviewedAt: now,
    );
    expect(next.repetitions, 2);
    expect(next.intervalDays, 6);
    expect(next.dueDate, now.add(const Duration(days: 6)));
  });

  test(
    'later repetition multiplies the incoming interval by incoming ease',
    () {
      final next = sm2.schedule(
        quality: 5,
        repetitions: 2,
        easeFactor: 2.5,
        intervalDays: 6,
        reviewedAt: now,
      );
      expect(next.repetitions, 3);
      expect(next.intervalDays, 15);
      expect(next.easeFactor, closeTo(2.6, 1e-10));
    },
  );

  test('fractional interval uses nearest-integer rounding', () {
    final next = sm2.schedule(
      quality: 4,
      repetitions: 3,
      easeFactor: 2.5,
      intervalDays: 5,
      reviewedAt: now,
    );
    expect(next.intervalDays, 13);
  });

  test('quality below three resets repetitions and interval', () {
    final next = sm2.schedule(
      quality: 1,
      repetitions: 8,
      easeFactor: 2.5,
      intervalDays: 99,
      reviewedAt: now,
    );
    expect(next.repetitions, 0);
    expect(next.intervalDays, 1);
    expect(next.easeFactor, closeTo(1.96, 1e-10));
    expect(next.dueDate, now.add(const Duration(days: 1)));
  });

  test('ease factor never drops below 1.3', () {
    final next = sm2.schedule(
      quality: 0,
      repetitions: 4,
      easeFactor: 1.3,
      intervalDays: 20,
      reviewedAt: now,
    );
    expect(next.easeFactor, 1.3);
    expect(next.repetitions, 0);
    expect(next.intervalDays, 1);
  });

  test('Hard is a successful repetition with reduced ease', () {
    final next = sm2.schedule(
      quality: 3,
      repetitions: 2,
      easeFactor: 2.5,
      intervalDays: 6,
      reviewedAt: now,
    );
    expect(next.repetitions, 3);
    expect(next.intervalDays, 15);
    expect(next.easeFactor, closeTo(2.36, 1e-10));
  });

  test('all six qualities apply the specified ease formula', () {
    final expected = [1.7, 1.96, 2.18, 2.36, 2.5, 2.6];
    for (var q = 0; q <= 5; q++) {
      final next = sm2.schedule(
        quality: q,
        repetitions: 3,
        easeFactor: 2.5,
        intervalDays: 6,
        reviewedAt: now,
      );
      expect(
        next.easeFactor,
        closeTo(expected[q], 1e-10),
        reason: 'quality $q',
      );
      expect(next.repetitions, q < 3 ? 0 : 4);
    }
  });

  test('date calculation uses UTC instants and exact 24-hour days', () {
    final next = sm2.schedule(
      quality: 4,
      repetitions: 0,
      easeFactor: 2.5,
      intervalDays: 0,
      reviewedAt: DateTime.parse('2026-11-08T23:30:00+08:00'),
    );
    expect(next.dueDate.isUtc, isTrue);
    expect(next.dueDate, DateTime.utc(2026, 11, 9, 15, 30));
  });

  test('invalid input is rejected', () {
    for (final q in [-1, 6]) {
      expect(
        () => sm2.schedule(
          quality: q,
          repetitions: 0,
          easeFactor: 2.5,
          intervalDays: 0,
          reviewedAt: now,
        ),
        throwsRangeError,
      );
    }
    for (final ef in [1.2, double.nan, double.infinity]) {
      expect(
        () => sm2.schedule(
          quality: 4,
          repetitions: 0,
          easeFactor: ef,
          intervalDays: 0,
          reviewedAt: now,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => sm2.schedule(
        quality: 4,
        repetitions: -1,
        easeFactor: 2.5,
        intervalDays: 0,
        reviewedAt: now,
      ),
      throwsArgumentError,
    );
    expect(
      () => sm2.schedule(
        quality: 4,
        repetitions: 2,
        easeFactor: 2.5,
        intervalDays: 0,
        reviewedAt: now,
      ),
      throwsArgumentError,
    );
  });
}
```

## test/review_repository_test.dart

```dart
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/features/flashcards/data/review_repository.dart';
import 'package:myapp/features/flashcards/domain/review_session.dart';
import 'package:myapp/features/lessons/data/lesson_completion_repository.dart';
import 'package:myapp/features/lessons/domain/lesson_session.dart';

import 'support/phase3_fixtures.dart';

void main() {
  late AppDatabase database;
  late ReviewRepository repository;
  late DateTime now;
  final course = sampleCourse();
  final lesson = course.units.first.lessons.first;
  setUp(() {
    now = DateTime.utc(2026, 11, 8, 12);
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = ReviewRepository(database, clock: () => now);
  });
  tearDown(() => database.close());

  Future<void> completeLesson() =>
      LessonCompletionRepository(database, clock: () => now).save(
        LessonResult(
          lessonId: lesson.id,
          totalExercises: 6,
          correctCount: 6,
          attempts: 6,
          perfectCount: 6,
          hearts: 3,
        ),
        wordIds: lesson.wordIds,
      );

  test(
    'successful lesson enrolls its ten words as immediately due cards',
    () async {
      await completeLesson();
      final rows = await database.select(database.wordProgress).get();
      expect(rows, hasLength(10));
      expect(rows.map((row) => row.wordId).toSet(), lesson.wordIds.toSet());
      for (final row in rows) {
        expect(row.repetitions, 0);
        expect(row.intervalDays, 0);
        expect(row.easeFactor, 2.5);
        expect(row.dueDate.toUtc(), now);
      }
      expect((await repository.watchOverview(course).first).dueCount, 10);
    },
  );

  test(
    'backfills old completed lessons and preserves scheduled cards on replay',
    () async {
      await database
          .into(database.lessonProgress)
          .insert(
            LessonProgressCompanion.insert(
              lessonId: lesson.id,
              completed: const Value(true),
            ),
          );
      await repository.enrollCompletedLessons(course);
      final scheduled = await repository.rate(lesson.wordIds.first, 5);
      now = now.add(const Duration(days: 2));
      await repository.enrollCompletedLessons(course);
      await completeLesson();
      final rows = await database.select(database.wordProgress).get();
      expect(rows, hasLength(10));
      final row = rows.singleWhere((row) => row.wordId == lesson.wordIds.first);
      expect(row.repetitions, 1);
      expect(row.easeFactor, closeTo(2.6, 1e-10));
      expect(row.dueDate.toUtc(), scheduled.dueDate);
    },
  );

  test('only due cards from this course are loaded, oldest first', () async {
    await database
        .into(database.wordProgress)
        .insert(
          WordProgressCompanion.insert(
            wordId: course.words[0].id,
            dueDate: now,
          ),
        );
    await database
        .into(database.wordProgress)
        .insert(
          WordProgressCompanion.insert(
            wordId: course.words[1].id,
            dueDate: now.subtract(const Duration(days: 2)),
          ),
        );
    await database
        .into(database.wordProgress)
        .insert(
          WordProgressCompanion.insert(
            wordId: course.words[2].id,
            dueDate: now.add(const Duration(days: 1)),
          ),
        );
    await database
        .into(database.wordProgress)
        .insert(
          WordProgressCompanion.insert(
            wordId: 'other-course-word',
            dueDate: now,
          ),
        );
    expect((await repository.loadDueCards(course)).map((word) => word.id), [
      course.words[1].id,
      course.words[0].id,
    ]);
    final overview = await repository.watchOverview(course).first;
    expect(overview.totalCards, 3);
    expect(overview.dueCount, 2);
    expect(overview.nextDue, now.add(const Duration(days: 1)));
  });

  for (final rating in ReviewRating.values) {
    test('${rating.label} persists the SM-2 result', () async {
      final wordId = course.words.first.id;
      await database
          .into(database.wordProgress)
          .insert(WordProgressCompanion.insert(wordId: wordId, dueDate: now));
      final result = await repository.rate(wordId, rating.quality);
      final row = await database.select(database.wordProgress).getSingle();
      expect(row.repetitions, result.repetitions);
      expect(row.easeFactor, result.easeFactor);
      expect(row.intervalDays, result.intervalDays);
      expect(row.dueDate.toUtc(), now.add(const Duration(days: 1)));
      expect((await repository.watchOverview(course).first).dueCount, 0);
    });
  }

  test('invalid rating leaves the persisted schedule unchanged', () async {
    await database
        .into(database.wordProgress)
        .insert(
          WordProgressCompanion.insert(
            wordId: course.words.first.id,
            dueDate: now,
          ),
        );
    await expectLater(
      repository.rate(course.words.first.id, 6),
      throwsRangeError,
    );
    final row = await database.select(database.wordProgress).getSingle();
    expect(row.repetitions, 0);
    expect(row.easeFactor, 2.5);
    expect(row.dueDate.toUtc(), now);
  });

  test(
    'due count updates when the next scheduled time arrives without a DB write',
    () async {
      final due = now.add(const Duration(seconds: 1));
      await database
          .into(database.wordProgress)
          .insert(
            WordProgressCompanion.insert(
              wordId: course.words.first.id,
              dueDate: due,
            ),
          );
      final initial = Completer<void>();
      final becameDue = Completer<void>();
      final subscription = repository.watchOverview(course).listen((value) {
        if (value.dueCount == 0 && !initial.isCompleted) initial.complete();
        if (value.dueCount == 1 && !becameDue.isCompleted) becameDue.complete();
      });
      addTearDown(subscription.cancel);
      await initial.future.timeout(const Duration(seconds: 3));
      now = due;
      await becameDue.future.timeout(const Duration(seconds: 3));
    },
  );
}
```

## test/review_session_controller_test.dart

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/flashcards/data/review_repository.dart';
import 'package:myapp/features/flashcards/domain/review_session.dart';
import 'package:myapp/features/flashcards/presentation/review_providers.dart';
import 'package:myapp/features/home/data/home_providers.dart';

import 'support/phase3_fixtures.dart';
import 'support/review_fixtures.dart';

void main() {
  late ProviderContainer container;
  late MemoryReviewRepository repository;
  final course = sampleCourse();
  setUp(() {
    repository = MemoryReviewRepository(course.words.take(2).toList());
    container = ProviderContainer(
      overrides: [
        selectedCourseProvider.overrideWith((ref) async => course),
        reviewRepositoryProvider.overrideWithValue(repository),
      ],
    );
    final subscription = container.listen(reviewSessionProvider, (_, next) {});
    addTearDown(subscription.close);
  });
  tearDown(() => container.dispose());

  test(
    'session snapshots the due cards and requires reveal before rating',
    () async {
      await container.read(reviewSessionProvider.future);
      final controller = container.read(reviewSessionProvider.notifier);
      repository.cards.add(course.words[2]);
      expect(
        container.read(reviewSessionProvider).requireValue.cards,
        hasLength(2),
      );
      await controller.rate(ReviewRating.good);
      expect(repository.calls, 0);
      controller.flip();
      expect(
        container.read(reviewSessionProvider).requireValue.revealed,
        isTrue,
      );
      controller.flip();
      expect(
        container.read(reviewSessionProvider).requireValue.revealed,
        isFalse,
      );
    },
  );

  test(
    'rating is saved before advancing; duplicate submissions are ignored',
    () async {
      await container.read(reviewSessionProvider.future);
      final controller = container.read(reviewSessionProvider.notifier);
      repository.saveGate = Completer<void>();
      controller.flip();
      final save = controller.rate(ReviewRating.good);
      expect(container.read(reviewSessionProvider).requireValue.saving, isTrue);
      expect(container.read(reviewSessionProvider).requireValue.index, 0);
      await controller.rate(ReviewRating.easy);
      expect(repository.calls, 1);
      repository.saveGate!.complete();
      await save;
      final session = container.read(reviewSessionProvider).requireValue;
      expect(session.index, 1);
      expect(session.revealed, isFalse);
      expect(session.ratings, {ReviewRating.good: 1});
      expect(repository.qualities, [4]);
    },
  );

  test('failed save preserves the revealed card and can be retried', () async {
    await container.read(reviewSessionProvider.future);
    final controller = container.read(reviewSessionProvider.notifier);
    repository.failSave = true;
    controller.flip();
    await controller.rate(ReviewRating.hard);
    var session = container.read(reviewSessionProvider).requireValue;
    expect(session.index, 0);
    expect(session.revealed, isTrue);
    expect(session.error, isNotNull);
    expect(session.ratings, isEmpty);
    repository.failSave = false;
    await controller.rate(ReviewRating.hard);
    session = container.read(reviewSessionProvider).requireValue;
    expect(session.index, 1);
    expect(session.error, isNull);
    expect(repository.qualities, [3]);
  });

  test(
    'finishing records each quality and ignores additional ratings',
    () async {
      await container.read(reviewSessionProvider.future);
      final controller = container.read(reviewSessionProvider.notifier);
      controller.flip();
      await controller.rate(ReviewRating.again);
      controller.flip();
      await controller.rate(ReviewRating.easy);
      final session = container.read(reviewSessionProvider).requireValue;
      expect(session.finished, isTrue);
      expect(session.index, 2);
      expect(session.ratings, {ReviewRating.again: 1, ReviewRating.easy: 1});
      expect(repository.qualities, [1, 5]);
      await controller.rate(ReviewRating.good);
      expect(repository.calls, 2);
    },
  );

  test('load failures are exposed and can be retried', () async {
    repository.failLoad = true;
    await expectLater(
      container.read(reviewSessionProvider.future),
      throwsA(anything),
    );
    repository.failLoad = false;
    container.invalidate(reviewSessionProvider);
    expect(
      (await container.read(reviewSessionProvider.future)).cards,
      hasLength(2),
    );
  });
}
```

## test/review_widget_test.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/core/router/app_router.dart';
import 'package:myapp/features/flashcards/presentation/review_providers.dart';
import 'package:myapp/shared/widgets/flippable_flashcard.dart';

import 'support/phase3_fixtures.dart';
import 'support/review_fixtures.dart';
import 'widget_test.dart' show AppHarness, mount, tapText;

void main() {
  final fixedNow = DateTime.utc(2026, 11, 8, 12);

  Future<void> seed(
    WidgetTester tester,
    AppHarness harness, {
    int count = 2,
    DateTime? due,
  }) async {
    await tester.runAsync(() async {
      for (final word in harness.course.words.take(count)) {
        await harness.database
            .into(harness.database.wordProgress)
            .insert(
              WordProgressCompanion.insert(
                wordId: word.id,
                dueDate: due ?? fixedNow,
              ),
            );
      }
    });
  }

  Future<void> openReview(WidgetTester tester, AppHarness harness) async {
    harness.container.read(appRouterProvider).go('/review');
    await tester.pumpAndSettle();
  }

  testWidgets(
    'due count, flip, ratings, persisted schedules and summary work together',
    (tester) async {
      final harness = AppHarness(
        settings: completedSettings(),
        clock: () => fixedNow,
      );
      await mount(tester, harness);
      await seed(tester, harness);
      await openReview(tester, harness);
      expect(find.text('2 cards due today'), findsOneWidget);
      await tapText(tester, 'Start');
      var session = harness.container.read(reviewSessionProvider).requireValue;
      final first = session.currentCard!;
      expect(find.text(first.translation), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('rate-good')))
            .onPressed,
        isNull,
      );
      await tapText(tester, 'Tap to reveal');
      expect(find.text(first.translation), findsOneWidget);
      expect(find.text(first.example), findsOneWidget);
      expect(find.text(first.exampleTranslation), findsOneWidget);
      await tapText(tester, 'Good');
      session = harness.container.read(reviewSessionProvider).requireValue;
      expect(session.index, 1);
      expect(session.revealed, isFalse);
      final row =
          (await harness.database.select(harness.database.wordProgress).get())
              .singleWhere((row) => row.wordId == first.id);
      expect(row.repetitions, 1);
      expect(row.intervalDays, 1);
      expect(row.dueDate.toUtc(), fixedNow.add(const Duration(days: 1)));
      await tapText(tester, 'Tap to reveal');
      await tapText(tester, 'Easy');
      expect(find.text('Review complete!'), findsOneWidget);
      expect(find.text('You reviewed 2 cards.'), findsOneWidget);
      await tapText(tester, 'Continue');
      expect(find.text('0 cards due today'), findsOneWidget);
      expect(find.text('All caught up!'), findsOneWidget);
      expect(find.textContaining('Next card due'), findsOneWidget);
    },
  );

  testWidgets('new and future-only decks show an empty state without Start', (
    tester,
  ) async {
    final harness = AppHarness(
      settings: completedSettings(),
      clock: () => fixedNow,
    );
    await mount(tester, harness);
    await openReview(tester, harness);
    expect(find.text('Your review deck is ready to grow.'), findsOneWidget);
    expect(find.text('Start'), findsNothing);
    await seed(
      tester,
      harness,
      count: 1,
      due: fixedNow.add(const Duration(days: 2)),
    );
    await tester.pumpAndSettle();
    expect(find.text('All caught up!'), findsOneWidget);
    expect(find.textContaining('Next card due'), findsOneWidget);
    harness.container.read(appRouterProvider).go('/review/session');
    await tester.pumpAndSettle();
    expect(find.text('All caught up!'), findsOneWidget);
    expect(find.text('Back to Review'), findsOneWidget);
  });

  testWidgets('resuming the app refreshes cards that became due while away', (
    tester,
  ) async {
    var now = fixedNow;
    final harness = AppHarness(settings: completedSettings(), clock: () => now);
    await mount(tester, harness);
    await seed(
      tester,
      harness,
      count: 1,
      due: now.add(const Duration(days: 1)),
    );
    await openReview(tester, harness);
    expect(find.text('0 cards due today'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(days: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('1 card due today'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('load and rating errors can be retried without skipping cards', (
    tester,
  ) async {
    final repository = MemoryReviewRepository(
      sampleCourse().words.take(1).toList(),
    )..failLoad = true;
    final harness = AppHarness(
      settings: completedSettings(),
      reviewRepository: repository,
    );
    await mount(tester, harness);
    harness.container.read(appRouterProvider).go('/review/session');
    await tester.pumpAndSettle();
    expect(find.text('Your flashcards could not be loaded.'), findsOneWidget);
    repository.failLoad = false;
    await tapText(tester, 'Try again');
    await tapText(tester, 'Tap to reveal');
    repository.failSave = true;
    await tapText(tester, 'Hard');
    expect(
      find.text('This rating could not be saved. Please try again.'),
      findsOneWidget,
    );
    expect(harness.container.read(reviewSessionProvider).requireValue.index, 0);
    repository.failSave = false;
    await tapText(tester, 'Hard');
    expect(find.text('Review complete!'), findsOneWidget);
    expect(repository.qualities, [3]);
  });

  testWidgets('catalog error on Review can be retried', (tester) async {
    final harness = AppHarness(settings: completedSettings())
      ..catalogFails = true;
    await mount(tester, harness);
    await openReview(tester, harness);
    expect(find.text('Your review deck could not be loaded.'), findsOneWidget);
    harness.catalogFails = false;
    await tapText(tester, 'Try again');
    expect(find.text('0 cards due today'), findsOneWidget);
  });

  testWidgets(
    'closing part-way keeps saved ratings and the remaining card due',
    (tester) async {
      final harness = AppHarness(
        settings: completedSettings(),
        clock: () => fixedNow,
      );
      await mount(tester, harness);
      await seed(tester, harness);
      await openReview(tester, harness);
      await tapText(tester, 'Start');
      await tapText(tester, 'Tap to reveal');
      await tapText(tester, 'Again');
      await tester.tap(find.byTooltip('Close review'));
      await tester.pumpAndSettle();
      expect(find.text('1 card due today'), findsOneWidget);
      final rows = await harness.database
          .select(harness.database.wordProgress)
          .get();
      expect(rows.where((row) => row.intervalDays == 1), hasLength(1));
      expect(rows.singleWhere((row) => row.intervalDays == 1).repetitions, 0);
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'flashcard, flip and summary fit 320px at 200% in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final harness = AppHarness(
          settings: completedSettings(),
          clock: () => fixedNow,
        );
        await mount(tester, harness);
        await seed(tester, harness, count: 1);
        await openReview(tester, harness);
        await tapText(tester, 'Start');
        expect(find.byType(FlippableFlashcard), findsOneWidget);
        await tapText(tester, 'Tap to reveal');
        await tapText(tester, 'Good');
        expect(find.text('Review complete!'), findsOneWidget);
        await tapText(tester, 'Continue');
        expect(find.text('All caught up!'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('flip respects the reduced-motion preference', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final harness = AppHarness(
      settings: completedSettings(),
      clock: () => fixedNow,
    );
    await mount(tester, harness);
    await seed(tester, harness, count: 1);
    await openReview(tester, harness);
    await tapText(tester, 'Start');
    final switcher = find.descendant(
      of: find.byType(FlippableFlashcard),
      matching: find.byType(AnimatedSwitcher),
    );
    expect(tester.widget<AnimatedSwitcher>(switcher).duration, Duration.zero);
    await tapText(tester, 'Tap to reveal');
    expect(
      harness.container.read(reviewSessionProvider).requireValue.revealed,
      isTrue,
    );
  });
}
```

## test/support/review_fixtures.dart

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/flashcards/data/review_repository.dart';
import 'package:myapp/features/flashcards/domain/review_session.dart';
import 'package:myapp/features/flashcards/domain/sm2.dart';
import 'package:myapp/features/flashcards/domain/word.dart';
import 'package:myapp/features/lessons/domain/course.dart';

class MemoryReviewRepository extends Fake implements ReviewRepository {
  MemoryReviewRepository(List<Word> words) : cards = words.toList();
  final List<Word> cards;
  final qualities = <int>[];
  bool failLoad = false;
  bool failSave = false;
  int calls = 0;
  Completer<void>? saveGate;

  @override
  Future<void> enrollCompletedLessons(Course course) async {}

  @override
  Future<List<Word>> loadDueCards(Course course) async {
    if (failLoad) throw StateError('Load failure');
    return cards;
  }

  @override
  Stream<ReviewOverview> watchOverview(Course course) => Stream.value(
    ReviewOverview(dueCount: cards.length, totalCards: cards.length),
  );

  @override
  Future<Sm2Schedule> rate(String wordId, int quality) async {
    calls++;
    await saveGate?.future;
    if (failSave) throw StateError('Save failure');
    qualities.add(quality);
    return const Sm2().schedule(
      quality: quality,
      repetitions: 0,
      easeFactor: 2.5,
      intervalDays: 0,
      reviewedAt: DateTime.utc(2026, 11, 8),
    );
  }
}
```

## lib/core/constants/app_routes.dart

```dart
abstract final class AppRoutes {
  static const welcome = '/welcome';
  static const startup = '/startup';
  static const languages = '/languages';
  static const dailyGoal = '/daily-goal';
  static const home = '/home';
  static const lesson = '/lesson/:id';
  static const review = '/review';
  static const reviewSession = '/review/session';
  static const profile = '/profile';

  static String lessonLocation(String id) =>
      '/lesson/${Uri.encodeComponent(id)}';
}
```

## lib/core/router/app_router.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/flashcards/presentation/review_screen.dart';
import '../../features/flashcards/presentation/review_session_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/learn_screen.dart';
import '../../features/lessons/presentation/lesson_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/onboarding/presentation/daily_goal_screen.dart';
import '../../features/onboarding/presentation/language_screen.dart';
import '../../features/onboarding/presentation/onboarding_controller.dart';
import '../../features/onboarding/presentation/startup_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../shared/widgets/placeholder_page.dart';
import '../constants/app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Refresh redirects when preferences change without rebuilding the router.
  final refresh = ValueNotifier(0);
  ref.listen(onboardingProvider, (previous, next) => refresh.value++);
  ref.listen(
    onboardingFlowProvider.select((draft) => draft.courseId),
    (previous, next) => refresh.value++,
  );
  final router = GoRouter(
    initialLocation: AppRoutes.welcome,
    refreshListenable: refresh,
    redirect: (context, state) {
      final settings = ref.read(onboardingProvider);
      final path = state.uri.path;
      const onboardingPaths = {
        AppRoutes.welcome,
        AppRoutes.languages,
        AppRoutes.dailyGoal,
      };
      if (settings.isLoading || settings.hasError) {
        return path == AppRoutes.startup ? null : AppRoutes.startup;
      }
      if (settings.requireValue == null) {
        if (!onboardingPaths.contains(path)) return AppRoutes.welcome;
        if (path == AppRoutes.dailyGoal &&
            ref.read(onboardingFlowProvider).courseId == null) {
          return AppRoutes.languages;
        }
        return null;
      }
      return onboardingPaths.contains(path) ||
              path == '/' ||
              path == AppRoutes.startup
          ? AppRoutes.home
          : null;
    },
    routes: [
      GoRoute(path: '/', redirect: (context, state) => AppRoutes.welcome),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.startup,
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(
        path: AppRoutes.languages,
        builder: (context, state) => const LanguageScreen(),
      ),
      GoRoute(
        path: AppRoutes.dailyGoal,
        builder: (context, state) => const DailyGoalScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeScreen(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const LearnScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.review,
                builder: (context, state) => const ReviewScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.lesson,
        builder: (context, state) =>
            LessonScreen(lessonId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.reviewSession,
        builder: (context, state) => const ReviewSessionScreen(),
      ),
    ],
    errorBuilder: (context, state) => PlaceholderPage(
      title: 'Page not found',
      message: 'This page is unavailable.',
      action: FilledButton(
        onPressed: () => context.go(AppRoutes.home),
        child: const Text('Go to Learn'),
      ),
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
```

## lib/features/flashcards/presentation/review_screen.dart

```dart
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
```

## lib/features/lessons/data/lesson_completion_repository.dart

```dart
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/clock.dart';
import '../../flashcards/data/word_enrollment.dart';
import '../domain/lesson_session.dart';

final lessonCompletionRepositoryProvider = Provider<LessonCompletionRepository>(
  (ref) => LessonCompletionRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

class LessonCompletionRepository {
  LessonCompletionRepository(this.database, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase database;
  final DateTime Function() clock;

  Future<void> save(
    LessonResult result, {
    required List<String> wordIds,
  }) async {
    if (!result.success) return;
    await database.transaction(() async {
      final previous =
          await (database.select(database.lessonProgress)
                ..where((table) => table.lessonId.equals(result.lessonId)))
              .getSingleOrNull();
      await database
          .into(database.lessonProgress)
          .insertOnConflictUpdate(
            LessonProgressCompanion.insert(
              lessonId: result.lessonId,
              completed: const Value(true),
              bestScore: Value(max(previous?.bestScore ?? 0, result.score)),
              completedAt: Value(previous?.completedAt ?? clock().toUtc()),
            ),
          );
      final changed =
          await (database.update(
            database.userStats,
          )..where((table) => table.id.equals(1))).write(
            UserStatsCompanion.custom(
              xp: database.userStats.xp + Constant(result.xp),
            ),
          );
      if (changed != 1) throw StateError('User stats row is missing');
      await enrollWords(database, wordIds, clock());
    });
  }
}
```

## lib/features/lessons/presentation/lesson_controller.dart

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../exercises/domain/exercise.dart';
import '../../exercises/domain/exercise_grader.dart';
import '../data/lesson_completion_repository.dart';
import '../domain/lesson.dart';
import '../domain/lesson_session.dart';

final lessonControllerProvider = NotifierProvider.autoDispose
    .family<LessonController, LessonSession, Lesson>(LessonController.new);

class LessonController extends Notifier<LessonSession> {
  LessonController(this.lesson);
  final Lesson lesson;

  @override
  LessonSession build() {
    if (lesson.exercises.isEmpty ||
        lesson.exercises.map((exercise) => exercise.id).toSet().length !=
            lesson.exercises.length) {
      throw ArgumentError('A lesson needs exercises with unique IDs');
    }
    return LessonSession(
      exercises: lesson.exercises,
      originalCount: lesson.exercises.length,
      rightOrder: _rightOrder(lesson.exercises.first),
    );
  }

  List<int> _rightOrder(Exercise exercise) => exercise is MatchPairs
      ? (List.generate(exercise.pairs.length, (index) => index)..shuffle())
      : [];

  void selectChoice(int index) {
    if (state.phase != LessonPhase.answering) return;
    final exercise = state.currentExercise!;
    final count = switch (exercise) {
      MultipleChoice() => exercise.options.length,
      FillInBlank() => exercise.choices.length,
      _ => 0,
    };
    if (index >= 0 && index < count) {
      state = state.copyWith(answer: ChoiceAnswer(index));
    }
  }

  void typeAnswer(String text) {
    if (state.phase == LessonPhase.answering &&
        state.currentExercise is TypeTranslation) {
      state = state.copyWith(answer: TranslationAnswer(text));
    }
  }

  void selectPair({required bool left, required int index}) {
    final exercise = state.currentExercise;
    if (state.phase != LessonPhase.answering ||
        exercise is! MatchPairs ||
        index < 0 ||
        index >= exercise.pairs.length) {
      return;
    }
    final matches = {
      ...?(state.answer is PairsAnswer
          ? (state.answer as PairsAnswer).matches
          : null),
    };
    if (left) {
      if (matches.containsKey(index)) {
        matches.remove(index);
        state = state.copyWith(
          answer: PairsAnswer(matches),
          clearSelection: true,
        );
      } else if (state.selectedRight != null) {
        matches[index] = state.selectedRight!;
        state = state.copyWith(
          answer: PairsAnswer(matches),
          clearSelection: true,
        );
      } else {
        state = state.copyWith(selectedLeft: index);
      }
    } else {
      if (matches.containsValue(index)) {
        matches.removeWhere((key, value) => value == index);
        state = state.copyWith(
          answer: PairsAnswer(matches),
          clearSelection: true,
        );
      } else if (state.selectedLeft != null) {
        matches[state.selectedLeft!] = index;
        state = state.copyWith(
          answer: PairsAnswer(matches),
          clearSelection: true,
        );
      } else {
        state = state.copyWith(selectedRight: index);
      }
    }
  }

  void check() {
    if (!state.canCheck) return;
    final exercise = state.currentExercise!;
    final feedback = gradeExercise(exercise, state.answer);
    state = state.copyWith(
      phase: LessonPhase.feedback,
      feedback: feedback,
      attempts: state.attempts + 1,
      hearts: state.hearts - (feedback.correct ? 0 : 1),
      correctCount: state.correctCount + (feedback.correct ? 1 : 0),
      perfectCount:
          state.perfectCount +
          (feedback.correct && !state.mistakenIds.contains(exercise.id)
              ? 1
              : 0),
      mistakenIds: feedback.correct
          ? state.mistakenIds
          : {...state.mistakenIds, exercise.id},
      exercises: feedback.correct
          ? state.exercises
          : [...state.exercises, exercise],
    );
  }

  void continueLesson() {
    if (state.phase != LessonPhase.feedback) return;
    final nextIndex = state.currentIndex + 1;
    if (state.hearts == 0 || nextIndex >= state.exercises.length) {
      final result = LessonResult(
        lessonId: lesson.id,
        totalExercises: state.originalCount,
        correctCount: state.correctCount,
        attempts: state.attempts,
        perfectCount: state.perfectCount,
        hearts: state.hearts,
      );
      state = state.copyWith(
        phase: LessonPhase.finished,
        result: result,
        clearDraft: true,
      );
      unawaited(saveResult());
    } else {
      state = state.copyWith(
        currentIndex: nextIndex,
        phase: LessonPhase.answering,
        clearDraft: true,
        rightOrder: _rightOrder(state.exercises[nextIndex]),
      );
    }
  }

  Future<void> saveResult() async {
    final result = state.result;
    if (state.phase != LessonPhase.finished ||
        result == null ||
        !result.success ||
        state.saving ||
        state.saved) {
      return;
    }
    state = state.copyWith(saving: true);
    try {
      await ref
          .read(lessonCompletionRepositoryProvider)
          .save(result, wordIds: lesson.wordIds);
      if (ref.mounted) state = state.copyWith(saving: false, saved: true);
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          saving: false,
          saveError: 'Progress could not be saved. Please try again.',
        );
      }
    }
  }
}
```

## test/lesson_controller_test.dart

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/exercises/domain/exercise_grader.dart';
import 'package:myapp/features/lessons/data/lesson_completion_repository.dart';
import 'package:myapp/features/lessons/domain/lesson.dart';
import 'package:myapp/features/lessons/domain/lesson_session.dart';
import 'package:myapp/features/lessons/presentation/lesson_controller.dart';

import 'support/exercise_fixtures.dart';

class MemoryCompletionRepository extends Fake
    implements LessonCompletionRepository {
  final saved = <LessonResult>[];
  bool fail = false;
  int calls = 0;
  Completer<void>? gate;

  @override
  Future<void> save(
    LessonResult result, {
    required List<String> wordIds,
  }) async {
    calls++;
    await gate?.future;
    if (fail) throw StateError('Save failed');
    saved.add(result);
  }
}

void main() {
  late ProviderContainer container;
  late MemoryCompletionRepository repository;
  setUp(() {
    repository = MemoryCompletionRepository();
    container = ProviderContainer(
      overrides: [
        lessonCompletionRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });
  tearDown(() => container.dispose());

  LessonController start(Lesson lesson) {
    final subscription = container.listen(
      lessonControllerProvider(lesson),
      (_, next) {},
    );
    addTearDown(subscription.close);
    return container.read(lessonControllerProvider(lesson).notifier);
  }

  test('starts with 3 hearts, first exercise and disabled empty check', () {
    final lesson = engineLesson();
    final controller = start(lesson);
    final initial = container.read(lessonControllerProvider(lesson));
    expect(initial.hearts, 3);
    expect(initial.currentIndex, 0);
    expect(initial.correctCount, 0);
    expect(initial.phase, LessonPhase.answering);
    controller.check();
    controller.continueLesson();
    expect(container.read(lessonControllerProvider(lesson)).attempts, 0);
  });

  test('correct check enters feedback once and Continue clears the draft', () {
    final lesson = engineLesson();
    final controller = start(lesson);
    controller.selectChoice(0);
    controller.check();
    controller.check();
    controller.selectChoice(1);
    final checked = container.read(lessonControllerProvider(lesson));
    expect(checked.feedback!.correct, isTrue);
    expect(checked.hearts, 3);
    expect(checked.correctCount, 1);
    expect(checked.attempts, 1);
    controller.continueLesson();
    final next = container.read(lessonControllerProvider(lesson));
    expect(next.currentIndex, 1);
    expect(next.phase, LessonPhase.answering);
    expect(next.answer, isNull);
    expect(next.feedback, isNull);
  });

  test(
    'wrong answer loses one heart, queues at the end and reduces first-try XP',
    () async {
      final lesson = engineLesson([choiceExercise('a'), choiceExercise('b')]);
      final controller = start(lesson);
      controller.selectChoice(1);
      controller.check();
      var state = container.read(lessonControllerProvider(lesson));
      expect(state.hearts, 2);
      expect(state.exercises.map((exercise) => exercise.id), ['a', 'b', 'a']);
      expect(state.progress, 0);
      controller.continueLesson();
      controller.selectChoice(0);
      controller.check();
      controller.continueLesson();
      expect(
        container.read(lessonControllerProvider(lesson)).currentExercise!.id,
        'a',
      );
      controller.selectChoice(0);
      controller.check();
      controller.continueLesson();
      await Future<void>.delayed(Duration.zero);
      state = container.read(lessonControllerProvider(lesson));
      expect(state.phase, LessonPhase.finished);
      expect(state.result!.success, isTrue);
      expect(state.result!.score, 67);
      expect(state.result!.perfectCount, 1);
      expect(state.result!.xp, 15);
      expect(state.saved, isTrue);
    },
  );

  test(
    'three wrong attempts exhaust hearts and finish without XP or writes',
    () {
      final lesson = engineLesson([choiceExercise()]);
      final controller = start(lesson);
      for (var i = 0; i < 3; i++) {
        controller.selectChoice(1);
        controller.check();
        expect(container.read(lessonControllerProvider(lesson)).hearts, 2 - i);
        controller.continueLesson();
      }
      final state = container.read(lessonControllerProvider(lesson));
      expect(state.phase, LessonPhase.finished);
      expect(state.result!.success, isFalse);
      expect(state.result!.xp, 0);
      controller.check();
      controller.continueLesson();
      expect(repository.calls, 0);
    },
  );

  test('pairing works in either direction and tapping a pair unpairs it', () {
    final lesson = engineLesson([pairsExercise()]);
    final controller = start(lesson);
    controller.selectPair(left: false, index: 1);
    controller.selectPair(left: true, index: 1);
    controller.selectPair(left: true, index: 0);
    controller.selectPair(left: false, index: 0);
    expect(container.read(lessonControllerProvider(lesson)).canCheck, isTrue);
    controller.selectPair(left: false, index: 0);
    expect(container.read(lessonControllerProvider(lesson)).canCheck, isFalse);
    controller.selectPair(left: true, index: 0);
    controller.selectPair(left: false, index: 0);
    expect(
      (container.read(lessonControllerProvider(lesson)).answer as PairsAnswer)
          .matches,
      {0: 0, 1: 1},
    );
    controller.check();
    expect(
      container.read(lessonControllerProvider(lesson)).feedback!.correct,
      isTrue,
    );
  });

  test(
    'successful perfect run earns 10 plus 5 per exercise and saves once',
    () async {
      final lesson = engineLesson([choiceExercise()]);
      final controller = start(lesson);
      repository.gate = Completer<void>();
      controller.selectChoice(0);
      controller.check();
      controller.continueLesson();
      expect(container.read(lessonControllerProvider(lesson)).saving, isTrue);
      await controller.saveResult();
      controller.continueLesson();
      expect(repository.calls, 1);
      repository.gate!.complete();
      await Future<void>.delayed(Duration.zero);
      final state = container.read(lessonControllerProvider(lesson));
      expect(state.result!.score, 100);
      expect(state.result!.xp, 15);
      expect(state.saved, isTrue);
      await controller.saveResult();
      expect(repository.calls, 1);
    },
  );

  test('failed save can be retried without losing the result', () async {
    final lesson = engineLesson([choiceExercise()]);
    final controller = start(lesson);
    repository.fail = true;
    controller.selectChoice(0);
    controller.check();
    controller.continueLesson();
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(lessonControllerProvider(lesson)).saveError,
      isNotNull,
    );
    repository.fail = false;
    await controller.saveResult();
    expect(container.read(lessonControllerProvider(lesson)).saveError, isNull);
    expect(container.read(lessonControllerProvider(lesson)).saved, isTrue);
    expect(repository.saved, hasLength(1));
  });

  test('empty and duplicate-ID exercise lists are rejected', () {
    for (final lesson in [
      engineLesson([]),
      engineLesson([choiceExercise(), choiceExercise()]),
    ]) {
      expect(
        () => container.read(lessonControllerProvider(lesson)),
        throwsA(anything),
      );
    }
  });
}
```

## test/lesson_completion_repository_test.dart

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/features/lessons/data/lesson_completion_repository.dart';
import 'package:myapp/features/lessons/domain/lesson_session.dart';

void main() {
  late AppDatabase database;
  late LessonCompletionRepository repository;
  final now = DateTime.utc(2026, 11, 8);
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LessonCompletionRepository(database, clock: () => now);
  });
  tearDown(() => database.close());

  LessonResult result({int attempts = 2, int hearts = 3}) => LessonResult(
    lessonId: 'ja_greetings',
    totalExercises: 2,
    correctCount: hearts == 0 ? 0 : 2,
    attempts: attempts,
    perfectCount: attempts == 2 ? 2 : 1,
    hearts: hearts,
  );

  test('success writes completed progress and adds XP while preserving other stats', () async {
    await database.select(database.userStats).getSingle();
    await database
        .update(database.userStats)
        .write(const UserStatsCompanion(xp: Value(50), streak: Value(4)));
    await repository.save(result(), wordIds: ['ja_hello', 'ja_goodbye']);
    final progress = await database.select(database.lessonProgress).getSingle();
    final stats = await database.select(database.userStats).getSingle();
    expect(progress.completed, isTrue);
    expect(progress.bestScore, 100);
    expect(progress.completedAt!.toUtc(), now);
    expect(stats.xp, 70);
    expect(stats.streak, 4);
  });

  test('a replay preserves the best score and first completion date', () async {
    await repository.save(result(), wordIds: ['ja_hello']);
    await repository.save(result(attempts: 3), wordIds: ['ja_hello']);
    final progress = await database.select(database.lessonProgress).getSingle();
    expect(progress.bestScore, 100);
    expect(progress.completedAt!.toUtc(), now);
    expect((await database.select(database.userStats).getSingle()).xp, 35);
  });

  test('failed lessons do not save completion or XP', () async {
    await repository.save(
      result(attempts: 3, hearts: 0),
      wordIds: ['ja_hello'],
    );
    expect(await database.select(database.lessonProgress).get(), isEmpty);
    expect((await database.select(database.userStats).getSingle()).xp, 0);
    expect(await database.select(database.wordProgress).get(), isEmpty);
  });

  test(
    'transaction rolls back completion if XP update cannot be saved',
    () async {
      await database.select(database.userStats).getSingle();
      await database.delete(database.userStats).go();
      await expectLater(
        repository.save(result(), wordIds: ['ja_hello']),
        throwsStateError,
      );
      expect(await database.select(database.lessonProgress).get(), isEmpty);
      expect(await database.select(database.wordProgress).get(), isEmpty);
    },
  );
}
```

## test/widget_test.dart

```dart
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app/app.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/core/utils/clock.dart';
import 'package:myapp/features/flashcards/data/review_repository.dart';
import 'package:myapp/core/router/app_router.dart';
import 'package:myapp/features/home/data/home_providers.dart';
import 'package:myapp/features/home/domain/learning_path.dart';
import 'package:myapp/features/lessons/domain/course.dart';
import 'package:myapp/features/lessons/data/lesson_completion_repository.dart';
import 'package:myapp/features/onboarding/data/course_catalog.dart';
import 'package:myapp/features/onboarding/data/onboarding_repository.dart';
import 'package:myapp/features/onboarding/domain/onboarding_settings.dart';
import 'package:myapp/features/onboarding/presentation/onboarding_controller.dart';
import 'package:myapp/shared/widgets/lesson_path_node.dart';

import 'support/phase3_fixtures.dart';

class AppHarness {
  AppHarness({
    MemoryOnboardingRepository? repository,
    OnboardingSettings? settings,
    bool statsError = false,
    Course? course,
    LessonCompletionRepository? completionRepository,
    ReviewRepository? reviewRepository,
    DateTime Function()? clock,
  }) {
    this.course = course ?? sampleCourse();
    this.repository = repository ?? MemoryOnboardingRepository(saved: settings);
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        onboardingRepositoryProvider.overrideWithValue(this.repository),
        appDatabaseProvider.overrideWithValue(database),
        if (clock != null) clockProvider.overrideWithValue(clock),
        if (reviewRepository != null)
          reviewRepositoryProvider.overrideWithValue(reviewRepository),
        appConfigProvider.overrideWithValue(
          const AppConfig(appName: 'Test App'),
        ),
        courseCatalogProvider.overrideWith((ref) async {
          if (catalogFails) throw StateError('Catalog failure');
          return catalogGate?.future ?? [this.course];
        }),
        if (completionRepository != null)
          lessonCompletionRepositoryProvider.overrideWithValue(
            completionRepository,
          ),
        if (statsError)
          userStatsProvider.overrideWith(
            (ref) => Stream.error(StateError('Stats error')),
          ),
      ],
    );
  }
  late final Course course;
  late final MemoryOnboardingRepository repository;
  late final AppDatabase database;
  late final ProviderContainer container;
  bool catalogFails = false;
  bool closed = false;
  Completer<List<Course>>? catalogGate;

  Future<void> close() async {
    if (closed) return;
    closed = true;
    container.dispose();
    await database.close();
  }
}

Future<void> mount(
  WidgetTester tester,
  AppHarness harness, {
  bool settle = true,
}) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(harness.close);
  });
  await tester.runAsync(() => harness.database.customSelect('SELECT 1').get());
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.container,
      child: const LanguageApp(),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> reachGoal(WidgetTester tester) async {
  await tapText(tester, 'Get Started');
  await tapText(tester, 'Japanese');
  await tapText(tester, 'Continue');
}

void main() {
  testWidgets('system Back preserves the onboarding draft', (tester) async {
    final harness = AppHarness();
    await mount(tester, harness);
    await reachGoal(tester);
    await tapText(tester, '5 minutes');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      harness.container.read(appRouterProvider).state.uri.path,
      '/languages',
    );
    expect(
      harness.container.read(onboardingFlowProvider).courseId,
      'ja_basics_en',
    );
    await tapText(tester, 'Continue');
    expect(harness.container.read(onboardingFlowProvider).goalMinutes, 5);
  });

  testWidgets('three steps persist choices; later launch skips onboarding', (
    tester,
  ) async {
    final harness = AppHarness();
    await mount(tester, harness);
    expect(find.text('Test App'), findsOneWidget);
    expect(
      harness.container.read(appRouterProvider).state.uri.path,
      '/welcome',
    );
    await reachGoal(tester);
    await tapText(tester, '15 minutes');
    await tapText(tester, 'Start learning');
    expect(harness.repository.saved!.courseId, 'ja_basics_en');
    expect(harness.repository.saved!.goalMinutes, 15);
    expect(find.text('Your daily goal: 15 minutes'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(harness.close);
    final second = AppHarness(repository: harness.repository);
    await mount(tester, second);
    final router = second.container.read(appRouterProvider);
    expect(router.state.uri.path, '/home');
    router.go('/welcome');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/home');
  });

  testWidgets('direct links cannot bypass onboarding or language selection', (
    tester,
  ) async {
    final harness = AppHarness();
    await mount(tester, harness);
    final router = harness.container.read(appRouterProvider);
    router.go('/lesson/ja_greetings');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/welcome');
    router.go('/daily-goal');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/languages');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('saving failures preserve choices and allow retry', (
    tester,
  ) async {
    final harness = AppHarness();
    harness.repository.failSave = true;
    await mount(tester, harness);
    await reachGoal(tester);
    await tapText(tester, '5 minutes');
    await tapText(tester, 'Start learning');
    expect(
      find.text('Your choices could not be saved. Please try again.'),
      findsOneWidget,
    );
    expect(harness.repository.saved, isNull);
    expect(harness.container.read(onboardingFlowProvider).goalMinutes, 5);
    harness.repository.failSave = false;
    await tapText(tester, 'Start learning');
    expect(harness.repository.saved!.goalMinutes, 5);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets(
    'in-flight save disables repeat submissions without redirecting',
    (tester) async {
      final harness = AppHarness();
      harness.repository.saveGate = Completer<void>();
      await mount(tester, harness);
      await reachGoal(tester);
      await tapText(tester, 'Start learning');
      expect(find.text('Saving…'), findsOneWidget);
      expect(
        harness.container.read(appRouterProvider).state.uri.path,
        '/daily-goal',
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull,
      );
      await harness.container.read(onboardingFlowProvider.notifier).finish();
      expect(harness.repository.saveCalls, 1);
      harness.repository.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('preferences loading and errors have a retry screen', (
    tester,
  ) async {
    final harness = AppHarness();
    harness.repository.loadGate = Completer<void>();
    await mount(tester, harness, settle: false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Get Started'), findsNothing);
    harness.repository.failLoad = true;
    harness.repository.loadGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Your preferences could not be loaded.'), findsOneWidget);
    harness.repository.failLoad = false;
    await tapText(tester, 'Try again');
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('data-driven language catalog errors can be retried', (
    tester,
  ) async {
    final harness = AppHarness()..catalogFails = true;
    await mount(tester, harness);
    await tapText(tester, 'Get Started');
    expect(find.text('Languages could not be loaded.'), findsOneWidget);
    harness.catalogFails = false;
    await tapText(tester, 'Try again');
    expect(find.text('Japanese'), findsOneWidget);
  });

  testWidgets('home loading and catalog errors can be retried', (tester) async {
    final harness = AppHarness(settings: completedSettings());
    harness.catalogGate = Completer<List<Course>>();
    await mount(tester, harness, settle: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    harness.catalogGate!.completeError(StateError('Catalog failure'));
    await tester.pumpAndSettle();
    expect(find.text('Your lessons could not be loaded.'), findsOneWidget);
    harness.catalogGate = null;
    await tapText(tester, 'Try again');
    expect(find.text('Japanese Basics'), findsOneWidget);
  });

  testWidgets('stats errors do not prevent learning path from loading', (
    tester,
  ) async {
    final harness = AppHarness(settings: completedSettings(), statsError: true);
    await mount(tester, harness);
    expect(find.text('Stats could not be loaded.'), findsOneWidget);
    expect(find.text('Retry stats'), findsOneWidget);
    expect(find.text('Japanese Basics'), findsOneWidget);
  });

  testWidgets('DB updates unlock next lesson, show stars and refresh stats', (
    tester,
  ) async {
    final harness = AppHarness(settings: completedSettings());
    await mount(tester, harness);
    expect(find.text('0 XP'), findsOneWidget);
    final secondFinder = find.byKey(const ValueKey('lesson-node-ja_people'));
    expect(
      tester.widget<LessonPathNode>(secondFinder).entry.availability,
      LessonAvailability.locked,
    );
    await harness.database
        .into(harness.database.lessonProgress)
        .insert(
          LessonProgressCompanion.insert(
            lessonId: 'ja_greetings',
            completed: const Value(true),
            bestScore: const Value(95),
          ),
        );
    await harness.database
        .update(harness.database.userStats)
        .write(const UserStatsCompanion(xp: Value(120), streak: Value(3)));
    await tester.pumpAndSettle();
    final first = tester.widget<LessonPathNode>(
      find.byKey(const ValueKey('lesson-node-ja_greetings')),
    );
    expect(first.entry.availability, LessonAvailability.completed);
    expect(first.entry.stars, 3);
    expect(
      tester.widget<LessonPathNode>(secondFinder).entry.availability,
      LessonAvailability.available,
    );
    expect(find.text('120 XP'), findsOneWidget);
    expect(find.text('3 days streak'), findsOneWidget);
    final firstButton = find.descendant(
      of: find.byKey(const ValueKey('lesson-node-ja_greetings')),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(firstButton);
    await tester.tap(firstButton);
    await tester.pumpAndSettle();
    expect(find.text('Check'), findsOneWidget);
    await tester.tap(find.byTooltip('Close lesson'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Leave');
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('tabs, locked and unknown lesson routes remain usable', (
    tester,
  ) async {
    final harness = AppHarness(settings: completedSettings());
    await mount(tester, harness);
    await tapText(tester, 'Review');
    expect(find.text('Your review deck is ready to grow.'), findsOneWidget);
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    expect(
      find.text('Your profile will appear here in a future phase.'),
      findsOneWidget,
    );
    final router = harness.container.read(appRouterProvider);
    router.go('/lesson/ja_people');
    await tester.pumpAndSettle();
    expect(find.text('Lesson locked'), findsWidgets);
    router.go('/lesson/missing');
    await tester.pumpAndSettle();
    expect(find.text('Lesson not found'), findsWidgets);
    router.go('/missing');
    await tester.pumpAndSettle();
    await tapText(tester, 'Go to Learn');
    expect(find.text('Japanese Basics'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('320px phone with 200% text in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final harness = AppHarness();
      await mount(tester, harness);
      final router = harness.container.read(appRouterProvider);
      await reachGoal(tester);
      await tapText(tester, 'Start learning');
      for (final route in [
        '/home',
        '/review',
        '/profile',
        '/lesson/ja_greetings',
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
          brightness,
        );
        expect(tester.takeException(), isNull, reason: route);
      }
      router.go('/home');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Daily life'),
        300,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Daily life'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
```

## README.md

````markdown
# Language learning app - Phases 1 through 5

This project contains Material 3 light/dark themes, Riverpod, go_router,
three-step onboarding, a learning path, an exercise engine, spaced-repetition flashcards,
and a placeholder Profile screen.
Phase 2 adds course content, immutable models, asset loading, and Drift tables.
Phase 3 connects onboarding preferences and database progress to the interface.
Phase 4 adds playable lessons, feedback, results, XP awards, and progress saving.
Phase 5 adds SM-2 scheduling, card enrollment, review sessions, and review summaries.
Backend integration, audio playback, and AI conversation belong to later phases.

## Create a separate project

Replace MYHANDLE and app_name before running. Keep app_name lowercase_with_underscores.
Do not recreate the existing project to run it.

```powershell
flutter doctor -v
flutter create --org com.MYHANDLE --project-name app_name app_name
cd app_name
```

The existing project keeps package name myapp and its existing native identifiers.
Changing the org flag only affects newly created projects. In another package,
replace package:myapp/ imports in tests with package:app_name/.

## Android setup and run

Your current doctor output reports missing Android SDK Command-line Tools and
unknown Android license status. In Android Studio, open Tools > SDK Manager >
SDK Tools, install Android SDK Command-line Tools (latest), and then run:

```powershell
flutter doctor --android-licenses
flutter doctor -v
cd C:\Langunge_flutter\myapp
flutter pub get
flutter emulators
flutter emulators --launch Medium_Phone_API_37.0
flutter devices
```

Wait until the emulator boots. Use the Android device ID printed by flutter devices
(e.g. emulator-5554, which can vary):

```powershell
flutter run -d emulator-5554 --dart-define="APP_NAME=My Language App" --dart-define="TARGET_LANGUAGE=Japanese" --dart-define="NATIVE_LANGUAGE=English"
```

Press r for hot reload, R for hot restart, and q to quit. Change dart-defines by
stopping and rerunning. AppConfig uses dart-defines; flutter_dotenv is installed
but no .env file or asset registration is needed in this phase.
Client configuration is not a place for private server credentials.

## Verify

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Widget tests cover welcome configuration, all bottom tabs, lesson IDs, back
navigation, direct routes, an unknown route, and 320x568 layouts at 200% text
scale in both light and dark themes. An Android build has not been verified.

## Structure

- lib/app: root app widget.
- lib/core/config: compile-time configuration.
- lib/core/theme: shared ColorScheme and typography.
- lib/core/constants: route constants.
- lib/core/router: go_router configuration.
- lib/core/utils: reserved for shared utilities.
- lib/features/{onboarding,home,lessons,exercises,flashcards,profile}/:
  each feature has data, domain, and presentation folders.
- lib/shared/widgets: reusable widgets.

Empty folders have empty .gitkeep files so Git can retain them.
ProviderScope supplies Riverpod providers, much like React context.
ConsumerWidget can watch those providers and rebuild when their values change.
StatefulShellRoute.indexedStack keeps each bottom tab's navigation state.
context.go changes location; context.push stacks a page so Back returns to Learn.
ThemeMode.system follows the device light/dark setting. The text theme inherits
platform fonts, then customizes weights and line heights.

## Dependencies and Git

Direct dependency versions were checked against pub.dev's latest stable metadata.
drift_dev and build_runner are dev dependencies for the Drift database generator;
see the Phase 2 commands below to regenerate it after schema edits.
Commit pubspec.lock in this application to reproduce resolved dependencies.
.gitignore excludes build output, local env files, SDK paths, and signing files.
This directory currently has no Git repository; initialize one when ready.
See PHASE1_FILES.md for complete setup file contents and the dependency lockfile.

## Phase 2: content and persistence

Sample language assumption: Japanese for English speakers. The registered asset
is assets/courses/japanese_basics.json: 1 course, 2 units, 3 lessons per unit,
6 exercises per lesson, and 60 common words/phrases (10 per lesson). Topics are
greetings, people, numbers, food, places, and actions. Example sentences may
include supporting vocabulary beyond the 60 study entries. Audio URLs are optional
and omitted because no recordings have been supplied.

All content models are handwritten immutable classes. Their lists are copied
into unmodifiable lists, and fromJson rejects missing/invalid required fields.
Exercises use a sealed hierarchy with a type discriminator in JSON.

CourseRepository loads the Flutter asset through an injectable AssetBundle.
courseProvider is a FutureProvider<Course>, so consumers receive an AsyncValue
that represents loading, data, or an error. Phase 3 uses the course catalog to
connect the selected course to Learn. Phase 4 renders its exercises in lesson screens.
The sample path can be overridden via COURSE_ASSET using --dart-define; any
replacement asset must also be registered in pubspec.yaml. App display language
configuration does not translate or select content automatically.

The Drift database lives in lib/core/database/app_database.dart and is exposed
through appDatabaseProvider. It opens lazily when a consumer first queries it.
Only Drift infrastructure uses code generation; the content models do not.
Tables use IDs matching content IDs, but no SQL foreign keys reference the JSON
asset. Word dueDate is required; completedAt and lastActiveDate are nullable.
bestScore is a percentage from 0 to 100. UserStats adds an internal primary key
restricted to 1, ensuring one local user's stats row, initialized on creation.
No XP, streak, scoring, or spaced-repetition algorithms are implemented yet.

After editing the database schema, regenerate its code:

```powershell
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

Keep app_database.g.dart with the source, and do not edit it manually. Schema
version is 1; later schema changes will need a version bump and a migration.
The native database setup targets Android/iOS/desktop; running the database on
web requires Drift's separate web worker/WASM setup in a later phase.

Tests check every required sample field for missing and null values, JSON round
trips, optional audio, immutable collections, exercise validation, duplicate IDs,
broken word references, injected/registered asset loading, database defaults,
progress round trips, and database constraints. SQLite tests use an in-memory DB.
See PHASE2_FILES.md for the short JSON schema table and every Phase 2 file in full.

## Phase 3: onboarding and Learn

First launch follows /welcome -> /languages -> /daily-goal. A language must be
selected before continuing. Daily goals are 5, 10, or 15 minutes (default 10).
OnboardingRepository stores the selected course ID and goal in one versioned JSON
document using SharedPreferencesAsync. Completion is published to Riverpod only
after saving succeeds, so a failed save stays on the goal screen with a retry.
A startup screen handles asynchronous preference loading and read errors.
Returning launches redirect to /home; completed users cannot revisit onboarding
routes. System Back preserves choices when moving between onboarding steps.

The language list is driven by courseCatalogPathsProvider. It starts with the
Japanese asset selected by courseAssetPathProvider. Add another registered asset
to the catalog to extend the choices; labels come from the course metadata.
Course IDs are stable preference keys, so changing a label does not lose selection.

Learn displays unit sections and round lesson nodes. A pure LearningPath model
flattens lessons in JSON order: the first incomplete lesson is available; later
incomplete lessons are locked; completed lessons remain open. The database's
completed flag controls unlocking, even when an unfinished lesson has a score.
Completed scores earn 1 star below 70%, 2 at 70-89%, and 3 at 90-100%.
LessonProgress and UserStats are observed with Riverpod StreamProviders: new
records update the path, XP, and streak without restarting or manually refreshing.
No completion, XP award, streak calculation, or exercise gameplay is added here.
The tests insert progress records to exercise the unlocking behavior.

Tapping an available/completed node pushes /lesson/:id. Direct links to locked
or unknown lesson IDs show explanatory pages. Loading/error states have friendly
messages and retry actions; stats failures do not hide the learning path.

Shared widgets provide responsive page bodies, loading/error feedback, choice
cards, wrapping stat badges, and accessible lesson nodes. Tests exercise 320x568
screens at 200% text scale in light and dark themes, including scrolling to unit 2.

```powershell
cd C:\Langunge_flutter\myapp
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d emulator-5554
```

Use your Android device ID in the final command. No dependency or database schema
changes were needed for Phase 3, so there is no new database generation step.
To manually test onboarding, complete the steps, quit, and reopen the app: Learn
should open directly. To see onboarding again in development, clear this app's
storage through Android Settings (this also clears its local database).
See PHASE3_FILES.md for the file manifest and full Phase 3 code.

## Phase 4: exercise engine

LessonController is an auto-disposed Riverpod Notifier family, keyed by the
loaded Lesson. A Notifier exposes immutable state and methods that change it;
widgets watch the state and invoke those methods rather than grade answers.
Auto-dispose releases a session after its lesson screen closes. Returning to the
same lesson starts a new attempt. Results are rendered on the existing lesson
route so there is no separate results URL that could lose the session.

The controller owns the exercise queue, current index, three hearts, answer draft,
pair selection, correct count, attempt count, first-try count, feedback, phase,
and save status. Phases are answering, feedback, and finished. Check stays
disabled until the answer is complete. Feedback locks the current answer.
Wrong answers cost one heart and append the whole exercise to the queue.
Continue advances after feedback, including the final correction when hearts
reach zero. Progress measures unique exercises cleared out of the original count.

The exercise grader and answer/result models contain no Flutter imports.
MultipleChoice and FillInBlank grade selected choices. MatchPairs shuffles the
right column, supports either tap direction, and allows unpairing by tapping a
paired card. Check grades a complete set of pairs as one exercise. TypeTranslation
trims leading/trailing whitespace, ignores case, and accepts any listed answer;
it does not ignore punctuation, accents, or internal spacing.

Scoring assumptions:

- Success means clearing the entire retry queue with at least one heart left.
- Accuracy is correct attempts divided by all checked attempts, rounded to a
  percentage for display and LessonProgress.bestScore.
- A perfect exercise is answered correctly on its first attempt.
- A successful run awards 10 base XP + 5 XP per perfect exercise. A perfect
  six-exercise sample lesson earns 40 XP. Failed or abandoned runs earn 0 XP.
- Each new successful replay awards its own XP. Repeated checks, Continue taps,
  and save taps in the same session cannot award XP twice.

LessonCompletionRepository writes progress and XP in one Drift transaction.
It marks the lesson complete, preserves its highest score and first completion
date, and increments UserStats.xp without changing the streak. The existing
progress streams unlock the next lesson immediately after commit. Failed saves
roll back both writes and leave the result available for retry. Successful
results allow Continue after saving; failed runs allow Continue immediately.
A close button or system Back asks before abandoning a lesson. Closing an unsaved
result also asks before discarding it; closing is disabled during the save.

The lesson layout keeps the progress/hearts header, scrolling exercise, and
Check/Continue area separate. Feedback is green/red with a correct-answer label,
including an independently scrollable list for match pairs. Header and action
areas can scroll when enlarged text or the keyboard reduces available height.

```powershell
cd C:\Langunge_flutter\myapp
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d emulator-5554
```

Use the Android device ID shown by flutter devices. Complete onboarding if needed,
tap the first available lesson, answer all exercises, and Continue from results.
Check that XP increases and the next node unlocks. Also try three mistakes and
cancel/confirm the close dialog. No new dependencies or database schema changes
were needed, so the existing generated Drift file is unchanged.
See PHASE4_FILES.md for the complete file manifest and source snapshot.

## Phase 5: flashcards and spaced repetition

Sm2 in lib/features/flashcards/domain/sm2.dart is a pure Dart scheduler. Its
schedule method takes quality, repetitions, easeFactor, intervalDays, and an
explicit reviewedAt timestamp, and returns a Sm2Schedule with updated values
and dueDate. Using an explicit time makes the algorithm deterministic in tests.

- Quality below 3 resets repetitions to 0 and intervalDays to 1.
- A successful rating schedules 1 day, then 6 days, then round(interval * easeFactor).
  The interval uses the incoming ease factor; the updated factor is for the next rating.
- Every rating updates easeFactor using the requested formula, with a 1.3 floor.
- One scheduling day is 24 hours. Due dates are UTC instants; the interface
  formats the next due time in the device's local time.
- Again, Hard, Good, and Easy map to quality 1, 3, 4, and 5.
  Again schedules a card one day out rather than repeating it within this session.

Successful lesson saving now requires its wordIds and inserts missing WordProgress
rows in the same transaction as LessonProgress and XP. New cards start with ease
2.5, zero repetitions, zero interval, and a due time of now. Insert-or-ignore
preserves existing schedules during lesson replays and when words occur again.
The Review repository also backfills words from already completed lessons when
the review deck/session loads. Only vocabulary declared in lesson.wordIds is
enrolled; words merely used as supporting text in an example are not inferred.

Review shows cards due at or before now, including overdue cards. Future cards
become available at their exact scheduled time; the count does not include a card
that will only become due later today. A Drift stream and a timer for the next
due card keep the count current, and app resume rechecks it. The deck is filtered
to the selected course. An empty deck either explains how to add words or shows
the next scheduled due time.

Start opens /review/session with a snapshot of the due cards, ordered by due time
and word ID. Cards added after a session starts are left for a subsequent session.
The front shows the word; tapping flips to its translation and example. Rating
buttons are disabled until the answer is revealed. AnimatedSwitcher plus Transform
provides the flip using Flutter alone, with a 240ms transition and reduced-motion
support. Card contents and buttons scroll on small screens and with large text.

ReviewSessionController saves a rating before advancing. Repeated taps during a
save are ignored, and a failed save leaves the revealed card available to retry.
The repository re-reads the stored progress inside a transaction before applying
SM-2. Closing a session keeps all ratings already saved, while its unreviewed
cards remain due. The session summary shows the number reviewed and rating counts.
Review does not award XP or change streaks in this phase.

```powershell
cd C:\Langunge_flutter\myapp
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d emulator-5554
```

Replace the device ID with yours. Complete a lesson, open Review, tap Start,
reveal each card, and choose a rating. After the summary, Continue should show
an empty state with the next due time if all currently due cards were reviewed.
Existing completed lessons also produce cards automatically on opening Review.
No dependencies, table definitions, generated database files, or schema version
changes were needed. clockProvider supplies an injectable UTC clock for tests.

Validation: all 94 tests pass, including 10 SM-2 tests, transactional enrollment,
backfill, schedule preservation, due-time updates without database writes, all
rating mappings, session save retry, partial sessions, app resume, reduced motion,
and 320px layouts at 200% text scale in light/dark themes. flutter analyze reports
no issues and formatting is clean. An Android emulator run was not performed.
See PHASE5_FILES.md for the file manifest and full Phase 5 source.
````

