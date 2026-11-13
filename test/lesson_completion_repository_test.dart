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
        .write(
          UserStatsCompanion(
            xp: const Value(50),
            streak: const Value(4),
            lastActiveDate: Value(now),
          ),
        );
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
