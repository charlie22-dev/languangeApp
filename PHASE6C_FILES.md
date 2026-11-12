# Phase 6C: changed files and source

Implementation is complete locally. Run the Phase 6C SQL script and configure providers in your dashboard before live account/sync verification.

Verification: 131 Flutter tests, 14 Phase 6C SQL checks, 11 historical Phase 6A SQL checks, clean static analysis/formatting, and a successful Android x86-64 debug APK build.

The earlier emulator run reached Login and verified empty-field errors; live login, OAuth, confirmation/recovery, and two-account sync remain manual checks after dashboard setup.

## Files created or edited

| File | Status |
| --- | --- |
| [README.md](README.md) | Edited |
| [SUPABASE_SETUP.md](SUPABASE_SETUP.md) | Edited |
| [android/gradle.properties](android/gradle.properties) | Edited |
| [lib/core/config/supabase_config.dart](lib/core/config/supabase_config.dart) | Edited |
| [lib/core/database/app_database.dart](lib/core/database/app_database.dart) | Edited |
| [lib/core/database/app_database.g.dart](lib/core/database/app_database.g.dart) | Edited |
| [lib/features/auth/data/auth_repository.dart](lib/features/auth/data/auth_repository.dart) | Edited |
| [lib/features/sync/data/local_sync_store.dart](lib/features/sync/data/local_sync_store.dart) | Edited |
| [lib/features/sync/data/remote_sync_store.dart](lib/features/sync/data/remote_sync_store.dart) | Edited |
| [lib/features/sync/data/sync_service.dart](lib/features/sync/data/sync_service.dart) | Edited |
| [lib/features/sync/domain/sync_record.dart](lib/features/sync/domain/sync_record.dart) | Edited |
| [lib/main.dart](lib/main.dart) | Edited |
| [supabase/migrations/202611120001_phase6c.sql](supabase/migrations/202611120001_phase6c.sql) | Created |
| [supabase/tests/phase6c_security.mjs](supabase/tests/phase6c_security.mjs) | Created |
| [test/account_database_test.dart](test/account_database_test.dart) | Edited |
| [test/auth_repository_test.dart](test/auth_repository_test.dart) | Edited |
| [test/auth_validation_test.dart](test/auth_validation_test.dart) | Edited |
| [test/auth_widget_test.dart](test/auth_widget_test.dart) | Edited |
| [test/remote_sync_store_test.dart](test/remote_sync_store_test.dart) | Created |
| [test/sync_service_test.dart](test/sync_service_test.dart) | Edited |
| PHASE6C_FILES.md | Created (this manifest) |

The Gradle memory settings and configuration-independent validation test were already modified by the preceding Android verification task.

config.local.json remains ignored and untracked. Its contents are intentionally excluded.

## Existing auth and lifecycle implementation

- [lib/features/auth/presentation/auth_screens.dart](lib/features/auth/presentation/auth_screens.dart)
- [lib/features/auth/presentation/auth_controller.dart](lib/features/auth/presentation/auth_controller.dart)
- [lib/features/auth/presentation/account_controller.dart](lib/features/auth/presentation/account_controller.dart)
- [lib/core/router/app_router.dart](lib/core/router/app_router.dart)
- [lib/features/profile/presentation/profile_screen.dart](lib/features/profile/presentation/profile_screen.dart)
- [lib/features/sync/presentation/sync_providers.dart](lib/features/sync/presentation/sync_providers.dart)
- [lib/app/app.dart](lib/app/app.dart)
- [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml)

## Run and test

```powershell
cd C:\Langunge_flutter\myapp
flutter pub get
flutter test --dart-define-from-file=config.local.json
flutter analyze
node.exe supabase/tests/phase6c_security.mjs
flutter build apk --debug --target-platform android-x64 --dart-define-from-file=config.local.json
flutter emulators --launch Medium_Phone_API_37.0
flutter devices
flutter run -d emulator-5554 --dart-define-from-file=config.local.json
```

Use your actual emulator ID. Regenerate Drift after table changes with `dart run build_runner build`.

Read [SUPABASE_SETUP.md](SUPABASE_SETUP.md) for the SQL Editor script, Google/email settings, callback allowlist, RLS test and offline behavior.

## Updated source

Generated app_database.g.dart is linked above; regenerate it with build_runner. Documentation files are linked above.

### android/gradle.properties

```properties
org.gradle.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError
org.gradle.workers.max=2
android.useAndroidX=true
# This newDsl flag was added by the Flutter template
android.newDsl=false
# This builtInKotlin flag was added by the Flutter template
android.builtInKotlin=false
```

### lib/core/config/supabase_config.dart

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseConfig {
  const SupabaseConfig({
    this.url = const String.fromEnvironment('SUPABASE_URL'),
    this.publishableKey = const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
    ),
    this.authRedirect = const String.fromEnvironment(
      'AUTH_REDIRECT_URL',
      defaultValue: 'io.languagelearning.app://auth-callback',
    ),
  });
  final String url;
  final String publishableKey;
  final String authRedirect;
  bool get isConfigured {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        !{'https', 'http'}.contains(uri.scheme)) {
      return false;
    }
    if (publishableKey.startsWith('sb_publishable_')) return true;
    // Legacy anon JWTs are also public client keys; service-role keys are rejected.
    try {
      final parts = publishableKey.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map && payload['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }
}

final supabaseConfigProvider = Provider<SupabaseConfig>(
  (ref) => const SupabaseConfig(),
);

final supabaseClientProvider = FutureProvider<SupabaseClient>((ref) async {
  final config = ref.watch(supabaseConfigProvider);
  if (!config.isConfigured) {
    throw StateError('Supabase configuration is missing');
  }
  final instance = await Supabase.initialize(
    url: config.url,
    publishableKey: config.publishableKey,
    debug: false,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  return instance.client;
}, retry: (count, error) => null);
```

### lib/core/database/app_database.dart

```dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';

part 'app_database.g.dart';

@DataClassName('LessonProgressRow')
class LessonProgress extends Table {
  TextColumn get lessonId => text()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  IntColumn get bestScore => integer().withDefault(const Constant(0))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {lessonId};

  @override
  List<String> get customConstraints => [
    'CHECK (best_score BETWEEN 0 AND 100)',
  ];
}

@DataClassName('WordProgressRow')
class WordProgress extends Table {
  TextColumn get wordId => text()();
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  DateTimeColumn get dueDate => dateTime()();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {wordId};

  @override
  List<String> get customConstraints => [
    'CHECK (ease_factor >= 1.3)',
    'CHECK (interval_days >= 0)',
    'CHECK (repetitions >= 0)',
  ];
}

@DataClassName('UserStatsRow')
class UserStats extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get xp => integer().withDefault(const Constant(0))();
  IntColumn get streak => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastActiveDate => dateTime().nullable()();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (id = 1)',
    'CHECK (xp >= 0)',
    'CHECK (streak >= 0)',
  ];
}

class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('LocalProfileRow')
class LocalProfiles extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get displayName => text()();
  IntColumn get updatedAt => integer()();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}

