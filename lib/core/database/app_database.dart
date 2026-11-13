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
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

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
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();
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

@DataClassName('DailyActivityRow')
class DailyActivities extends Table {
  TextColumn get activityDate => text()();
  IntColumn get xp => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
  @override
  Set<Column> get primaryKey => {activityDate};
  @override
  List<String> get customConstraints => ['CHECK (xp >= 0)'];
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

@DataClassName('ChatEntryRow')
class ChatEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get scenario => text()();
  TextColumn get role => text()();
  TextColumn get content => text()();
  TextColumn get status => text().withDefault(const Constant('sent'))();
  TextColumn get metadata => text().withDefault(const Constant('{}'))();
}

@DataClassName('SavedVocabularyRow')
class SavedVocabulary extends Table {
  TextColumn get wordId => text()();
  TextColumn get courseId => text()();
  TextColumn get wordText => text().named('text')();
  TextColumn get translation => text()();
  TextColumn get example => text()();
  TextColumn get exampleTranslation => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();
  @override
  Set<Column> get primaryKey => {wordId};
}

@DriftDatabase(
  tables: [
    LessonProgress,
    WordProgress,
    UserStats,
    SyncMetadata,
    LocalProfiles,
    DailyActivities,
    ChatEntries,
    SavedVocabulary,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({String? userId})
    : super(
        driftDatabase(
          name: databaseName(userId),
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  static String databaseName(String? userId) => userId == null
      ? 'language_learning'
      : 'language_learning_${base64Url.encode(utf8.encode(userId)).replaceAll('=', '')}';

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

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
      if (from < 4) {
        await migrator.addColumn(userStats, userStats.longestStreak);
        await migrator.addColumn(wordProgress, wordProgress.deleted);
        await migrator.createTable(dailyActivities);
        await customStatement('UPDATE user_stats SET longest_streak = streak');
      }
      if (from < 5) {
        await migrator.createTable(chatEntries);
        await migrator.createTable(savedVocabulary);
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
