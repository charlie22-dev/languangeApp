import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/json_reader.dart';
import '../domain/sync_record.dart';

abstract interface class RemoteSyncStore {
  Future<SyncSnapshot> exchange(String userId, SyncSnapshot local);
}

class SupabaseSyncStore implements RemoteSyncStore {
  const SupabaseSyncStore(this.client);
  final SupabaseClient client;

  @override
  Future<SyncSnapshot> exchange(String userId, SyncSnapshot local) async {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('Account changed');
    }
    final result = await client.rpc(
      'sync_progress',
      params: {'p_user_id': userId, ...local.payload},
    );
    if (client.auth.currentUser?.id != userId) {
      throw StateError('Account changed');
    }
    return SyncSnapshot.fromJson(
      JsonReader.object(result, 'sync'),
      userId: userId,
    );
  }
}