@DriftDatabase(
  tables: [
    LessonProgress,
    WordProgress,
    UserStats,
    SyncMetadata,
    LocalProfiles,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({String? userId})
    : super(driftDatabase(name: databaseName(userId)));

  static String databaseName(String? userId) => userId == null
      ? 'language_learning'
      : 'language_learning_${base64Url.encode(utf8.encode(userId)).replaceAll('=', '')}';

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await into(userStats).insert(UserStatsCompanion.insert());
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(lessonProgress, lessonProgress.updatedAt);
        await migrator.addColumn(lessonProgress, lessonProgress.dirty);
        await migrator.addColumn(wordProgress, wordProgress.updatedAt);
        await migrator.addColumn(wordProgress, wordProgress.dirty);
        await migrator.addColumn(userStats, userStats.updatedAt);
        await migrator.addColumn(userStats, userStats.dirty);
        await migrator.createTable(syncMetadata);
      }
      if (from < 3) {
        await migrator.createTable(localProfiles);
      }
    },
  );
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final uid = ref.watch(
    authStateProvider.select((value) => value.asData?.value?.id),
  );
  final database = AppDatabase(userId: uid);
  ref.onDispose(database.close);
  return database;
});
```

### lib/features/auth/data/auth_repository.dart

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../domain/auth_models.dart';

abstract interface class AuthRepository {
  Stream<AuthIdentity?> watchIdentity();
  Future<void> signIn(String email, String password);
  Future<bool> register(String email, String password);
  Future<void> resetPassword(String email);
  Future<void> updatePassword(String password);
  Future<void> signInGoogle();
  Future<void> signOut();
}

final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  final config = ref.watch(supabaseConfigProvider);
  final client = await ref.watch(supabaseClientProvider.future);
  return SupabaseAuthRepository(client, redirectTo: config.authRedirect);
}, retry: (count, error) => null);

final authStateProvider = StreamProvider<AuthIdentity?>((ref) async* {
  final repository = await ref.watch(authRepositoryProvider.future);
  yield* repository.watchIdentity();
}, retry: (count, error) => null);

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this.client, {required this.redirectTo});
  final SupabaseClient client;
  final String redirectTo;
  bool _recovering = false;

  AuthIdentity? _identity(Session? session) => session == null
      ? null
      : AuthIdentity(
          id: session.user.id,
          email: session.user.email ?? '',
          needsPasswordReset: _recovering,
        );

  @override
  Stream<AuthIdentity?> watchIdentity() =>
      client.auth.onAuthStateChange.transform(
        StreamTransformer.fromHandlers(
          handleData: (event, sink) {
            if (event.event == AuthChangeEvent.passwordRecovery) {
              _recovering = true;
            }
            if (event.event == AuthChangeEvent.signedOut ||
                event.event == AuthChangeEvent.userUpdated) {
              _recovering = false;
            }
            sink.add(_identity(event.session));
          },
          handleError: (Object error, StackTrace stack, sink) {
            // Network refresh failures must not lock a cached account out of local lessons.
            final cached = client.auth.currentSession;
            if (cached != null) {
              sink.add(_identity(cached));
            } else {
              // An expired/revoked session returns to Login without an unhandled stream error.
              sink.add(null);
            }
          },
        ),
      );

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthFailure {
      rethrow;
    } on AuthException catch (error) {
      throw AuthFailure(authMessageForCode(error.code));
    } catch (_) {
      throw AuthFailure(authMessageForCode('network'));
    }
  }

  @override
  Future<void> signIn(String email, String password) => _guard(() async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  });
  @override
  Future<bool> register(String email, String password) => _guard(() async {
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: redirectTo,
    );
    return response.session != null;
  });
  @override
  Future<void> resetPassword(String email) => _guard(
    () =>
        client.auth.resetPasswordForEmail(email.trim(), redirectTo: redirectTo),
  );
  @override
  Future<void> updatePassword(String password) => _guard(() async {
    await client.auth.updateUser(UserAttributes(password: password));
  });
  @override
  Future<void> signInGoogle() => _guard(() async {
    final launched = await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
    if (!launched) {
      throw const AuthFailure('The sign-in browser could not be opened.');
    }
  });
  @override
  Future<void> signOut() async {
    try {
      await client.auth
          .signOut(scope: SignOutScope.local)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      if (client.auth.currentSession != null) rethrow;
    }
  }
}
```

### lib/features/sync/data/local_sync_store.dart

