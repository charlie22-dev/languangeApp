import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/sync_timestamp.dart';
import '../domain/streak.dart';

final activityRepositoryProvider = Provider(
  (ref) => ActivityRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

class ActivityRepository {
  ActivityRepository(this.database, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase database;
  final DateTime Function() clock;

  /// Called in the lesson transaction, so history and total XP cannot diverge.
  Future<void> award(int xp, DateTime instant) => database.transaction(
    () async {
      final stats = await database.select(database.userStats).getSingle();
      final now = instant.toLocal();
      final previous = stats.lastActiveDate?.toLocal();
      final change = Streak.evaluate(lastActiveDate: previous, today: now);
      final streak = Streak.next(stats.streak, change);
      final active = previous != null && previous.isAfter(now) ? previous : now;
      await database
          .update(database.userStats)
          .write(
            UserStatsCompanion(
              xp: Value(stats.xp + xp),
              streak: Value(streak),
              longestStreak: Value(
                max(stats.longestStreak, max(stats.streak, streak)),
              ),
              lastActiveDate: Value(active.toUtc()),
              updatedAt: Value(nextSyncTimestamp(stats.updatedAt, instant)),
              dirty: const Value(true),
            ),
          );
      final key = dayKey(now);
      final row = await (database.select(
        database.dailyActivities,
      )..where((r) => r.activityDate.equals(key))).getSingleOrNull();
      await database
          .into(database.dailyActivities)
          .insertOnConflictUpdate(
            DailyActivitiesCompanion.insert(
              activityDate: key,
              xp: Value((row?.xp ?? 0) + xp),
              updatedAt: Value(nextSyncTimestamp(row?.updatedAt ?? 0, instant)),
            ),
          );
    },
  );

  /// Keep tombstones and import/cursor metadata, so stale sync responses cannot
  /// resurrect reset rows. Profile, preferences and the account are preserved.
  Future<void> reset() => database.transaction(() async {
    final stampRow = await database.customSelect(
      '''SELECT MAX(updated_at) AS stamp FROM (
      SELECT updated_at FROM user_stats UNION ALL SELECT updated_at FROM word_progress
      UNION ALL SELECT updated_at FROM lesson_progress UNION ALL SELECT updated_at FROM daily_activities)''',
    ).getSingle();
    final stamp = nextSyncTimestamp(
      stampRow.readNullable<int>('stamp') ?? 0,
      clock(),
    );
    await database
        .update(database.userStats)
        .write(
          UserStatsCompanion(
            xp: const Value(0),
            streak: const Value(0),
            longestStreak: const Value(0),
            lastActiveDate: const Value(null),
            updatedAt: Value(stamp),
            dirty: const Value(true),
          ),
        );
    await database
        .update(database.lessonProgress)
        .write(
          LessonProgressCompanion(
            completed: const Value(false),
            bestScore: const Value(0),
            completedAt: const Value(null),
            updatedAt: Value(stamp),
            dirty: const Value(true),
          ),
        );
    await database
        .update(database.wordProgress)
        .write(
          WordProgressCompanion(
            deleted: const Value(true),
            updatedAt: Value(stamp),
            dirty: const Value(true),
          ),
        );
    await database
        .update(database.dailyActivities)
        .write(
          DailyActivitiesCompanion(
            xp: const Value(0),
            updatedAt: Value(stamp),
            dirty: const Value(true),
          ),
        );
  });
}
