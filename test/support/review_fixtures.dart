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