```dart
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/sync_record.dart';

class LocalSyncStore {
  const LocalSyncStore(this.database);
  final AppDatabase database;

  Future<SyncCursor> readCursor() async {
    final row = await (database.select(
      database.syncMetadata,
    )..where((row) => row.key.equals('cursorV2'))).getSingleOrNull();
    if (row == null) return const SyncCursor();
    final value = jsonDecode(row.value) as Map<String, dynamic>;
    return SyncCursor(
      timestamp: value['timestamp'] as int,
      revision: value['revision'] as int,
    );
  }

  Future<SyncSnapshot> snapshot({bool dirtyOnly = true}) =>
      database.transaction(() async {
        final statsQuery = database.select(database.userStats);
        final wordsQuery = database.select(database.wordProgress);
        final lessonsQuery = database.select(database.lessonProgress);
        final profilesQuery = database.select(database.localProfiles);
        if (dirtyOnly) {
          statsQuery.where((row) => row.dirty.equals(true));
          wordsQuery.where((row) => row.dirty.equals(true));
          lessonsQuery.where((row) => row.dirty.equals(true));
          profilesQuery.where((row) => row.dirty.equals(true));
        }
        final stats = await statsQuery.get();
        final words = await wordsQuery.get();
        final lessons = await lessonsQuery.get();
        final profiles = await profilesQuery.get();
        return SyncSnapshot([
          for (final row in profiles)
            SyncRecord.fromJson(SyncKind.profile, {
              'display_name': row.displayName,
              'updated_at': row.updatedAt,
            }),
          for (final row in stats)
            SyncRecord.fromJson(SyncKind.stats, {
              'xp': row.xp,
              'streak': row.streak,
              'last_active_date': row.lastActiveDate?.toUtc().toIso8601String(),
              'updated_at': row.updatedAt,
            }),
          for (final row in words)
            SyncRecord.fromJson(SyncKind.word, {
              'word_id': row.wordId,
              'ease_factor': row.easeFactor,
              'interval_days': row.intervalDays,
              'repetitions': row.repetitions,
              'due_date': row.dueDate.toUtc().toIso8601String(),
              'updated_at': row.updatedAt,
            }),
          for (final row in lessons)
            SyncRecord.fromJson(SyncKind.lesson, {
              'lesson_id': row.lessonId,
              'completed': row.completed,
              'best_score': row.bestScore,
              'completed_at': row.completedAt?.toUtc().toIso8601String(),
              'updated_at': row.updatedAt,
            }),
        ]);
      });

  Future<void> merge(
    SyncSnapshot remote, {
    bool imported = false,
    bool saveCursor = false,
  }) => database.transaction(() async {
    for (final row in remote.records) {
      final data = row.data;
      DateTime? date(String key) => data[key] == null
          ? null
          : DateTime.parse(data[key] as String).toUtc();
      switch (row.kind) {
        case SyncKind.profile:
          final current = await database
              .select(database.localProfiles)
              .getSingleOrNull();
          if (!remoteWins(current?.updatedAt, row.updatedAt)) continue;
          if (current != null &&
              current.updatedAt == row.updatedAt &&
              current.dirty == imported &&
              current.displayName == data['display_name']) {
            continue;
          }
          await database
              .into(database.localProfiles)
              .insertOnConflictUpdate(
                LocalProfilesCompanion.insert(
                  id: const Value(1),
                  displayName: data['display_name'] as String,
                  updatedAt: row.updatedAt,
                  dirty: Value(imported),
                ),
              );
        case SyncKind.stats:
          final current = await database
              .select(database.userStats)
              .getSingleOrNull();
          if (!remoteWins(current?.updatedAt, row.updatedAt)) continue;
          if (current != null &&
              current.updatedAt == row.updatedAt &&
              current.dirty == imported &&
              current.xp == data['xp'] &&
              current.streak == data['streak'] &&
              current.lastActiveDate?.toUtc() == date('last_active_date')) {
            continue;
          }
          await database
              .into(database.userStats)
              .insertOnConflictUpdate(
                UserStatsCompanion.insert(
                  id: const Value(1),
                  xp: Value(data['xp'] as int),
                  streak: Value(data['streak'] as int),
                  lastActiveDate: Value(date('last_active_date')),
                  updatedAt: Value(row.updatedAt),
                  dirty: Value(imported),
                ),
              );
        case SyncKind.word:
          final current = await (database.select(
            database.wordProgress,
          )..where((table) => table.wordId.equals(row.id))).getSingleOrNull();
          if (!remoteWins(current?.updatedAt, row.updatedAt)) continue;
          if (current != null &&
              current.updatedAt == row.updatedAt &&
              current.dirty == imported &&
              current.easeFactor == data['ease_factor'] &&
              current.intervalDays == data['interval_days'] &&
              current.repetitions == data['repetitions'] &&
              current.dueDate.toUtc() == date('due_date')) {
            continue;
          }
          await database
              .into(database.wordProgress)
              .insertOnConflictUpdate(
                WordProgressCompanion.insert(
                  wordId: row.id,
                  easeFactor: Value(data['ease_factor'] as double),
                  intervalDays: Value(data['interval_days'] as int),
                  repetitions: Value(data['repetitions'] as int),
                  dueDate: date('due_date')!,
                  updatedAt: Value(row.updatedAt),
                  dirty: Value(imported),
                ),
              );
        case SyncKind.lesson:
          final current = await (database.select(
            database.lessonProgress,
          )..where((table) => table.lessonId.equals(row.id))).getSingleOrNull();
          if (!remoteWins(current?.updatedAt, row.updatedAt)) continue;
          if (current != null &&
              current.updatedAt == row.updatedAt &&
              current.dirty == imported &&
              current.completed == data['completed'] &&
              current.bestScore == data['best_score'] &&
              current.completedAt?.toUtc() == date('completed_at')) {
            continue;
          }
          await database
              .into(database.lessonProgress)
              .insertOnConflictUpdate(
                LessonProgressCompanion.insert(
                  lessonId: row.id,
                  completed: Value(data['completed'] as bool),
                  bestScore: Value(data['best_score'] as int),
                  completedAt: Value(date('completed_at')),
                  updatedAt: Value(row.updatedAt),
                  dirty: Value(imported),
                ),
              );
      }
    }
    if (saveCursor) {
      await database
          .into(database.syncMetadata)
          .insertOnConflictUpdate(
            SyncMetadataCompanion.insert(
              key: 'cursorV2',
              value: jsonEncode({
                'timestamp': remote.cursor.timestamp,
                'revision': remote.cursor.revision,
              }),
            ),
          );
    }
  });

  Future<void> importLegacy(AppDatabase legacy, String uid) async {
    final done = await (database.select(
      database.syncMetadata,
    )..where((row) => row.key.equals('legacyImported'))).getSingleOrNull();
    if (done != null) return;
    // Claim first. A failed copy can resume only for this account, never another user.
    final ownsLegacy = await legacy.transaction(() async {
      await legacy
          .into(legacy.syncMetadata)
          .insert(
            SyncMetadataCompanion.insert(key: 'legacyOwner', value: uid),
            mode: InsertMode.insertOrIgnore,
          );
      return (await (legacy.select(
                legacy.syncMetadata,
              )..where((row) => row.key.equals('legacyOwner'))).getSingle())
              .value ==
          uid;
    });
    await database.transaction(() async {
      if (ownsLegacy) {
        await merge(
          SyncSnapshot(
            (await LocalSyncStore(
              legacy,
            ).snapshot(dirtyOnly: false)).records.map(
              (row) => row.updatedAt == 0
                  ? SyncRecord.fromJson(row.kind, {
                      ...row.toJson(),
                      // Untimestamped legacy data is newer than empty signup
                      // defaults, but older than actual timestamped cloud edits.
                      'updated_at': 1,
                    })
                  : row,
            ),
          ),
          imported: true,
        );
      }
      await database
          .into(database.syncMetadata)
          .insertOnConflictUpdate(
            SyncMetadataCompanion.insert(key: 'legacyImported', value: '1'),
          );
    });
  }

  Stream<void> watchChanges() => database
      .customSelect(
        '''SELECT 'stats' AS kind, CAST(id AS TEXT) AS row_id, updated_at, dirty FROM user_stats
           UNION ALL SELECT 'word', word_id, updated_at, dirty FROM word_progress
           UNION ALL SELECT 'lesson', lesson_id, updated_at, dirty FROM lesson_progress
           UNION ALL SELECT 'profile', CAST(id AS TEXT), updated_at, dirty FROM local_profiles''',
        readsFrom: {
          database.userStats,
          database.wordProgress,
          database.lessonProgress,
          database.localProfiles,
        },
      )
      .watch()
      .map((rows) {});
}
```

### lib/features/sync/data/remote_sync_store.dart

```dart
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
```

### lib/features/sync/data/sync_service.dart

```dart
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
```

### lib/features/sync/domain/sync_record.dart

```dart
import '../../../core/utils/json_reader.dart';

enum SyncKind { stats, word, lesson, profile }

final class SyncCursor {
  const SyncCursor({this.timestamp = 0, this.revision = 0});
  final int timestamp;
  final int revision;
  String get isoTimestamp => DateTime.fromMicrosecondsSinceEpoch(
    timestamp,
    isUtc: true,
  ).toIso8601String();
}

final class SyncRecord {
  SyncRecord._(this.kind, this.id, this.updatedAt, JsonMap data)
    : data = Map.unmodifiable(data);
  final SyncKind kind;
  final String id;
  final int updatedAt;
  final JsonMap data;

  factory SyncRecord.fromJson(SyncKind kind, JsonMap json) {
    final value = json['updated_at'];
    final stamp = value is int
        ? value
        : DateTime.tryParse(value is String ? value : '')
              ?.microsecondsSinceEpoch;
    if (stamp == null) throw const FormatException('Invalid updated_at');
    if (stamp < 0) throw const FormatException('Invalid updated_at');
    String? date(String key, {bool optional = false}) {
      if (optional && json[key] == null) return null;
      final value = DateTime.tryParse(JsonReader.text(json, key));
      if (value == null) throw FormatException('Invalid $key');
      return value.toUtc().toIso8601String();
    }

    int count(String key) {
      final value = JsonReader.integer(json, key);
      if (value < 0) throw FormatException('Invalid $key');
      return value;
    }

    switch (kind) {
      case SyncKind.profile:
        final name = json['display_name'];
        if (name is! String || name.length > 120) {
          throw const FormatException('Invalid display_name');
        }
        return SyncRecord._(kind, 'profile', stamp, {'display_name': name});
      case SyncKind.stats:
        return SyncRecord._(kind, 'stats', stamp, {
          'xp': count('xp'),
          'streak': count('streak'),
          'last_active_date': date('last_active_date', optional: true),
        });
      case SyncKind.word:
        final ease = json['ease_factor'];
        if (ease is! num || !ease.isFinite || ease < 1.3) {
          throw const FormatException('Invalid ease_factor');
        }
        return SyncRecord._(kind, JsonReader.text(json, 'word_id'), stamp, {
          'ease_factor': ease.toDouble(),
          'interval_days': count('interval_days'),
          'repetitions': count('repetitions'),
          'due_date': date('due_date'),
        });
      case SyncKind.lesson:
        final completed = json['completed'];
        final score = count('best_score');
        if (completed is! bool || score > 100) {
          throw const FormatException('Invalid lesson progress');
        }
        return SyncRecord._(kind, JsonReader.text(json, 'lesson_id'), stamp, {
          'completed': completed,
          'best_score': score,
          'completed_at': date('completed_at', optional: true),
        });
    }
  }

  JsonMap toJson() => {
    if (kind == SyncKind.word) 'word_id': id,
    if (kind == SyncKind.lesson) 'lesson_id': id,
    ...data,
    'updated_at': updatedAt,
  };

  JsonMap toRemoteJson(String userId) => {
    ...toJson(),
    'user_id': userId,
    'updated_at': DateTime.fromMicrosecondsSinceEpoch(
      updatedAt,
      isUtc: true,
    ).toIso8601String(),
  };
}

final class SyncSnapshot {
  SyncSnapshot(Iterable<SyncRecord> records, {this.cursor = const SyncCursor()})
    : records = List.unmodifiable(records);
  final List<SyncRecord> records;
  final SyncCursor cursor;

  factory SyncSnapshot.fromJson(JsonMap json, {required String userId}) {
    if (json['schema_version'] != 2 || json['user_id'] != userId) {
      throw const FormatException('Sync response owner or version mismatch');
    }
    final timestamp = DateTime.tryParse(
      JsonReader.text(json, 'last_synced_at'),
    );
    final revision = JsonReader.integer(json, 'revision');
    if (timestamp == null ||
        timestamp.microsecondsSinceEpoch < 0 ||
        revision < 0) {
      throw const FormatException('Invalid sync cursor');
    }
    SyncRecord record(SyncKind kind, Object? value) {
      final row = JsonReader.object(value, kind.name);
      if (row['user_id'] != userId) {
        throw const FormatException('Sync row owner mismatch');
      }
      return SyncRecord.fromJson(kind, row);
    }

    return SyncSnapshot(
      [
        if (json['profile'] != null) record(SyncKind.profile, json['profile']),
        if (json['stats'] != null) record(SyncKind.stats, json['stats']),
        for (final value in JsonReader.list(json, 'words'))
          record(SyncKind.word, value),
        for (final value in JsonReader.list(json, 'lessons'))
          record(SyncKind.lesson, value),
      ],
      cursor: SyncCursor(
        timestamp: timestamp.microsecondsSinceEpoch,
        revision: revision,
      ),
    );
  }
}

/// The remote value wins exact timestamp ties on every device.
bool remoteWins(int? localTimestamp, int remoteTimestamp) =>
    localTimestamp == null || remoteTimestamp >= localTimestamp;
```

