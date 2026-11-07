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
