import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/sync_timestamp.dart';

/// The caller owns the transaction. Existing schedules are never overwritten.
Future<void> enrollWords(
  AppDatabase database,
  Iterable<String> wordIds,
  DateTime now,
) async {
  final ids = wordIds.toSet();
  if (ids.isEmpty) return;
  for (final row in await (database.select(
    database.wordProgress,
  )..where((r) => r.deleted.equals(true) & r.wordId.isIn(ids))).get()) {
    await (database.update(
      database.wordProgress,
    )..where((r) => r.wordId.equals(row.wordId))).write(
      WordProgressCompanion(
        deleted: const Value(false),
        easeFactor: const Value(2.5),
        intervalDays: const Value(0),
        repetitions: const Value(0),
        dueDate: Value(now.toUtc()),
        updatedAt: Value(nextSyncTimestamp(row.updatedAt, now)),
        dirty: const Value(true),
      ),
    );
  }
  await database.batch(
    (batch) => batch.insertAll(database.wordProgress, [
      for (final id in ids)
        WordProgressCompanion.insert(
          wordId: id,
          dueDate: now.toUtc(),
          updatedAt: Value(now.toUtc().microsecondsSinceEpoch),
        ),
    ], mode: InsertMode.insertOrIgnore),
  );
}
