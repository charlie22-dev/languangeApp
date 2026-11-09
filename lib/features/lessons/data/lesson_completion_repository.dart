import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/sync_timestamp.dart';
import '../../flashcards/data/word_enrollment.dart';
import '../domain/lesson_session.dart';

final lessonCompletionRepositoryProvider = Provider<LessonCompletionRepository>(
  (ref) => LessonCompletionRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

class LessonCompletionRepository {
  LessonCompletionRepository(this.database, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase database;
  final DateTime Function() clock;

  Future<void> save(
    LessonResult result, {
    required List<String> wordIds,
  }) async {
    if (!result.success) return;
    await database.transaction(() async {
      final previous =
          await (database.select(database.lessonProgress)
                ..where((table) => table.lessonId.equals(result.lessonId)))
              .getSingleOrNull();
      await database
          .into(database.lessonProgress)
          .insertOnConflictUpdate(
            LessonProgressCompanion.insert(
              lessonId: result.lessonId,
              completed: const Value(true),
              bestScore: Value(max(previous?.bestScore ?? 0, result.score)),
              completedAt: Value(previous?.completedAt ?? clock().toUtc()),
              updatedAt: Value(
                nextSyncTimestamp(previous?.updatedAt ?? 0, clock()),
              ),
              dirty: const Value(true),
            ),
          );
      final stats = await (database.select(
        database.userStats,
      )..where((row) => row.id.equals(1))).getSingleOrNull();
      if (stats == null) throw StateError('User stats row is missing');
      final changed =
          await (database.update(
            database.userStats,
          )..where((table) => table.id.equals(1))).write(
            UserStatsCompanion.custom(
              xp: database.userStats.xp + Constant(result.xp),
              lastActiveDate: Constant(clock().toUtc()),
              updatedAt: Constant(nextSyncTimestamp(stats.updatedAt, clock())),
              dirty: const Constant(true),
            ),
          );
      if (changed != 1) throw StateError('User stats row is missing');
      await enrollWords(database, wordIds, clock());
    });
  }
}