### lib/main.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = SupabaseConfig();
  // Keep a failed initialization retryable from the existing auth error screen.
  Future<SupabaseClient>? initialization;
  if (config.isConfigured) {
    initialization = Supabase.initialize(
      url: config.url,
      publishableKey: config.publishableKey,
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    ).then((supabase) => supabase.client);
    try {
      await initialization;
    } catch (_) {
      initialization = null;
    }
  }
  final client = initialization;
  runApp(
    ProviderScope(
      overrides: [
        if (client != null)
          supabaseClientProvider.overrideWith((ref) => client),
      ],
      child: const LanguageApp(),
    ),
  );
}
```

### supabase/migrations/202611120001_phase6c.sql

```sql
-- PHASE 6C: run this ONE script in Supabase SQL Editor.
-- Supports both a fresh project and the previous Phase 6A schema; preserves rows.
-- Old app builds using sync_progress must be upgraded together with this schema.
begin;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '' check (length(display_name) <= 120),
  updated_at timestamptz not null default now()
);
create table if not exists public.user_stats (
  user_id uuid primary key references auth.users(id) on delete cascade,
  xp bigint not null default 0 check (xp >= 0),
  streak integer not null default 0 check (streak >= 0),
  last_active_date timestamptz,
  updated_at timestamptz not null default 'epoch'
);
create table if not exists public.lesson_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  lesson_id text not null check (length(lesson_id) > 0),
  completed boolean not null default false,
  best_score integer not null default 0 check (best_score between 0 and 100),
  completed_at timestamptz,
  updated_at timestamptz not null default 'epoch',
  primary key (user_id, lesson_id)
);
create table if not exists public.word_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  word_id text not null check (length(word_id) > 0),
  ease_factor double precision not null default 2.5
    check (ease_factor >= 1.3 and ease_factor <> 'NaN'::float8 and ease_factor <> 'Infinity'::float8),
  interval_days integer not null default 0 check (interval_days >= 0),
  repetitions integer not null default 0 check (repetitions >= 0),
  due_date timestamptz not null,
  updated_at timestamptz not null default 'epoch',
  primary key (user_id, word_id)
);

drop function if exists public.sync_progress(uuid, jsonb, jsonb, jsonb);
-- Convert Phase 6A microseconds without rounding through a floating-point epoch.
do $$
declare t text;
begin
  foreach t in array array['user_stats', 'lesson_progress', 'word_progress'] loop
    if exists (select 1 from information_schema.columns where table_schema = 'public'
      and table_name = t and column_name = 'updated_at' and data_type = 'bigint') then
      execute format('alter table public.%I drop constraint if exists %I', t, t || '_updated_at_check');
      execute format('alter table public.%I alter column updated_at drop default', t);
      execute format('alter table public.%I alter column updated_at type timestamptz using
        (timestamptz ''epoch'' + (updated_at / 1000000) * interval ''1 second''
          + (updated_at %% 1000000) * interval ''1 microsecond'')', t);
      execute format('alter table public.%I alter column updated_at set default ''epoch''', t);
    end if;
  end loop;
end $$;

-- Internal revision protects incremental downloads from late offline uploads.
-- Per-user transaction locks make revision order match visible commit order.
create sequence if not exists public.progress_sync_version;
revoke all on sequence public.progress_sync_version from public, anon, authenticated;
do $$
declare t text; p record;
begin
  foreach t in array array['profiles', 'user_stats', 'lesson_progress', 'word_progress'] loop
    execute format('alter table public.%I add column if not exists sync_version bigint not null default 0', t);
    execute format('update public.%I set sync_version = nextval(''public.progress_sync_version'') where sync_version = 0', t);
    execute format('alter table public.%I enable row level security', t);
    -- These four application tables use a single ownership policy each.
    for p in select policyname from pg_policies where schemaname = 'public' and tablename = t loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    execute format('revoke all on public.%I from public, anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('create policy own_rows on public.%I for all to authenticated
      using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', t);
    execute format('create index if not exists %I on public.%I (user_id, updated_at)', t || '_sync_time', t);
    execute format('create index if not exists %I on public.%I (user_id, sync_version)', t || '_sync_revision', t);
  end loop;
end $$;

create or replace function public.guard_progress_write()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.user_id::text, 0));
  if tg_op = 'UPDATE' then
    if new.user_id <> old.user_id then
      raise exception 'Row ownership cannot change' using errcode = '42501';
    end if;
    if new.updated_at <= old.updated_at then
      return old; -- Existing cloud row wins ties; RETURNING supplies its value.
    end if;
  end if;
  new.sync_version := pg_catalog.nextval('public.progress_sync_version'::regclass);
  return new;
