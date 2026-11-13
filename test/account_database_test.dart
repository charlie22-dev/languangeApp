import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/features/sync/data/local_sync_store.dart';

void main() {
  test(
    'version 4 upgrades chat tables without changing existing progress',
    () async {
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute('''
        CREATE TABLE lesson_progress (lesson_id TEXT PRIMARY KEY NOT NULL, completed INTEGER NOT NULL DEFAULT 0, best_score INTEGER NOT NULL DEFAULT 0, completed_at INTEGER, updated_at INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1);
        CREATE TABLE word_progress (word_id TEXT PRIMARY KEY NOT NULL, ease_factor REAL NOT NULL DEFAULT 2.5, interval_days INTEGER NOT NULL DEFAULT 0, repetitions INTEGER NOT NULL DEFAULT 0, due_date INTEGER, updated_at INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1, deleted INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE user_stats (id INTEGER PRIMARY KEY NOT NULL DEFAULT 1, xp INTEGER NOT NULL DEFAULT 0, streak INTEGER NOT NULL DEFAULT 0, longest_streak INTEGER NOT NULL DEFAULT 0, last_active_date INTEGER, updated_at INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1);
        CREATE TABLE sync_metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);
        CREATE TABLE local_profiles (id INTEGER PRIMARY KEY NOT NULL DEFAULT 1, display_name TEXT NOT NULL, updated_at INTEGER NOT NULL, dirty INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE daily_activities (activity_date TEXT PRIMARY KEY NOT NULL, xp INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1);
        INSERT INTO user_stats(id,xp,streak,longest_streak,dirty) VALUES (1,80,3,5,0);
        INSERT INTO word_progress(word_id,repetitions,due_date) VALUES ('hello',2,1000);
        PRAGMA user_version = 4;
      ''');
          },
        ),
      );
      addTearDown(database.close);
      final stats = await database.select(database.userStats).getSingle();
      expect(stats.xp, 80);
      expect(stats.longestStreak, 5);
      expect(stats.dirty, isFalse);
      expect(
        (await database.select(database.wordProgress).getSingle()).repetitions,
        2,
      );
      expect(await database.select(database.chatEntries).get(), isEmpty);
      expect(await database.select(database.savedVocabulary).get(), isEmpty);
    },
  );
  test('version 3 upgrades progress, longest streak and reset flags without data loss', () async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
        CREATE TABLE lesson_progress (lesson_id TEXT PRIMARY KEY NOT NULL, completed INTEGER NOT NULL DEFAULT 0, best_score INTEGER NOT NULL DEFAULT 0, completed_at INTEGER, updated_at INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1);
        CREATE TABLE word_progress (word_id TEXT PRIMARY KEY NOT NULL, ease_factor REAL NOT NULL DEFAULT 2.5, interval_days INTEGER NOT NULL DEFAULT 0, repetitions INTEGER NOT NULL DEFAULT 0, due_date INTEGER, updated_at INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1);
        CREATE TABLE user_stats (id INTEGER PRIMARY KEY NOT NULL DEFAULT 1, xp INTEGER NOT NULL DEFAULT 0, streak INTEGER NOT NULL DEFAULT 0, last_active_date INTEGER, updated_at INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1);
        CREATE TABLE sync_metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);
        CREATE TABLE local_profiles (id INTEGER PRIMARY KEY NOT NULL DEFAULT 1, display_name TEXT NOT NULL, updated_at INTEGER NOT NULL, dirty INTEGER NOT NULL DEFAULT 0);
        INSERT INTO user_stats(id,xp,streak,updated_at,dirty) VALUES (1,80,5,100,0);
        INSERT INTO word_progress(word_id,due_date) VALUES ('hello',1000);
        INSERT INTO sync_metadata(key,value) VALUES ('legacyImported','1');
        PRAGMA user_version = 3;
      ''');
        },
      ),
    );
    addTearDown(database.close);
    final stats = await database.select(database.userStats).getSingle();
    expect(stats.xp, 80);
    expect(stats.longestStreak, 5);
    expect(stats.dirty, isFalse);
    expect(
      (await database.select(database.wordProgress).getSingle()).deleted,
      isFalse,
    );
    expect(await database.select(database.dailyActivities).get(), isEmpty);
    expect(
      (await database.select(database.syncMetadata).getSingle()).value,
      '1',
    );
  });
  setUp(() {
    // These tests intentionally open distinct in-memory executors for each account.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });
  tearDown(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  test(
    'schema version 1 migrates existing data to durable pending sync rows',
    () async {
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute('''
        CREATE TABLE lesson_progress (lesson_id TEXT PRIMARY KEY NOT NULL, completed INTEGER NOT NULL DEFAULT 0, best_score INTEGER NOT NULL DEFAULT 0, completed_at INTEGER);
        CREATE TABLE word_progress (word_id TEXT PRIMARY KEY NOT NULL, ease_factor REAL NOT NULL DEFAULT 2.5, interval_days INTEGER NOT NULL DEFAULT 0, repetitions INTEGER NOT NULL DEFAULT 0, due_date INTEGER NOT NULL);
        CREATE TABLE user_stats (id INTEGER PRIMARY KEY NOT NULL DEFAULT 1, xp INTEGER NOT NULL DEFAULT 0, streak INTEGER NOT NULL DEFAULT 0, last_active_date INTEGER);
        INSERT INTO user_stats(id, xp, streak) VALUES (1, 80, 3);
        INSERT INTO word_progress(word_id, due_date) VALUES ('ja_hello', 1000);
        INSERT INTO lesson_progress(lesson_id, completed, best_score) VALUES ('ja_greetings', 1, 90);
        PRAGMA user_version = 1;
      ''');
          },
        ),
      );
      addTearDown(database.close);
      final stats = await database.select(database.userStats).getSingle();
      expect(stats.xp, 80);
      expect(stats.streak, 3);
      expect(stats.updatedAt, 0);
      expect(stats.dirty, isTrue);
      expect(
        (await database.select(database.wordProgress).getSingle()).dirty,
        isTrue,
      );
      expect(
        (await database.select(database.lessonProgress).getSingle()).bestScore,
        90,
      );
      expect(await database.select(database.syncMetadata).get(), isEmpty);
    },
  );

  test(
    'legacy progress is claimed by one account and never copied to another',
    () async {
      final legacy = AppDatabase.forTesting(NativeDatabase.memory());
      final a = AppDatabase.forTesting(NativeDatabase.memory());
      final b = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(legacy.close);
      addTearDown(a.close);
      addTearDown(b.close);
      await legacy.select(legacy.userStats).getSingle();
      await legacy
          .update(legacy.userStats)
          .write(const UserStatsCompanion(xp: Value(80)));
      await legacy
          .into(legacy.wordProgress)
          .insert(
            WordProgressCompanion.insert(
              wordId: 'ja_hello',
              dueDate: DateTime.utc(2026, 11, 8),
            ),
          );
      await LocalSyncStore(a).importLegacy(legacy, 'A');
      await LocalSyncStore(b).importLegacy(legacy, 'B');
      expect((await a.select(a.userStats).getSingle()).xp, 80);
      expect((await a.select(a.userStats).getSingle()).updatedAt, 1);
      expect((await a.select(a.wordProgress).get()).length, 1);
      expect((await b.select(b.userStats).getSingle()).xp, 0);
      expect(await b.select(b.wordProgress).get(), isEmpty);
      await a
          .update(a.userStats)
          .write(
            const UserStatsCompanion(xp: Value(100), updatedAt: Value(10)),
          );
      await LocalSyncStore(a).importLegacy(legacy, 'A');
      expect((await a.select(a.userStats).getSingle()).xp, 100);
    },
  );

  test('schema version 2 adds profiles without losing sync metadata or pending flags', () async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
        CREATE TABLE lesson_progress (lesson_id TEXT PRIMARY KEY NOT NULL, completed INTEGER NOT NULL DEFAULT 0, best_score INTEGER NOT NULL DEFAULT 0, completed_at INTEGER, updated_at INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1);
        CREATE TABLE word_progress (word_id TEXT PRIMARY KEY NOT NULL, ease_factor REAL NOT NULL DEFAULT 2.5, interval_days INTEGER NOT NULL DEFAULT 0, repetitions INTEGER NOT NULL DEFAULT 0, due_date INTEGER NOT NULL, updated_at INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1);
        CREATE TABLE user_stats (id INTEGER PRIMARY KEY NOT NULL DEFAULT 1, xp INTEGER NOT NULL DEFAULT 0, streak INTEGER NOT NULL DEFAULT 0, last_active_date INTEGER, updated_at INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1);
        CREATE TABLE sync_metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);
        INSERT INTO user_stats(id,xp,updated_at,dirty) VALUES (1,80,100,0);
        INSERT INTO sync_metadata(key,value) VALUES ('legacyImported','1');
        PRAGMA user_version = 2;
      ''');
        },
      ),
    );
    addTearDown(database.close);
    final row = await database.select(database.userStats).getSingle();
    expect(row.xp, 80);
    expect(row.updatedAt, 100);
    expect(row.dirty, isFalse);
    expect(
      (await database.select(database.syncMetadata).getSingle()).value,
      '1',
    );
    expect(await database.select(database.localProfiles).get(), isEmpty);
    expect((await LocalSyncStore(database).readCursor()).revision, 0);
  });

  test(
    'account filenames are deterministic and cannot contain path separators',
    () {
      expect(AppDatabase.databaseName(null), 'language_learning');
      expect(
        AppDatabase.databaseName('A'),
        isNot(AppDatabase.databaseName('B')),
      );
      expect(AppDatabase.databaseName('a/b'), isNot(contains('/')));
      expect(AppDatabase.databaseName('A'), AppDatabase.databaseName('A'));
    },
  );
}
