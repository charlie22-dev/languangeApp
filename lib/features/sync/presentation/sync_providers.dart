import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/database/app_database.dart';
import '../../auth/data/auth_repository.dart';
import '../data/local_sync_store.dart';
import '../data/remote_sync_store.dart';
import '../data/sync_service.dart';

final accountReadyProvider = FutureProvider<void>((ref) async {
  final uid = ref.watch(
    authStateProvider.select((value) => value.asData?.value?.id),
  );
  if (uid == null) return;
  final database = ref.watch(appDatabaseProvider);
  final legacy = AppDatabase();
  try {
    await LocalSyncStore(database).importLegacy(legacy, uid);
  } finally {
    await legacy.close();
  }
}, retry: (count, error) => null);

final syncStatusProvider = NotifierProvider<SyncStatusController, SyncStatus>(
  SyncStatusController.new,
);

class SyncStatusController extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => SyncStatus.idle;
  void update(SyncStatus value) => state = value;
}

final syncServiceProvider = Provider<SyncService?>((ref) {
  final uid = ref.watch(
    authStateProvider.select((value) => value.asData?.value?.id),
  );
  final ready = ref.watch(accountReadyProvider);
  if (uid == null || !ready.hasValue || ready.hasError || ready.isLoading) {
    return null;
  }
  final client = ref.watch(supabaseClientProvider).asData?.value;
  if (client == null) return null;
  final service = SyncService(
    userId: uid,
    local: LocalSyncStore(ref.watch(appDatabaseProvider)),
    remote: SupabaseSyncStore(client),
    onStatus: (status) {
      if (ref.mounted) ref.read(syncStatusProvider.notifier).update(status);
    },
  );
  ref.onDispose(service.dispose);
  service.start();
  return service;
});
