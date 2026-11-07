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
