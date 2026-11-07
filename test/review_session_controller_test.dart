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
