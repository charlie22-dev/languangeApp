import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/sync_timestamp.dart';
import '../../flashcards/data/word_enrollment.dart';
import '../../activity/data/activity_repository.dart';
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
    final now = clock();
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
              completedAt: Value(previous?.completedAt ?? now.toUtc()),
              updatedAt: Value(
                nextSyncTimestamp(previous?.updatedAt ?? 0, now),
              ),
              dirty: const Value(true),
            ),
          );
      await ActivityRepository(database).award(result.xp, now);
      await enrollWords(database, wordIds, now);
    });
  }
}
