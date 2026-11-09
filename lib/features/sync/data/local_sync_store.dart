import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/sync_record.dart';

class LocalSyncStore {
  const LocalSyncStore(this.database);
  final AppDatabase database;

  Future<SyncSnapshot> snapshot({bool dirtyOnly = true}) =>
      database.transaction(() async {
        final statsQuery = database.select(database.userStats);
        final wordsQuery = database.select(database.wordProgress);
        final lessonsQuery = database.select(database.lessonProgress);
        if (dirtyOnly) {
          statsQuery.where((row) => row.dirty.equals(true));
          wordsQuery.where((row) => row.dirty.equals(true));
          lessonsQuery.where((row) => row.dirty.equals(true));
        }
        final stats = await statsQuery.get();
        final words = await wordsQuery.get();
        final lessons = await lessonsQuery.get();
        return SyncSnapshot([
          for (final row in stats)
            SyncRecord.fromJson(SyncKind.stats, {
              'xp': row.xp,
              'streak': row.streak,
              'last_active_date': row.lastActiveDate?.toUtc().toIso8601String(),
              'updated_at': row.updatedAt,
            }),
          for (final row in words)
            SyncRecord.fromJson(SyncKind.word, {
              'word_id': row.wordId,
              'ease_factor': row.easeFactor,
              'interval_days': row.intervalDays,
              'repetitions': row.repetitions,
              'due_date': row.dueDate.toUtc().toIso8601String(),
              'updated_at': row.updatedAt,
            }),
          for (final row in lessons)
            SyncRecord.fromJson(SyncKind.lesson, {
              'lesson_id': row.lessonId,
              'completed': row.completed,
              'best_score': row.bestScore,
              'completed_at': row.completedAt?.toUtc().toIso8601String(),
              'updated_at': row.updatedAt,
            }),
        ]);
      });

  Future<void> merge(
    SyncSnapshot remote, {
    bool imported = false,
  }) => database.transaction(() async {
    for (final row in remote.records) {
      final data = row.data;
      DateTime? date(String key) => data[key] == null
          ? null
          : DateTime.parse(data[key] as String).toUtc();
      switch (row.kind) {
        case SyncKind.stats:
          final current = await database
              .select(database.userStats)
              .getSingleOrNull();
          if (!remoteWins(current?.updatedAt, row.updatedAt)) continue;
          if (current != null &&
              current.updatedAt == row.updatedAt &&
              current.dirty == imported &&
              current.xp == data['xp'] &&
              current.streak == data['streak'] &&
              current.lastActiveDate?.toUtc() == date('last_active_date')) {
            continue;
          }
          await database
              .into(database.userStats)
              .insertOnConflictUpdate(
                UserStatsCompanion.insert(
                  id: const Value(1),
                  xp: Value(data['xp'] as int),
                  streak: Value(data['streak'] as int),
                  lastActiveDate: Value(date('last_active_date')),
                  updatedAt: Value(row.updatedAt),
                  dirty: Value(imported),
                ),
              );
        case SyncKind.word:
          final current = await (database.select(
            database.wordProgress,
          )..where((table) => table.wordId.equals(row.id))).getSingleOrNull();
          if (!remoteWins(current?.updatedAt, row.updatedAt)) continue;
          if (current != null &&
              current.updatedAt == row.updatedAt &&
              current.dirty == imported &&
              current.easeFactor == data['ease_factor'] &&
              current.intervalDays == data['interval_days'] &&
              current.repetitions == data['repetitions'] &&
              current.dueDate.toUtc() == date('due_date')) {
            continue;
          }
          await database
              .into(database.wordProgress)
              .insertOnConflictUpdate(
                WordProgressCompanion.insert(
                  wordId: row.id,
                  easeFactor: Value(data['ease_factor'] as double),
                  intervalDays: Value(data['interval_days'] as int),
                  repetitions: Value(data['repetitions'] as int),
                  dueDate: date('due_date')!,
                  updatedAt: Value(row.updatedAt),
                  dirty: Value(imported),
                ),
              );
        case SyncKind.lesson:
          final current = await (database.select(
            database.lessonProgress,
          )..where((table) => table.lessonId.equals(row.id))).getSingleOrNull();
          if (!remoteWins(current?.updatedAt, row.updatedAt)) continue;
          if (current != null &&
              current.updatedAt == row.updatedAt &&
              current.dirty == imported &&
              current.completed == data['completed'] &&
              current.bestScore == data['best_score'] &&
              current.completedAt?.toUtc() == date('completed_at')) {
            continue;
          }
          await database
              .into(database.lessonProgress)
              .insertOnConflictUpdate(
                LessonProgressCompanion.insert(
                  lessonId: row.id,
                  completed: Value(data['completed'] as bool),
                  bestScore: Value(data['best_score'] as int),
                  completedAt: Value(date('completed_at')),
                  updatedAt: Value(row.updatedAt),
                  dirty: Value(imported),
                ),
              );
      }
    }
  });

  Future<void> importLegacy(AppDatabase legacy, String uid) async {
    final done = await (database.select(
      database.syncMetadata,
    )..where((row) => row.key.equals('legacyImported'))).getSingleOrNull();
    if (done != null) return;
    // Claim first. A failed copy can resume only for this account, never another user.
    final ownsLegacy = await legacy.transaction(() async {
      await legacy
          .into(legacy.syncMetadata)
          .insert(
            SyncMetadataCompanion.insert(key: 'legacyOwner', value: uid),
            mode: InsertMode.insertOrIgnore,
          );
      return (await (legacy.select(
                legacy.syncMetadata,
              )..where((row) => row.key.equals('legacyOwner'))).getSingle())
              .value ==
          uid;
    });
    await database.transaction(() async {
      if (ownsLegacy) {
        await merge(
          await LocalSyncStore(legacy).snapshot(dirtyOnly: false),
          imported: true,
        );
      }
      await database
          .into(database.syncMetadata)
          .insertOnConflictUpdate(
            SyncMetadataCompanion.insert(key: 'legacyImported', value: '1'),
          );
    });
  }

  Stream<void> watchChanges() => database
      .customSelect(
        '''SELECT 'stats' AS kind, CAST(id AS TEXT) AS row_id, updated_at, dirty FROM user_stats
           UNION ALL SELECT 'word', word_id, updated_at, dirty FROM word_progress
           UNION ALL SELECT 'lesson', lesson_id, updated_at, dirty FROM lesson_progress''',
        readsFrom: {
          database.userStats,
          database.wordProgress,
          database.lessonProgress,
        },
      )
      .watch()
      .map((rows) {});
}
