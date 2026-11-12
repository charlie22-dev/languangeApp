import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/core/utils/sync_timestamp.dart';
import 'package:myapp/features/sync/data/local_sync_store.dart';
import 'package:myapp/features/sync/data/remote_sync_store.dart';
import 'package:myapp/features/sync/data/sync_service.dart';
import 'package:myapp/features/sync/domain/sync_record.dart';

SyncRecord statsRecord(int xp, int timestamp) => SyncRecord.fromJson(
  SyncKind.stats,
  {'xp': xp, 'streak': 1, 'last_active_date': null, 'updated_at': timestamp},
);

class MemoryRemoteStore implements RemoteSyncStore {
  final users = <String, Map<String, SyncRecord>>{};
  bool fail = false;
  int calls = 0;
  Completer<void>? gate;
  final started = Completer<void>();
  final cursors = <SyncCursor>[];
  @override
  Future<SyncSnapshot> exchange(
    String userId,
    SyncSnapshot local, {
    SyncCursor cursor = const SyncCursor(),
  }) async {
    cursors.add(cursor);
    calls++;
    if (!started.isCompleted) started.complete();
    await gate?.future;
    if (fail) throw StateError('Offline');
    final records = users.putIfAbsent(userId, () => {});
    for (final row in local.records) {
      final key = '${row.kind.name}/${row.id}';
      if (records[key] == null || row.updatedAt > records[key]!.updatedAt) {
        records[key] = row;
      }
    }
    final timestamp = records.values.fold(
      cursor.timestamp,
      (stamp, row) => row.updatedAt > stamp ? row.updatedAt : stamp,
    );
    return SyncSnapshot(
      records.values,
      cursor: SyncCursor(timestamp: timestamp, revision: cursor.revision + 1),
    );
  }
}

