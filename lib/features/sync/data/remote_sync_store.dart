import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/json_reader.dart';
import '../domain/sync_record.dart';

abstract interface class RemoteSyncStore {
  Future<SyncSnapshot> exchange(
    String userId,
    SyncSnapshot local, {
    SyncCursor cursor = const SyncCursor(),
  });
}

class SupabaseSyncStore implements RemoteSyncStore {
  const SupabaseSyncStore(this.client);
  final SupabaseClient client;

  @override
  Future<SyncSnapshot> exchange(
    String userId,
    SyncSnapshot local, {
    SyncCursor cursor = const SyncCursor(),
  }) async {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('Account changed');
    }
    final acknowledged = <SyncRecord>[];
    for (final kind in SyncKind.values) {
      final rows = local.records.where((row) => row.kind == kind).toList();
      final (table, conflict) = switch (kind) {
        SyncKind.stats => ('user_stats', 'user_id'),
        SyncKind.word => ('word_progress', 'user_id,word_id'),
        SyncKind.lesson => ('lesson_progress', 'user_id,lesson_id'),
        SyncKind.profile => ('profiles', 'user_id'),
      };
      for (var start = 0; start < rows.length; start += 200) {
        if (client.auth.currentUser?.id != userId) {
          throw StateError('Account changed');
        }
        final batch = rows
            .skip(start)
            .take(200)
            .map((row) => row.toRemoteJson(userId))
            .toList();
        // The server trigger rejects stale replacements, including timestamp ties.
        final winners = await client
            .from(table)
            .upsert(batch, onConflict: conflict)
            .select();
        for (final row in winners) {
          if (row['user_id'] != userId) throw StateError('Account changed');
          acknowledged.add(SyncRecord.fromJson(kind, row));
        }
      }
    }
    if (client.auth.currentUser?.id != userId) {
      throw StateError('Account changed');
    }
    final result = await client.rpc(
      'pull_progress',
      params: {
        'p_since': cursor.isoTimestamp,
        'p_after_version': cursor.revision,
      },
    );
    if (client.auth.currentUser?.id != userId) {
      throw StateError('Account changed');
    }
    final pulled = SyncSnapshot.fromJson(
      JsonReader.object(result, 'sync'),
      userId: userId,
    );
    return SyncSnapshot([
      ...acknowledged,
      ...pulled.records,
    ], cursor: pulled.cursor);
  }
}
