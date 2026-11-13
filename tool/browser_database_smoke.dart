// Run only on a separate test origin, never the origin holding your own progress:
// flutter run -d edge -t tool/browser_database_smoke.dart --web-port=7358
import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';

import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/features/sync/data/local_sync_store.dart';

void require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await checkBrowserDatabase();
    debugPrint('BROWSER_DATABASE_SMOKE_PASS');
    runApp(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: Text('Browser database checks passed.')),
      ),
    );
  } catch (error, stack) {
    debugPrint('BROWSER_DATABASE_SMOKE_FAIL: $error\n$stack');
    rethrow;
  }
}

Future<void> checkBrowserDatabase() async {
  const userA = 'browser-smoke-account-a';
  const userB = 'browser-smoke-account-b';
  final legacy = AppDatabase();
  final accountA = AppDatabase(userId: userA);
  final accountB = AppDatabase(userId: userB);
  try {
    // Use the production constructor, worker and migration, rather than the
    // in-memory native executor used by unit tests.
    await legacy
        .update(legacy.userStats)
        .write(
          const UserStatsCompanion(
            xp: Value(80),
            streak: Value(3),
            longestStreak: Value(3),
          ),
        );
    final storeA = LocalSyncStore(accountA);
    await storeA.importLegacy(legacy, userA);
    await LocalSyncStore(accountB).importLegacy(legacy, userB);
    final statsA = await accountA.select(accountA.userStats).getSingle();
    final statsB = await accountB.select(accountB.userStats).getSingle();
    require(statsA.xp == 80 && statsA.streak == 3, 'Legacy import failed');
    require(statsB.xp == 0, 'Accounts are not isolated');
    await accountA
        .into(accountA.wordProgress)
        .insertOnConflictUpdate(
          WordProgressCompanion.insert(
            wordId: 'browser-smoke-word',
            dueDate: DateTime.utc(2026, 11, 13),
          ),
        );
    await accountA
        .into(accountA.lessonProgress)
        .insertOnConflictUpdate(
          LessonProgressCompanion.insert(
            lessonId: 'browser-smoke-lesson',
            completed: const Value(true),
            bestScore: const Value(100),
          ),
        );
    await accountA
        .into(accountA.dailyActivities)
        .insertOnConflictUpdate(
          DailyActivitiesCompanion.insert(
            activityDate: '2026-11-13',
            xp: const Value(17),
          ),
        );
    await storeA.importLegacy(legacy, userA);
    require(
      (await accountA.select(accountA.wordProgress).get()).length == 1,
      'Repeat import lost words',
    );
    require(
      (await accountB.select(accountB.wordProgress).get()).isEmpty,
      'Words leaked to another account',
    );
  } finally {
    await accountA.close();
    await accountB.close();
    await legacy.close();
  }
  final reopened = AppDatabase(userId: userA);
  try {
    require(
      (await reopened.select(reopened.userStats).getSingle()).xp == 80,
      'Stats did not persist',
    );
    require(
      (await reopened.select(reopened.wordProgress).get()).length == 1,
      'Words did not persist',
    );
    require(
      (await reopened.select(reopened.lessonProgress).getSingle()).completed,
      'Lesson did not persist',
    );
    require(
      (await reopened.select(reopened.dailyActivities).getSingle()).xp == 17,
      'Daily activity did not persist',
    );
  } finally {
    await reopened.close();
  }
}