void main() {
  late AppDatabase database;
  late LocalSyncStore local;
  late MemoryRemoteStore remote;
  late SyncService service;
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    local = LocalSyncStore(database);
    remote = MemoryRemoteStore();
    service = SyncService(userId: 'A', local: local, remote: remote);
  });
  tearDown(() async {
    service.dispose();
    await database.close();
  });

  Future<void> editStats(int xp, int stamp) async {
    await database.select(database.userStats).getSingle();
    await database
        .update(database.userStats)
        .write(
          UserStatsCompanion(
            xp: Value(xp),
            updatedAt: Value(stamp),
            dirty: const Value(true),
          ),
        );
  }

  test(
    'newer remote data replaces local data and clears pending flags',
    () async {
      await editStats(10, 90);
      remote.users['A'] = {'stats/stats': statsRecord(50, 100)};
      await service.syncOnce();
      final row = await database.select(database.userStats).getSingle();
      expect(row.xp, 50);
      expect(row.updatedAt, 100);
      expect(row.dirty, isFalse);
    },
  );

  test(
    'newer local data uploads, including lower counters under LWW',
    () async {
      await editStats(20, 101);
      remote.users['A'] = {'stats/stats': statsRecord(50, 100)};
      await service.syncOnce();
      expect(remote.users['A']!['stats/stats']!.data['xp'], 20);
      expect(
        (await database.select(database.userStats).getSingle()).dirty,
        isFalse,
      );
    },
  );

  test('remote value consistently wins equal timestamps', () async {
    await editStats(10, 100);
    remote.users['A'] = {'stats/stats': statsRecord(50, 100)};
    await service.syncOnce();
    expect((await database.select(database.userStats).getSingle()).xp, 50);
  });

  test(
    'network failure preserves pending changes for a new service instance',
    () async {
      await editStats(35, 100);
      remote.fail = true;
      await service.syncOnce();
      expect(
        (await database.select(database.userStats).getSingle()).dirty,
        isTrue,
      );
      expect((await local.snapshot()).records, hasLength(1));
      service.dispose();
      remote.fail = false;
      service = SyncService(
        userId: 'A',
        local: LocalSyncStore(database),
        remote: remote,
      );
      await service.syncOnce();
      expect(remote.users['A']!['stats/stats']!.data['xp'], 35);
      expect((await local.snapshot()).records, isEmpty);
    },
  );

  test(
    'in-flight response cannot overwrite or acknowledge a newer local edit',
    () async {
      await editStats(10, 100);
      remote.gate = Completer<void>();
      final pending = service.syncOnce();
      await remote.started.future;
      await editStats(40, 101);
      remote.gate!.complete();
      await pending;
      var row = await database.select(database.userStats).getSingle();
      expect(row.xp, 40);
      expect(row.dirty, isTrue);
      await service.syncOnce();
      row = await database.select(database.userStats).getSingle();
      expect(row.dirty, isFalse);
      expect(remote.users['A']!['stats/stats']!.data['xp'], 40);
    },
  );

  test(
    'disposed account service does not apply a late network response',
    () async {
      await editStats(10, 100);
      remote.users['A'] = {'stats/stats': statsRecord(50, 200)};
      remote.gate = Completer<void>();
      final pending = service.syncOnce();
      await remote.started.future;
      service.dispose();
      remote.gate!.complete();
      await pending;
      final row = await database.select(database.userStats).getSingle();
      expect(row.xp, 10);
      expect(row.dirty, isTrue);
    },
  );

  test(
    'background merge acknowledgements do not create an endless sync loop',
    () async {
      await editStats(10, 100);
      final synced = Completer<void>();
      service = SyncService(
        userId: 'A',
        local: local,
        remote: remote,
        retryInterval: const Duration(hours: 1),
        onStatus: (status) {
          if (status == SyncStatus.idle && !synced.isCompleted) {
            synced.complete();
          }
        },
      );
      service.start();
      await synced.future.timeout(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      expect(remote.calls, inInclusiveRange(1, 2));
    },
  );

  test(
    'timestamp generator advances even when the device clock goes backwards',
    () {
      final now = DateTime.utc(2026, 11, 8);
      expect(nextSyncTimestamp(0, now), now.microsecondsSinceEpoch);
      expect(
        nextSyncTimestamp(
          now.microsecondsSinceEpoch,
          now.subtract(const Duration(days: 1)),
        ),
        now.microsecondsSinceEpoch + 1,
      );
      expect(remoteWins(100, 100), isTrue);
      expect(remoteWins(101, 100), isFalse);
    },
  );

  test('payload parser rejects wrong owners, versions and malformed dates', () {
    final valid = {
      'schema_version': 2,
      'user_id': 'A',
      'last_synced_at': DateTime.fromMicrosecondsSinceEpoch(
        100,
        isUtc: true,
      ).toIso8601String(),
      'revision': 1,
      'stats': statsRecord(1, 100).toRemoteJson('A'),
      'words': [],
      'lessons': [],
    };
    expect(
      () => SyncSnapshot.fromJson({...valid, 'user_id': 'B'}, userId: 'A'),
      throwsFormatException,
    );
    expect(
      () => SyncSnapshot.fromJson({...valid, 'schema_version': 3}, userId: 'A'),
      throwsFormatException,
    );
    expect(
      () => SyncRecord.fromJson(SyncKind.word, {
        'word_id': 'w',
        'updated_at': 0,
        'ease_factor': 2.5,
        'repetitions': 0,
        'interval_days': 0,
        'due_date': 'invalid',
      }),
      throwsFormatException,
    );
  });

  test(
    'cursor survives service restart and advances only after successful merge',
    () async {
      await editStats(35, 100);
      await service.syncOnce();
      expect((await local.readCursor()).timestamp, 100);
      expect((await local.readCursor()).revision, 1);
      service.dispose();
      service = SyncService(
        userId: 'A',
        local: LocalSyncStore(database),
        remote: remote,
      );
      remote.fail = true;
      await service.syncOnce();
      expect(remote.cursors.last.timestamp, 100);
      expect((await local.readCursor()).revision, 1);
      remote.fail = false;
      await service.syncOnce();
      expect((await local.readCursor()).revision, 2);
    },
  );

  test('profile caches timestamp strings locally for offline use', () async {
    final now = DateTime.utc(2026, 11, 12, 8, 1, 2, 3, 456);
    await local.merge(
      SyncSnapshot([
        SyncRecord.fromJson(SyncKind.profile, {
          'display_name': 'Learner',
          'updated_at': now.toIso8601String(),
        }),
      ]),
    );
    final row = await database.select(database.localProfiles).getSingle();
    expect(row.displayName, 'Learner');
    expect(row.updatedAt, now.microsecondsSinceEpoch);
    expect(row.dirty, isFalse);
    expect(
      (await local.snapshot()).records,
      isNot(
        contains(
          isA<SyncRecord>().having((row) => row.kind, 'kind', SyncKind.profile),
        ),
      ),
    );
  });

  test('merge rollback also rolls back cursor and earlier rows', () async {
    await local.merge(
      SyncSnapshot([], cursor: const SyncCursor(timestamp: 100, revision: 1)),
      saveCursor: true,
    );
    await database.customStatement(
      '''CREATE TRIGGER reject_profile BEFORE INSERT ON local_profiles
      BEGIN SELECT RAISE(ABORT, 'test failure'); END''',
    );
    await expectLater(
      local.merge(
        SyncSnapshot([
          statsRecord(90, 200),
          SyncRecord.fromJson(SyncKind.profile, {
            'display_name': 'Learner',
            'updated_at': 200,
          }),
        ], cursor: const SyncCursor(timestamp: 200, revision: 2)),
        saveCursor: true,
      ),
      throwsA(anything),
    );
    expect((await database.select(database.userStats).getSingle()).xp, 0);
    expect((await local.readCursor()).timestamp, 100);
    expect((await local.readCursor()).revision, 1);
  });
}
