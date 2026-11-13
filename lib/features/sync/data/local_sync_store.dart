import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/sync_record.dart';

class LocalSyncStore {
  const LocalSyncStore(this.database);
  final AppDatabase database;

  Future<SyncCursor> readCursor() async {
    final row = await (database.select(
      database.syncMetadata,
    )..where((row) => row.key.equals('cursorV2'))).getSingleOrNull();
    if (row == null) return const SyncCursor();
    final value = jsonDecode(row.value) as Map<String, dynamic>;
    return SyncCursor(
      timestamp: value['timestamp'] as int,
      revision: value['revision'] as int,
    );
  }

  Future<SyncSnapshot> snapshot({bool dirtyOnly = true}) =>
      database.transaction(() async {
        final vocabularyQuery = database.select(database.savedVocabulary);
        final statsQuery = database.select(database.userStats);
        final wordsQuery = database.select(database.wordProgress);
        final lessonsQuery = database.select(database.lessonProgress);
        final activitiesQuery = database.select(database.dailyActivities);
        final profilesQuery = database.select(database.localProfiles);
        if (dirtyOnly) {
          vocabularyQuery.where((row) => row.dirty.equals(true));
          activitiesQuery.where((row) => row.dirty.equals(true));
          statsQuery.where((row) => row.dirty.equals(true));
          wordsQuery.where((row) => row.dirty.equals(true));
          lessonsQuery.where((row) => row.dirty.equals(true));
          profilesQuery.where((row) => row.dirty.equals(true));
        }
        final vocabulary = await vocabularyQuery.get();
        final activities = await activitiesQuery.get();
        final stats = await statsQuery.get();
        final words = await wordsQuery.get();
        final lessons = await lessonsQuery.get();
        final profiles = await profilesQuery.get();
        return SyncSnapshot([
          for (final row in vocabulary)
            SyncRecord.fromJson(SyncKind.vocabulary, {
              'word_id': row.wordId,
              'course_id': row.courseId,
              'text': row.wordText,
              'translation': row.translation,
              'example': row.example,
              'example_translation': row.exampleTranslation,
              'deleted': row.deleted,
              'updated_at': row.updatedAt,
            }),
          for (final row in activities)
            SyncRecord.fromJson(SyncKind.activity, {
              'activity_date': row.activityDate,
              'xp': row.xp,
              'updated_at': row.updatedAt,
            }),
          for (final row in profiles)
            SyncRecord.fromJson(SyncKind.profile, {
              'display_name': row.displayName,
              'updated_at': row.updatedAt,
            }),
          for (final row in stats)
            SyncRecord.fromJson(SyncKind.stats, {
              'xp': row.xp,
              'streak': row.streak,
              'longest_streak': row.longestStreak,
              'last_active_date': row.lastActiveDate?.toUtc().toIso8601String(),
              'updated_at': row.updatedAt,
            }),
          for (final row in words)
            SyncRecord.fromJson(SyncKind.word, {
              'word_id': row.wordId,
              'deleted': row.deleted,
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
    bool saveCursor = false,
  }) => database.transaction(() async {
    for (final row in remote.records) {
      final data = row.data;
      DateTime? date(String key) => data[key] == null
          ? null
          : DateTime.parse(data[key] as String).toUtc();
      switch (row.kind) {
        case SyncKind.vocabulary:
          final current = await (database.select(
            database.savedVocabulary,
          )..where((r) => r.wordId.equals(row.id))).getSingleOrNull();
          if (!remoteWins(current?.updatedAt, row.updatedAt)) continue;
          if (current != null &&
              current.updatedAt == row.updatedAt &&
              current.dirty == imported &&
              current.deleted == data['deleted'] &&
              current.wordText == data['text'] &&
              current.translation == data['translation'] &&
              current.example == data['example'] &&
              current.exampleTranslation == data['example_translation'] &&
              current.courseId == data['course_id']) {
            continue;
          }
          await database
              .into(database.savedVocabulary)
              .insertOnConflictUpdate(
                SavedVocabularyCompanion.insert(
                  wordId: row.id,
                  courseId: data['course_id'] as String,
                  wordText: data['text'] as String,
                  translation: data['translation'] as String,
                  example: data['example'] as String,
                  exampleTranslation: data['example_translation'] as String,
                  deleted: Value(data['deleted'] as bool),
                  updatedAt: Value(row.updatedAt),
                  dirty: Value(imported),
                ),
              );
        case SyncKind.activity:
          final current = await (database.select(
            database.dailyActivities,
          )..where((r) => r.activityDate.equals(row.id))).getSingleOrNull();
          if (!remoteWins(current?.updatedAt, row.updatedAt)) continue;
          if (current != null &&
              current.updatedAt == row.updatedAt &&
              current.dirty == imported &&
              current.xp == data['xp']) {
            continue;
          }
          await database
              .into(database.dailyActivities)
              .insertOnConflictUpdate(
                DailyActivitiesCompanion.insert(
                  activityDate: row.id,
                  xp: Value(data['xp'] as int),
                  updatedAt: Value(row.updatedAt),
                  dirty: Value(imported),
                ),
              );
        case SyncKind.profile:
          final current = await database
              .select(database.localProfiles)
              .getSingleOrNull();
          if (!remoteWins(current?.updatedAt, row.updatedAt)) continue;
          if (current != null &&
              current.updatedAt == row.updatedAt &&
              current.dirty == imported &&
              current.displayName == data['display_name']) {
            continue;
          }
          await database
              .into(database.localProfiles)
              .insertOnConflictUpdate(
                LocalProfilesCompanion.insert(
                  id: const Value(1),
                  displayName: data['display_name'] as String,
                  updatedAt: row.updatedAt,
                  dirty: Value(imported),
                ),
              );
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
              current.longestStreak == data['longest_streak'] &&
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
                  longestStreak: Value(data['longest_streak'] as int),
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
              current.deleted == data['deleted'] &&
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
                  deleted: Value(data['deleted'] as bool),
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
    if (saveCursor) {
      await database
          .into(database.syncMetadata)
          .insertOnConflictUpdate(
            SyncMetadataCompanion.insert(
              key: 'cursorV2',
              value: jsonEncode({
                'timestamp': remote.cursor.timestamp,
                'revision': remote.cursor.revision,
              }),
            ),
          );
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
          SyncSnapshot(
            (await LocalSyncStore(
              legacy,
            ).snapshot(dirtyOnly: false)).records.map(
              (row) => row.updatedAt == 0
                  ? SyncRecord.fromJson(row.kind, {
                      ...row.toJson(),
                      // Untimestamped legacy data is newer than empty signup
                      // defaults, but older than actual timestamped cloud edits.
                      'updated_at': 1,
                    })
                  : row,
            ),
          ),
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
           UNION ALL SELECT 'lesson', lesson_id, updated_at, dirty FROM lesson_progress
           UNION ALL SELECT 'activity', activity_date, updated_at, dirty FROM daily_activities
           UNION ALL SELECT 'vocabulary', word_id, updated_at, dirty FROM saved_vocabulary
           UNION ALL SELECT 'profile', CAST(id AS TEXT), updated_at, dirty FROM local_profiles''',
        readsFrom: {
          database.userStats,
          database.wordProgress,
          database.lessonProgress,
          database.localProfiles,
          database.dailyActivities,
          database.savedVocabulary,
        },
      )
      .watch()
      .map((rows) {});
}
