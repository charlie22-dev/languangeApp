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
