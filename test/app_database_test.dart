import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('fresh database has a single zeroed stats row', () async {
    final stats = await database.select(database.userStats).getSingle();
    expect(stats.id, 1);
    expect(stats.xp, 0);
    expect(stats.streak, 0);
    expect(stats.lastActiveDate, isNull);
  });

  test(
    'lesson and word progress store requested fields and defaults',
    () async {
      await database
          .into(database.lessonProgress)
          .insert(LessonProgressCompanion.insert(lessonId: 'ja_greetings'));
      final initial = await database
          .select(database.lessonProgress)
          .getSingle();
      expect(initial.completed, isFalse);
      expect(initial.bestScore, 0);
      expect(initial.completedAt, isNull);
      final date = DateTime.utc(2026, 11, 8);
      await database
          .into(database.lessonProgress)
          .insertOnConflictUpdate(
            LessonProgressCompanion.insert(
              lessonId: 'ja_greetings',
              completed: const Value(true),
              bestScore: const Value(90),
              completedAt: Value(date),
            ),
          );
      final completed = await database
          .select(database.lessonProgress)
          .getSingle();
      expect(completed.completed, isTrue);
      expect(completed.bestScore, 90);
      expect(completed.completedAt!.toUtc(), date);
      await database
          .into(database.wordProgress)
          .insert(
            WordProgressCompanion.insert(wordId: 'ja_hello', dueDate: date),
          );
      final word = await database.select(database.wordProgress).getSingle();
      expect(word.wordId, 'ja_hello');
      expect(word.easeFactor, 2.5);
      expect(word.intervalDays, 0);
      expect(word.repetitions, 0);
      expect(word.dueDate.toUtc(), date);
    },
  );

  test(
    'constraints reject invalid scores and multiple stats identities',
    () async {
      await expectLater(
        database
            .into(database.lessonProgress)
            .insert(
              LessonProgressCompanion.insert(
                lessonId: 'bad',
                bestScore: const Value(101),
              ),
            ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        database
            .into(database.userStats)
            .insert(UserStatsCompanion.insert(id: const Value(2))),
        throwsA(isA<Exception>()),
      );
    },
  );
}
