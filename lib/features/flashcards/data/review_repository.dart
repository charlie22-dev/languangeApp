import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/sync_timestamp.dart';
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
        ..where((row) => row.deleted.equals(false))
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
            updatedAt: Value(nextSyncTimestamp(row.updatedAt, clock())),
            dirty: const Value(true),
          ),
        );
        return next;
      });
}