end $$;
revoke all on function public.guard_progress_write() from public, anon, authenticated;
do $$
declare t text;
begin
  foreach t in array array['profiles', 'user_stats', 'lesson_progress', 'word_progress'] loop
    execute format('drop trigger if exists guard_progress_write on public.%I', t);
    execute format('create trigger guard_progress_write before insert or update on public.%I
      for each row execute function public.guard_progress_write()', t);
  end loop;
end $$;

create or replace function public.create_signup_rows()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(user_id, display_name)
  values (new.id, left(coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', ''), 120))
  on conflict (user_id) do nothing;
  -- Empty stats use epoch so they cannot replace actual offline progress.
  insert into public.user_stats(user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end $$;
revoke all on function public.create_signup_rows() from public, anon, authenticated;
drop trigger if exists create_signup_rows on auth.users;
create trigger create_signup_rows after insert on auth.users
  for each row execute function public.create_signup_rows();
-- Also repair accounts created before this phase without replacing their data.
insert into public.profiles(user_id, display_name)
  select id, left(coalesce(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name', ''), 120)
  from auth.users on conflict (user_id) do nothing;
insert into public.user_stats(user_id) select id from auth.users on conflict (user_id) do nothing;

-- Pull a consistent per-account delta. Invoker privileges preserve RLS.
-- Returning JSON avoids PostgREST's default SELECT row-count cap.
create or replace function public.pull_progress(
  p_since timestamptz default 'epoch', p_after_version bigint default 0
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare uid uuid := auth.uid(); result jsonb; boundary bigint; stamp timestamptz;
begin
  if uid is null then raise exception 'Sign in required' using errcode = '42501'; end if;
  if p_since is null or p_since < timestamptz 'epoch' or p_after_version is null or p_after_version < 0 then
    raise exception 'Invalid sync cursor' using errcode = '22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(uid::text, 0));
  select greatest(p_after_version, coalesce(max(sync_version), 0)),
         greatest(p_since, coalesce(max(updated_at), timestamptz 'epoch'))
    into boundary, stamp from (
      select updated_at, sync_version from public.profiles where user_id = uid
      union all select updated_at, sync_version from public.user_stats where user_id = uid
      union all select updated_at, sync_version from public.lesson_progress where user_id = uid
      union all select updated_at, sync_version from public.word_progress where user_id = uid
    ) as versions;
  select jsonb_build_object(
    'schema_version', 2, 'user_id', uid, 'last_synced_at', stamp, 'revision', boundary,
    'profile', (select to_jsonb(r) from public.profiles r where user_id = uid
      and (updated_at > p_since or sync_version > p_after_version)),
    'stats', (select to_jsonb(r) from public.user_stats r where user_id = uid
      and (updated_at > p_since or sync_version > p_after_version)),
    'lessons', coalesce((select jsonb_agg(to_jsonb(r) order by lesson_id) from public.lesson_progress r
      where user_id = uid and (updated_at > p_since or sync_version > p_after_version)), '[]'::jsonb),
    'words', coalesce((select jsonb_agg(to_jsonb(r) order by word_id) from public.word_progress r
      where user_id = uid and (updated_at > p_since or sync_version > p_after_version)), '[]'::jsonb)
  ) into result;
  return result;
end $$;
revoke all on function public.pull_progress(timestamptz, bigint) from public, anon;
grant execute on function public.pull_progress(timestamptz, bigint) to authenticated;
notify pgrst, 'reload schema';
commit;
```

### supabase/tests/phase6c_security.mjs

```javascript
// npm.cmd install --prefix .dart_tool/sqlcheck --no-save @electric-sql/pglite@0.5.15
// node.exe supabase/tests/phase6c_security.mjs
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const require = createRequire(resolve('.dart_tool/sqlcheck/package.json'));
const { PGlite } = require('@electric-sql/pglite');
const migration = await readFile('supabase/migrations/202611120001_phase6c.sql', 'utf8');
const A = '11111111-1111-4111-8111-111111111111';
const B = '22222222-2222-4222-8222-222222222222';
const tables = ['profiles', 'user_stats', 'lesson_progress', 'word_progress'];
let assertions = 0;
async function check(name, run) { await run(); assertions++; console.log(`PASS: ${name}`); }
async function setup(db) {
  await db.exec(`create role anon; create role authenticated;
    create schema auth;
    create table auth.users(id uuid primary key, raw_user_meta_data jsonb default '{}'::jsonb);
    create function auth.uid() returns uuid language sql stable as
      $$select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid$$;
    grant usage on schema auth, public to anon, authenticated;
    grant execute on function auth.uid() to anon, authenticated;`);
}
async function identity(db, uid, role = 'authenticated') {
  await db.exec(`reset role; set role ${role}`);
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [uid ?? '']);
}
async function pull(db, cursor) {
  const result = await db.query('select public.pull_progress($1::timestamptz, $2::bigint) as data',
    [cursor?.last_synced_at ?? '1970-01-01T00:00:00Z', cursor?.revision ?? 0]);
  return result.rows[0].data;
}
async function upsertStats(db, uid, xp, timestamp) {
  return (await db.query(`insert into public.user_stats(user_id, xp, updated_at) values ($1,$2,$3)
    on conflict(user_id) do update set xp=excluded.xp, updated_at=excluded.updated_at returning *`,
  [uid, xp, timestamp])).rows[0];
}
const db = new PGlite();
try {
  await setup(db);
  await db.exec(migration);
  await db.query(`insert into auth.users(id, raw_user_meta_data) values ($1, '{"full_name":"Learner A"}'),($2,'{}')`, [A,B]);
  await check('signup creates profiles and empty stats for both accounts', async () => {
    assert.equal((await db.query('select * from public.profiles where user_id=$1', [A])).rows[0].display_name, 'Learner A');
    assert.equal((await db.query('select * from public.user_stats')).rows.length, 2);
  });
  await check('all four tables use timestamptz and RLS', async () => {
    for (const table of tables) {
      const result = await db.query(`select data_type from information_schema.columns
        where table_schema='public' and table_name=$1 and column_name='updated_at'`, [table]);
      assert.equal(result.rows[0].data_type, 'timestamp with time zone');
      assert.equal((await db.query('select relrowsecurity from pg_class where oid=$1::regclass', [`public.${table}`])).rows[0].relrowsecurity, true);
    }
  });
  await identity(db, A);
  const initial = await pull(db);
  await check('second pull without changes is empty', async () => {
    const delta = await pull(db, initial);
    assert.equal(delta.profile, null); assert.equal(delta.stats, null);
    assert.deepEqual(delta.words, []); assert.deepEqual(delta.lessons, []);
  });
  await check('upsert retains newer cloud values and returns them for stale/tied writes', async () => {
    const stamp = '2026-11-12T10:00:00.123456Z';
    await upsertStats(db, A, 50, stamp);
    assert.equal((await upsertStats(db, A, 99, stamp)).xp, 50);
    assert.equal((await upsertStats(db, A, 99, '2026-11-11T10:00:00Z')).xp, 50);
    assert.equal((await upsertStats(db, A, 30, '2026-11-12T10:00:00.123457Z')).xp, 30);
  });
  await check('late offline row with older updated_at is still downloaded via revision', async () => {
    const cursor = await pull(db, initial);
    await db.query(`insert into public.word_progress(user_id,word_id,due_date,updated_at)
      values ($1,'late-word',now(),'2020-01-01')`, [A]);
    const delta = await pull(db, cursor);
    assert.equal(delta.words[0].word_id, 'late-word');
    assert.ok(delta.revision > cursor.revision);
    const empty = await pull(db, delta);
    assert.deepEqual(empty.words, []);
  });
  await check('RLS prevents A reading any rows belonging to B', async () => {
    for (const table of tables) {
      assert.equal((await db.query(`select * from public.${table} where user_id=$1`, [B])).rows.length, 0);
    }
  });
  await check('RLS blocks inserts for B and changes of owner', async () => {
    const sql = [
      `insert into public.profiles(user_id) values ($1)`,
      `insert into public.user_stats(user_id) values ($1)`,
      `insert into public.lesson_progress(user_id,lesson_id) values ($1,'stolen')`,
      `insert into public.word_progress(user_id,word_id,due_date) values ($1,'stolen',now())`,
    ];
    for (const statement of sql) await assert.rejects(db.query(statement, [B]), { code: '42501' });
    await assert.rejects(db.query(`update public.user_stats set user_id=$1, updated_at=now() where user_id=$2`, [B,A]), {code: '42501'});
  });
  await check('RLS hides B from updates and deletes across all tables', async () => {
    for (const table of tables) {
      assert.equal((await db.query(`update public.${table} set updated_at=now() where user_id=$1 returning *`, [B])).rows.length, 0);
      assert.equal((await db.query(`delete from public.${table} where user_id=$1 returning *`, [B])).rows.length, 0);
    }
  });
  await check('owner can insert, update and delete own lesson and word rows', async () => {
    await db.query(`insert into public.lesson_progress(user_id,lesson_id) values ($1,'own')`, [A]);
    assert.equal((await db.query(`update public.lesson_progress set completed=true,updated_at=now() where user_id=$1 returning *`, [A])).rows[0].completed, true);
    assert.equal((await db.query('delete from public.lesson_progress where user_id=$1 returning *', [A])).rows.length, 1);
    assert.equal((await db.query('delete from public.word_progress where user_id=$1 returning *', [A])).rows.length, 1);
  });
  await check('clients cannot forge the revision counter', async () => {
    const row = (await db.query(`update public.user_stats set sync_version=99999999,
      updated_at='2027-01-01' where user_id=$1 returning *`, [A])).rows[0];
    assert.notEqual(row.sync_version, 99999999);
  });
  await identity(db, null, 'anon');
  await check('anonymous access is blocked for all tables and pull RPC', async () => {
    for (const table of tables) await assert.rejects(db.query(`select * from public.${table}`), {code:'42501'});
    await assert.rejects(pull(db), {code:'42501'});
  });
  await identity(db, null);
  await check('expired session cannot pull progress', async () => {
    await assert.rejects(pull(db), {code:'42501'});
  });
  await db.exec('reset role');
  await check('script can be run twice without losing existing progress', async () => {
    await db.exec(migration);
    assert.equal((await db.query('select xp from public.user_stats where user_id=$1', [A])).rows[0].xp, 30);
  });
} finally { await db.close(); }

const upgrade = new PGlite();
try {
  await setup(upgrade);
  await upgrade.query('insert into auth.users(id) values ($1)', [A]);
  await upgrade.exec(await readFile('supabase/migrations/202611080001_auth_sync.sql', 'utf8'));
  await upgrade.query(`insert into public.user_stats(user_id,xp,updated_at) values ($1,99,1794477600123456)`, [A]);
  await upgrade.exec(migration);
  await check('Phase 6A upgrade preserves XP and exact microsecond timestamp', async () => {
    const result = await upgrade.query(`select xp, (extract(epoch from updated_at)*1000000)::bigint as stamp
      from public.user_stats where user_id=$1`, [A]);
    assert.equal(result.rows[0].xp, 99);
    assert.equal(result.rows[0].stamp, 1794477600123456);
    assert.equal((await upgrade.query('select * from public.profiles')).rows.length, 1);
  });
} finally { await upgrade.close(); }
console.log(`${assertions} Phase 6C SQL checks passed.`);
```

### test/account_database_test.dart

```dart
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/features/sync/data/local_sync_store.dart';

void main() {
  setUp(() {
    // These tests intentionally open distinct in-memory executors for each account.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });
  tearDown(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  test(
    'schema version 1 migrates existing data to durable pending sync rows',
    () async {
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute('''
        CREATE TABLE lesson_progress (lesson_id TEXT PRIMARY KEY NOT NULL, completed INTEGER NOT NULL DEFAULT 0, best_score INTEGER NOT NULL DEFAULT 0, completed_at INTEGER);
        CREATE TABLE word_progress (word_id TEXT PRIMARY KEY NOT NULL, ease_factor REAL NOT NULL DEFAULT 2.5, interval_days INTEGER NOT NULL DEFAULT 0, repetitions INTEGER NOT NULL DEFAULT 0, due_date INTEGER NOT NULL);
        CREATE TABLE user_stats (id INTEGER PRIMARY KEY NOT NULL DEFAULT 1, xp INTEGER NOT NULL DEFAULT 0, streak INTEGER NOT NULL DEFAULT 0, last_active_date INTEGER);
        INSERT INTO user_stats(id, xp, streak) VALUES (1, 80, 3);
        INSERT INTO word_progress(word_id, due_date) VALUES ('ja_hello', 1000);
        INSERT INTO lesson_progress(lesson_id, completed, best_score) VALUES ('ja_greetings', 1, 90);
        PRAGMA user_version = 1;
      ''');
          },
        ),
      );
      addTearDown(database.close);
      final stats = await database.select(database.userStats).getSingle();
      expect(stats.xp, 80);
      expect(stats.streak, 3);
      expect(stats.updatedAt, 0);
      expect(stats.dirty, isTrue);
      expect(
        (await database.select(database.wordProgress).getSingle()).dirty,
        isTrue,
      );
      expect(
        (await database.select(database.lessonProgress).getSingle()).bestScore,
        90,
      );
      expect(await database.select(database.syncMetadata).get(), isEmpty);
    },
  );

  test(
    'legacy progress is claimed by one account and never copied to another',
    () async {
      final legacy = AppDatabase.forTesting(NativeDatabase.memory());
      final a = AppDatabase.forTesting(NativeDatabase.memory());
      final b = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(legacy.close);
      addTearDown(a.close);
      addTearDown(b.close);
      await legacy.select(legacy.userStats).getSingle();
      await legacy
          .update(legacy.userStats)
          .write(const UserStatsCompanion(xp: Value(80)));
      await legacy
          .into(legacy.wordProgress)
          .insert(
            WordProgressCompanion.insert(
              wordId: 'ja_hello',
              dueDate: DateTime.utc(2026, 11, 8),
            ),
          );
      await LocalSyncStore(a).importLegacy(legacy, 'A');
      await LocalSyncStore(b).importLegacy(legacy, 'B');
      expect((await a.select(a.userStats).getSingle()).xp, 80);
      expect((await a.select(a.userStats).getSingle()).updatedAt, 1);
      expect((await a.select(a.wordProgress).get()).length, 1);
      expect((await b.select(b.userStats).getSingle()).xp, 0);
      expect(await b.select(b.wordProgress).get(), isEmpty);
      await a
          .update(a.userStats)
          .write(
            const UserStatsCompanion(xp: Value(100), updatedAt: Value(10)),
          );
      await LocalSyncStore(a).importLegacy(legacy, 'A');
      expect((await a.select(a.userStats).getSingle()).xp, 100);
    },
  );

  test('schema version 2 adds profiles without losing sync metadata or pending flags', () async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
        CREATE TABLE lesson_progress (lesson_id TEXT PRIMARY KEY NOT NULL, completed INTEGER NOT NULL DEFAULT 0, best_score INTEGER NOT NULL DEFAULT 0, completed_at INTEGER, updated_at INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1);
        CREATE TABLE word_progress (word_id TEXT PRIMARY KEY NOT NULL, ease_factor REAL NOT NULL DEFAULT 2.5, interval_days INTEGER NOT NULL DEFAULT 0, repetitions INTEGER NOT NULL DEFAULT 0, due_date INTEGER NOT NULL, updated_at INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1);
        CREATE TABLE user_stats (id INTEGER PRIMARY KEY NOT NULL DEFAULT 1, xp INTEGER NOT NULL DEFAULT 0, streak INTEGER NOT NULL DEFAULT 0, last_active_date INTEGER, updated_at INTEGER NOT NULL DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1);
        CREATE TABLE sync_metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);
        INSERT INTO user_stats(id,xp,updated_at,dirty) VALUES (1,80,100,0);
        INSERT INTO sync_metadata(key,value) VALUES ('legacyImported','1');
        PRAGMA user_version = 2;
      ''');
        },
      ),
    );
    addTearDown(database.close);
    final row = await database.select(database.userStats).getSingle();
    expect(row.xp, 80);
    expect(row.updatedAt, 100);
    expect(row.dirty, isFalse);
    expect(
      (await database.select(database.syncMetadata).getSingle()).value,
      '1',
    );
    expect(await database.select(database.localProfiles).get(), isEmpty);
    expect((await LocalSyncStore(database).readCursor()).revision, 0);
  });

  test(
    'account filenames are deterministic and cannot contain path separators',
    () {
      expect(AppDatabase.databaseName(null), 'language_learning');
      expect(
        AppDatabase.databaseName('A'),
        isNot(AppDatabase.databaseName('B')),
      );
      expect(AppDatabase.databaseName('a/b'), isNot(contains('/')));
      expect(AppDatabase.databaseName('A'), AppDatabase.databaseName('A'));
    },
  );
}
```

### test/auth_repository_test.dart

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/features/auth/data/auth_repository.dart';
import 'package:myapp/features/auth/domain/auth_models.dart';

class MockClient extends Mock implements SupabaseClient {}

class MockAuth extends Mock implements GoTrueClient {}

class MockSession extends Mock implements Session {}

class MockUser extends Mock implements User {}

void main() {
  late MockClient client;
  late MockAuth auth;
  late MockSession session;
  late SupabaseAuthRepository repository;
  late StreamController<AuthState> events;
  setUp(() {
    client = MockClient();
    auth = MockAuth();
    session = MockSession();
    final user = MockUser();
    events = StreamController<AuthState>.broadcast(sync: true);
    when(() => client.auth).thenReturn(auth);
    when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
    when(() => auth.currentSession).thenReturn(session);
    when(() => session.user).thenReturn(user);
    when(() => user.id).thenReturn('account-a');
    when(() => user.email).thenReturn('a@example.com');
    repository = SupabaseAuthRepository(
      client,
      redirectTo: 'io.languagelearning.app://auth-callback',
    );
  });
  tearDown(() => events.close());

  test(
    'refresh network errors retain a cached identity for offline lessons',
    () {
      final received = <AuthIdentity?>[];
      final subscription = repository.watchIdentity().listen(received.add);
      addTearDown(subscription.cancel);
      events.add(AuthState(AuthChangeEvent.initialSession, session));
      events.addError(const AuthException('Network unavailable'));
      expect(received.map((identity) => identity!.id), [
        'account-a',
        'account-a',
      ]);
    },
  );
  test('password recovery event routes to reset until password is updated', () {
    final received = <AuthIdentity?>[];
    final subscription = repository.watchIdentity().listen(received.add);
    addTearDown(subscription.cancel);
    events.add(AuthState(AuthChangeEvent.passwordRecovery, session));
    events.add(AuthState(AuthChangeEvent.userUpdated, session));
    expect(received.map((identity) => identity!.needsPasswordReset), [
      true,
      false,
    ]);
  });
  test('invalid credentials become a friendly domain failure', () async {
    when(
      () => auth.signInWithPassword(email: 'a@example.com', password: 'wrong'),
    ).thenThrow(
      const AuthException(
        'Invalid login credentials',
        code: 'invalid_credentials',
      ),
    );
    await expectLater(
      repository.signIn(' a@example.com ', 'wrong'),
      throwsA(
        isA<AuthFailure>().having(
          (error) => error.message,
          'message',
          contains('incorrect'),
        ),
      ),
    );
  });
  test(
    'expired session without cached credentials emits logged out safely',
    () {
      when(() => auth.currentSession).thenReturn(null);
      final received = <AuthIdentity?>[];
      final subscription = repository.watchIdentity().listen(received.add);
      addTearDown(subscription.cancel);
      events.addError(
        const AuthException(
          'Refresh token revoked',
          code: 'refresh_token_not_found',
        ),
      );
      expect(received, [null]);
    },
  );
}
```

### test/auth_validation_test.dart

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/config/supabase_config.dart';
import 'package:myapp/features/auth/domain/auth_models.dart';

void main() {
  test(
    'email validation accepts trimmed addresses and rejects malformed input',
    () {
      expect(AuthValidation.email(' learner@example.com '), isNull);
      for (final value in ['', 'missing-at', 'a@b', 'a b@example.com']) {
        expect(AuthValidation.email(value), isNotNull);
      }
    },
  );
  test('new passwords need eight characters; sign-in accepts existing shorter passwords', () {
    expect(AuthValidation.password(''), isNotNull);
    expect(AuthValidation.password('short', creating: true), isNotNull);
    expect(AuthValidation.password('short'), isNull);
    expect(AuthValidation.password('secret123', creating: true), isNull);
    expect(AuthValidation.confirmation('secret123', 'secret123'), isNull);
    expect(AuthValidation.confirmation('different', 'secret123'), isNotNull);
  });
  test('auth error codes map to clear messages', () {
    expect(authMessageForCode('invalid_credentials'), contains('incorrect'));
    expect(
      authMessageForCode('email_not_confirmed'),
      contains('Confirm your email'),
    );
    expect(authMessageForCode('over_email_send_rate_limit'), contains('wait'));
    expect(authMessageForCode('network'), contains('connection'));
    expect(authMessageForCode('unknown'), contains('try again'));
  });
  test('configuration accepts only public client keys and valid URLs', () {
    expect(
      const SupabaseConfig(url: '', publishableKey: '').isConfigured,
      isFalse,
    );
    expect(
      const SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: 'sb_publishable_example',
      ).isConfigured,
      isTrue,
    );
    expect(
      const SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: 'sb_secret_private',
      ).isConfigured,
      isFalse,
    );
    String jwt(String role) =>
        'header.${base64Url.encode(utf8.encode(jsonEncode({'role': role})))}.signature';
    expect(
      SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: jwt('anon'),
      ).isConfigured,
      isTrue,
    );
    expect(
      SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: jwt('service_role'),
      ).isConfigured,
      isFalse,
    );
  });
}
```

### test/auth_widget_test.dart

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/router/app_router.dart';
import 'package:myapp/features/auth/domain/auth_models.dart';

import 'support/auth_fixtures.dart';
import 'support/phase3_fixtures.dart';
import 'widget_test.dart' show AppHarness, mount, tapText;

Future<void> enter(WidgetTester tester, String key, String value) async {
  final target = find.byKey(ValueKey(key));
  final field = key == 'auth-email'
      ? target
      : find.descendant(of: target, matching: find.byType(TextFormField));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
}

Future<void> submit(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'session expiry redirects an open lesson to Login without crashing',
    (tester) async {
      final repository = MemoryAuthRepository(
        identity: const AuthIdentity(id: 'account-a', email: 'a@example.com'),
      );
      addTearDown(repository.close);
      final harness = AppHarness(
        authRepository: repository,
        settings: completedSettings(),
      );
      await mount(tester, harness);
      final router = harness.container.read(appRouterProvider);
      router.go('/lesson/ja_greetings');
      await tester.pumpAndSettle();
      repository.emit(null);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/login');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'missing Supabase configuration shows a login error instead of crashing',
    (tester) async {
      final harness = AppHarness(useRealAuth: true);
      await mount(tester, harness);
      expect(
        harness.container.read(appRouterProvider).state.uri.path,
        '/login',
      );
      expect(
        find.text('Sign-in is unavailable on this build.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'logged-out routes redirect to login; valid login returns to Learn',
    (tester) async {
      final repository = MemoryAuthRepository();
      addTearDown(repository.close);
      final harness = AppHarness(
        authRepository: repository,
        settings: completedSettings(),
      );
      await mount(tester, harness);
      final router = harness.container.read(appRouterProvider);
      expect(router.state.uri.path, '/login');
      router.go('/lesson/ja_greetings');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/login');
      await submit(tester, 'Sign in');
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      await enter(tester, 'auth-email', 'a@example.com');
      await enter(tester, 'auth-password', 'password123');
      await submit(tester, 'Sign in');
      expect(router.state.uri.path, '/home');
      await tester.tap(find.byType(NavigationDestination).at(2));
      await tester.pumpAndSettle();
      expect(find.text('a@example.com'), findsOneWidget);
      await tapText(tester, 'Sign out');
      expect(router.state.uri.path, '/login');
    },
  );

  testWidgets(
    'registration validates confirmation and explains email verification',
    (tester) async {
      final repository = MemoryAuthRepository();
      addTearDown(repository.close);
      final harness = AppHarness(authRepository: repository);
      await mount(tester, harness);
      await tapText(tester, 'Create an account');
      await enter(tester, 'auth-email', 'new@example.com');
      await enter(tester, 'auth-password', 'password123');
      await enter(tester, 'auth-confirmation', 'different');
      await submit(tester, 'Register');
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await enter(tester, 'auth-confirmation', 'password123');
      await submit(tester, 'Register');
      expect(
        find.text('Check your email to confirm your account, then sign in.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'forgot-password email and recovery link complete the reset flow',
    (tester) async {
      final repository = MemoryAuthRepository();
      addTearDown(repository.close);
      final harness = AppHarness(
        authRepository: repository,
        settings: completedSettings(),
      );
      await mount(tester, harness);
      await tapText(tester, 'Forgot password?');
      await enter(tester, 'auth-email', 'reset@example.com');
      await submit(tester, 'Send reset link');
      expect(repository.resetEmail, 'reset@example.com');
      expect(find.textContaining('If an account exists'), findsOneWidget);
      repository.emit(
        const AuthIdentity(
          id: 'account-a',
          email: 'reset@example.com',
          needsPasswordReset: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        harness.container.read(appRouterProvider).state.uri.path,
        '/reset-password',
      );
      await enter(tester, 'auth-password', 'newpassword123');
      await enter(tester, 'auth-confirmation', 'newpassword123');
      await submit(tester, 'Update password');
      expect(repository.updatedPassword, 'newpassword123');
      expect(harness.container.read(appRouterProvider).state.uri.path, '/home');
    },
  );

  testWidgets(
    'login errors preserve input and in-flight submits cannot repeat',
    (tester) async {
      final repository = MemoryAuthRepository()..failLogin = true;
      addTearDown(repository.close);
      final harness = AppHarness(
        authRepository: repository,
        settings: completedSettings(),
      );
      await mount(tester, harness);
      await enter(tester, 'auth-email', 'a@example.com');
      await enter(tester, 'auth-password', 'password123');
      await submit(tester, 'Sign in');
      expect(find.text('The email or password is incorrect.'), findsOneWidget);
      repository.failLogin = false;
      repository.loginGate = Completer<void>();
      await submit(tester, 'Sign in');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Please wait…'),
            )
            .onPressed,
        isNull,
      );
      expect(repository.loginCalls, 2);
      repository.loginGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('Google starts OAuth and its auth callback opens the app', (
    tester,
  ) async {
    final repository = MemoryAuthRepository();
    addTearDown(repository.close);
    final harness = AppHarness(
      authRepository: repository,
      settings: completedSettings(),
    );
    await mount(tester, harness);
    await tapText(tester, 'Continue with Google');
    expect(repository.googleCalls, 1);
    expect(find.text('Finish signing in in the browser.'), findsOneWidget);
    repository.emit(
      const AuthIdentity(id: 'google-account', email: 'google@example.com'),
    );
    await tester.pumpAndSettle();
    expect(harness.container.read(appRouterProvider).state.uri.path, '/home');
  });

  for (final brightness in Brightness.values) {
    testWidgets('auth forms fit 320px with 200% text in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final repository = MemoryAuthRepository();
      addTearDown(repository.close);
      final harness = AppHarness(authRepository: repository);
      await mount(tester, harness);
      for (final route in ['/login', '/register', '/forgot-password']) {
        harness.container.read(appRouterProvider).go(route);
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
      }
      repository.emit(
        const AuthIdentity(
          id: 'account-a',
          email: 'a@example.com',
          needsPasswordReset: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Set a new password'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
```

### test/remote_sync_store_test.dart

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/features/sync/data/remote_sync_store.dart';
import 'package:myapp/features/sync/domain/sync_record.dart';

class MockClient extends Mock implements SupabaseClient {}

class MockAuth extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

void main() {
  late HttpServer server;
  late SupabaseClient transport;
  late MockClient client;
  late MockAuth auth;
  late SupabaseSyncStore store;
  late List<({Uri uri, dynamic body})> requests;
  late Future<void> Function(HttpRequest, dynamic) respond;
  const stamp = '2026-11-12T08:00:00.123456Z';
  final cursor = SyncCursor(
    timestamp: DateTime.parse(stamp).microsecondsSinceEpoch,
    revision: 7,
  );
  Map<String, dynamic> delta() => {
    'schema_version': 2,
    'user_id': 'A',
    'last_synced_at': stamp,
    'revision': 8,
    'profile': null,
    'stats': null,
    'words': [],
    'lessons': [],
  };
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    transport = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    client = MockClient();
    auth = MockAuth();
    final user = MockUser();
    when(() => user.id).thenReturn('A');
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(user);
    when(() => client.from(any())).thenAnswer(
      (call) => transport.from(call.positionalArguments[0] as String),
    );
    when(() => client.rpc(any(), params: any(named: 'params'))).thenAnswer(
      (call) => transport.rpc(
        call.positionalArguments[0] as String,
        params: call.namedArguments[#params] as Map<String, dynamic>?,
      ),
    );
    store = SupabaseSyncStore(client);
    requests = [];
    respond = (request, body) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(request.uri.path.endsWith('pull_progress') ? delta() : body),
      );
    };
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      requests.add((uri: request.uri, body: body));
      try {
        await respond(request, body);
      } finally {
        await request.response.close();
      }
    });
  });
  tearDown(() async {
    await transport.dispose();
    await server.close(force: true);
  });

  test(
    'real HTTP requests upsert all primary keys then pull with saved cursor',
    () async {
      final snapshot = SyncSnapshot([
        SyncRecord.fromJson(SyncKind.stats, {
          'xp': 10,
          'streak': 1,
          'last_active_date': null,
          'updated_at': stamp,
        }),
        SyncRecord.fromJson(SyncKind.word, {
          'word_id': 'hello',
          'ease_factor': 2.5,
          'interval_days': 1,
          'repetitions': 1,
          'due_date': stamp,
          'updated_at': stamp,
        }),
        SyncRecord.fromJson(SyncKind.lesson, {
          'lesson_id': 'greetings',
          'completed': true,
          'best_score': 100,
          'completed_at': stamp,
          'updated_at': stamp,
        }),
        SyncRecord.fromJson(SyncKind.profile, {
          'display_name': 'Learner',
          'updated_at': stamp,
        }),
      ]);
      final result = await store.exchange('A', snapshot, cursor: cursor);
      expect(requests, hasLength(5));
      expect(
        requests.take(4).map((r) => r.uri.queryParameters['on_conflict']),
        ['user_id', 'user_id,word_id', 'user_id,lesson_id', 'user_id'],
      );
      for (final request in requests.take(4)) {
        expect(request.body[0]['user_id'], 'A');
        expect(
          DateTime.parse(request.body[0]['updated_at'] as String),
          DateTime.parse(stamp),
        );
      }
      expect(requests.last.uri.path, '/rest/v1/rpc/pull_progress');
      expect(requests.last.body['p_since'], cursor.isoTimestamp);
      expect(requests.last.body['p_after_version'], 7);
      expect(result.records, hasLength(4));
      expect(result.cursor.revision, 8);
    },
  );

  test('account mismatch is rejected before any request', () async {
    when(() => auth.currentUser).thenReturn(null);
    await expectLater(store.exchange('A', SyncSnapshot([])), throwsStateError);
    expect(requests, isEmpty);
  });

  test(
    'account change during upload prevents pull and application of response',
    () async {
      respond = (request, body) async {
        when(() => auth.currentUser).thenReturn(null);
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(body));
      };
      await expectLater(
        store.exchange(
          'A',
          SyncSnapshot([
            SyncRecord.fromJson(SyncKind.profile, {
              'display_name': 'Learner',
              'updated_at': stamp,
            }),
          ]),
        ),
        throwsStateError,
      );
      expect(requests, hasLength(1));
    },
  );

  test('server rejection leaves upload unacknowledged and does not advance to pull', () async {
    respond = (request, body) async {
      request.response.statusCode = HttpStatus.forbidden;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'code': '42501', 'message': 'Denied'}),
      );
    };
    await expectLater(
      store.exchange(
        'A',
        SyncSnapshot([
          SyncRecord.fromJson(SyncKind.profile, {
            'display_name': 'Learner',
            'updated_at': stamp,
          }),
        ]),
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect(requests, hasLength(1));
  });
}
```

### test/sync_service_test.dart

```dart
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
```
