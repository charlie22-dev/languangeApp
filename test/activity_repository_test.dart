import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/features/activity/data/activity_repository.dart';
import 'package:myapp/features/flashcards/data/word_enrollment.dart';
import 'package:myapp/features/sync/data/local_sync_store.dart';
import 'package:myapp/features/sync/domain/sync_record.dart';

void main() {
  late AppDatabase db;
  late ActivityRepository repository;
  late DateTime now;
  setUp(() {
    now = DateTime(2026, 11, 13, 10);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = ActivityRepository(db, clock: () => now);
  });
  tearDown(() => db.close());
  Future<void> award(int xp) => db.transaction(() => repository.award(xp, now));

  test('daily XP accumulates while repeat practice preserves streak', () async {
    await award(35);
    await award(20);
    final stats = await db.select(db.userStats).getSingle();
    expect(stats.xp, 55);
    expect(stats.streak, 1);
    expect(stats.longestStreak, 1);
    expect((await db.select(db.dailyActivities).getSingle()).xp, 55);
  });
  test(
    'a legacy current streak remains the longest when a missed day resets',
    () async {
      await db
          .update(db.userStats)
          .write(
            UserStatsCompanion(
              streak: const Value(5),
              lastActiveDate: Value(DateTime(2026, 11, 11).toUtc()),
            ),
          );
      await award(20);
      final stats = await db.select(db.userStats).getSingle();
      expect(stats.streak, 1);
      expect(stats.longestStreak, 5);
    },
  );
  test(
    'consecutive local days continue and missed days preserve longest record',
    () async {
      await award(35);
      now = DateTime(2026, 11, 14);
      await award(35);
      expect((await db.select(db.userStats).getSingle()).streak, 2);
      now = DateTime(2026, 11, 16);
      await award(35);
      final stats = await db.select(db.userStats).getSingle();
      expect(stats.streak, 1);
      expect(stats.longestStreak, 2);
      expect((await db.select(db.dailyActivities).get()).length, 3);
    },
  );
  test(
    'reset stays offline and stale incoming sync cannot resurrect progress',
    () async {
      await award(35);
      await enrollWords(db, ['hello'], now);
      await db
          .into(db.lessonProgress)
          .insert(LessonProgressCompanion.insert(lessonId: 'lesson'));
      final old = await LocalSyncStore(db).snapshot(dirtyOnly: false);
      await repository.reset();
      await LocalSyncStore(db).merge(old);
      final stats = await db.select(db.userStats).getSingle();
      expect(stats.xp, 0);
      expect(stats.streak, 0);
      expect(stats.longestStreak, 0);
      expect((await db.select(db.wordProgress).getSingle()).deleted, isTrue);
      expect((await db.select(db.dailyActivities).getSingle()).xp, 0);
      final dirty = await LocalSyncStore(db).snapshot();
      expect(
        dirty.records
            .where((r) => r.kind == SyncKind.word)
            .single
            .data['deleted'],
        isTrue,
      );
      expect(dirty.records.any((r) => r.kind == SyncKind.activity), isTrue);
      await enrollWords(db, ['hello'], now);
      final revived = await db.select(db.wordProgress).getSingle();
      expect(revived.deleted, isFalse);
      expect(revived.repetitions, 0);
    },
  );
  test(
    'activity merge persists per-day XP and rejects stale replacements',
    () async {
      await award(35);
      await LocalSyncStore(db).merge(
        SyncSnapshot([
          SyncRecord.fromJson(SyncKind.activity, {
            'activity_date': '2026-11-13',
            'xp': 1,
            'updated_at': 0,
          }),
        ]),
      );
      expect((await db.select(db.dailyActivities).getSingle()).xp, 35);
    },
  );
}
