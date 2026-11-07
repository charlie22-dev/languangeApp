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
