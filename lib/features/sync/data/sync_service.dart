import 'dart:async';

import 'local_sync_store.dart';
import 'remote_sync_store.dart';

enum SyncStatus { idle, syncing, offline }

class SyncService {
  SyncService({
    required this.userId,
    required this.local,
    required this.remote,
    this.onStatus,
    this.retryInterval = const Duration(seconds: 30),
  });
  final String userId;
  final LocalSyncStore local;
  final RemoteSyncStore remote;
  final void Function(SyncStatus)? onStatus;
  final Duration retryInterval;
  StreamSubscription<void>? _changes;
  Timer? _retry;
  Timer? _debounce;
  bool _disposed = false;
  bool _running = false;
  bool _pending = false;

  void start() {
    if (_changes != null || _disposed) return;
    _changes = local.watchChanges().listen(
      (_) => request(),
      onError: (Object error) => onStatus?.call(SyncStatus.offline),
    );
    _retry = Timer.periodic(retryInterval, (_) => request());
    request();
  }

  void request() {
    if (_disposed) return;
    if (_running) {
      _pending = true;
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(syncOnce()),
    );
  }

  Future<void> syncOnce() async {
    if (_disposed || _running) return;
    _running = true;
    _pending = false;
    onStatus?.call(SyncStatus.syncing);
    try {
      final changes = await local.snapshot();
      final cursor = await local.readCursor();
      if (_disposed) return;
      final merged = await remote
          .exchange(userId, changes, cursor: cursor)
          .timeout(const Duration(seconds: 15));
      if (_disposed) return;
      if (merged.cursor.timestamp < cursor.timestamp ||
          merged.cursor.revision < cursor.revision) {
        throw StateError('Sync cursor moved backwards');
      }
      await local.merge(merged, saveCursor: true);
      if (!_disposed) onStatus?.call(SyncStatus.idle);
    } catch (_) {
      // Dirty rows stay on disk. Gameplay never waits for the network.
      if (!_disposed) onStatus?.call(SyncStatus.offline);
    } finally {
      _running = false;
      if (_pending && !_disposed) request();
    }
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _debounce?.cancel();
    unawaited(_changes?.cancel());
  }
}
