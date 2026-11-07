import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// The caller owns the transaction. Existing schedules are never overwritten.
Future<void> enrollWords(
  AppDatabase database,
  Iterable<String> wordIds,
  DateTime now,
) async {
  final ids = wordIds.toSet();
  if (ids.isEmpty) return;
  await database.batch(
    (batch) => batch.insertAll(database.wordProgress, [
      for (final id in ids)
        WordProgressCompanion.insert(wordId: id, dueDate: now.toUtc()),
    ], mode: InsertMode.insertOrIgnore),
  );
}
