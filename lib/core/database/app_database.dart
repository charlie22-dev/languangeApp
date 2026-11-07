import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'app_database.g.dart';

@DataClassName('LessonProgressRow')
class LessonProgress extends Table {
  TextColumn get lessonId => text()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  IntColumn get bestScore => integer().withDefault(const Constant(0))();
  DateTimeColumn get completedAt => dateTime().nullable()();

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

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (id = 1)',
    'CHECK (xp >= 0)',
    'CHECK (streak >= 0)',
  ];
}

@DriftDatabase(tables: [LessonProgress, WordProgress, UserStats])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'language_learning'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await into(userStats).insert(UserStatsCompanion.insert());
    },
  );
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
