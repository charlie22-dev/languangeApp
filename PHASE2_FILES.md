# Phase 2 - schema and full file contents

Assumption: Japanese for English speakers. The sample has one course, two units,
three lessons per unit, six exercises per lesson, and exactly 60 study entries.
The content models are handwritten. Only Drift database infrastructure is generated.

| JSON object | Required fields | Notes |
| --- | --- | --- |
| Course (root) | schemaVersion, id, title, targetLanguage, nativeLanguage, words[], units[] | schemaVersion is integer 1; language fields are display names |
| Unit | id, title, lessons[] | Ordered lessons |
| Lesson | id, title, wordIds[], exercises[] | wordIds reference course.words IDs |
| Word | id, text, translation, example, exampleTranslation, tags[] | audioUrl is an optional nullable string; tags contain strings |
| MultipleChoice | id, type, prompt, options[], correctIndex | type: multipleChoice; zero-based integer index |
| MatchPairs | id, type, pairs[] | type: matchPairs; each pair has required left and right strings |
| FillInBlank | id, type, sentenceWithBlank, answer, choices[] | type: fillInBlank; one literal ___ marker; answer must be a choice |
| TypeTranslation | id, type, prompt, acceptedAnswers[] | type: typeTranslation; at least one accepted answer |

All IDs and text fields must be nonempty strings. IDs are unique within their
entity type across the course. Required fields cannot be missing or null.
Collections are immutable in Dart, and toJson returns new JSON collections.
Unknown exercise types and unknown course schema versions are rejected.
Sample course shape/count requirements are checked in tests rather than imposed
on every future course by the general-purpose model classes.

bestScore is a percentage (0-100). UserStats adds an internal id fixed to 1 so
there is exactly one local user stats row. completedAt and lastActiveDate are
nullable; word dueDate must be provided. No gameplay or scheduling logic is added.

Run from C:\Langunge_flutter\myapp:

```powershell
flutter pub get
dart run build_runner build
flutter analyze
flutter test
flutter run -d emulator-5554
```

Replace the device ID using flutter devices. Existing Android SDK setup fixes
from Phase 1 still apply. After adding another course, register its asset in
pubspec.yaml and use --dart-define=COURSE_ASSET=assets/courses/your_course.json
or override courseAssetPathProvider. The display TARGET_LANGUAGE setting does
not select or translate the course asset automatically.

The following sections contain all Phase 2 source files, tests, the complete
sample asset, updated pubspec/README, and generated database code.

## lib/core/utils/json_reader.dart

```dart
typedef JsonMap = Map<String, dynamic>;

abstract final class JsonReader {
  static JsonMap object(Object? value, String field) {
    if (value is! JsonMap) throw FormatException('$field must be an object');
    return value;
  }

  static String text(JsonMap json, String field) {
    final value = json[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field must be a nonempty string');
    }
    return value;
  }

  static List<dynamic> list(JsonMap json, String field) {
    final value = json[field];
    if (value is! List) throw FormatException('$field must be an array');
    return value;
  }

  static List<String> strings(JsonMap json, String field) =>
      list(json, field).map((value) => text({field: value}, field)).toList();

  static int integer(JsonMap json, String field) {
    final value = json[field];
    if (value is! int) throw FormatException('$field must be an integer');
    return value;
  }

  static void unique(Iterable<String> values, String field) {
    final seen = <String>{};
    for (final value in values) {
      if (!seen.add(value)) throw FormatException('Duplicate $field: $value');
    }
  }
}
```

## lib/features/flashcards/domain/word.dart

```dart
import '../../../core/utils/json_reader.dart';

final class Word {
  Word({
    required this.id,
    required this.text,
    required this.translation,
    required this.example,
    required this.exampleTranslation,
    this.audioUrl,
    required List<String> tags,
  }) : tags = List.unmodifiable(tags);

  final String id;
  final String text;
  final String translation;
  final String example;
  final String exampleTranslation;
  final String? audioUrl;
  final List<String> tags;

  factory Word.fromJson(JsonMap json) => Word(
    id: JsonReader.text(json, 'id'),
    text: JsonReader.text(json, 'text'),
    translation: JsonReader.text(json, 'translation'),
    example: JsonReader.text(json, 'example'),
    exampleTranslation: JsonReader.text(json, 'exampleTranslation'),
    audioUrl: json['audioUrl'] == null
        ? null
        : JsonReader.text(json, 'audioUrl'),
    tags: JsonReader.strings(json, 'tags'),
  );

  JsonMap toJson() => {
    'id': id,
    'text': text,
    'translation': translation,
    'example': example,
    'exampleTranslation': exampleTranslation,
    if (audioUrl != null) 'audioUrl': audioUrl,
    'tags': tags.toList(),
  };
}
```

## lib/features/exercises/domain/exercise.dart

```dart
import '../../../core/utils/json_reader.dart';

sealed class Exercise {
  const Exercise({required this.id});

  final String id;

  factory Exercise.fromJson(JsonMap json) {
    final id = JsonReader.text(json, 'id');
    return switch (JsonReader.text(json, 'type')) {
      'multipleChoice' => MultipleChoice.fromJson(json),
      'matchPairs' => MatchPairs.fromJson(json),
      'fillInBlank' => FillInBlank.fromJson(json),
      'typeTranslation' => TypeTranslation.fromJson(json),
      final type => throw FormatException('Unknown exercise type $type ($id)'),
    };
  }

  JsonMap toJson();
}

final class MultipleChoice extends Exercise {
  MultipleChoice({
    required super.id,
    required this.prompt,
    required List<String> options,
    required this.correctIndex,
  }) : options = List.unmodifiable(options) {
    if (options.length < 2 ||
        correctIndex < 0 ||
        correctIndex >= options.length) {
      throw const FormatException('Invalid multiple-choice options or index');
    }
    JsonReader.unique(options, 'option');
  }

  final String prompt;
  final List<String> options;
  final int correctIndex;

  factory MultipleChoice.fromJson(JsonMap json) => MultipleChoice(
    id: JsonReader.text(json, 'id'),
    prompt: JsonReader.text(json, 'prompt'),
    options: JsonReader.strings(json, 'options'),
    correctIndex: JsonReader.integer(json, 'correctIndex'),
  );

  @override
  JsonMap toJson() => {
    'id': id,
    'type': 'multipleChoice',
    'prompt': prompt,
    'options': options.toList(),
    'correctIndex': correctIndex,
  };
}

final class MatchPair {
  const MatchPair({required this.left, required this.right});

  final String left;
  final String right;

  factory MatchPair.fromJson(JsonMap json) => MatchPair(
    left: JsonReader.text(json, 'left'),
    right: JsonReader.text(json, 'right'),
  );

  JsonMap toJson() => {'left': left, 'right': right};
}

final class MatchPairs extends Exercise {
  MatchPairs({required super.id, required List<MatchPair> pairs})
    : pairs = List.unmodifiable(pairs) {
    if (pairs.length < 2) {
      throw const FormatException('Need at least two pairs');
    }
    JsonReader.unique(pairs.map((pair) => pair.left), 'pair left side');
    JsonReader.unique(pairs.map((pair) => pair.right), 'pair right side');
  }

  final List<MatchPair> pairs;

  factory MatchPairs.fromJson(JsonMap json) => MatchPairs(
    id: JsonReader.text(json, 'id'),
    pairs: JsonReader.list(json, 'pairs')
        .map((value) => MatchPair.fromJson(JsonReader.object(value, 'pair')))
        .toList(),
  );

  @override
  JsonMap toJson() => {
    'id': id,
    'type': 'matchPairs',
    'pairs': pairs.map((pair) => pair.toJson()).toList(),
  };
}

final class FillInBlank extends Exercise {
  FillInBlank({
    required super.id,
    required this.sentenceWithBlank,
    required this.answer,
    required List<String> choices,
  }) : choices = List.unmodifiable(choices) {
    if ('___'.allMatches(sentenceWithBlank).length != 1 ||
        !choices.contains(answer) ||
        choices.length < 2) {
      throw const FormatException(
        'Need one ___ blank and choices containing answer',
      );
    }
  }

  final String sentenceWithBlank;
  final String answer;
  final List<String> choices;

  factory FillInBlank.fromJson(JsonMap json) => FillInBlank(
    id: JsonReader.text(json, 'id'),
    sentenceWithBlank: JsonReader.text(json, 'sentenceWithBlank'),
    answer: JsonReader.text(json, 'answer'),
    choices: JsonReader.strings(json, 'choices'),
  );

  @override
  JsonMap toJson() => {
    'id': id,
    'type': 'fillInBlank',
    'sentenceWithBlank': sentenceWithBlank,
    'answer': answer,
    'choices': choices.toList(),
  };
}

final class TypeTranslation extends Exercise {
  TypeTranslation({
    required super.id,
    required this.prompt,
    required List<String> acceptedAnswers,
  }) : acceptedAnswers = List.unmodifiable(acceptedAnswers) {
    if (acceptedAnswers.isEmpty) {
      throw const FormatException('acceptedAnswers must not be empty');
    }
  }

  final String prompt;
  final List<String> acceptedAnswers;

  factory TypeTranslation.fromJson(JsonMap json) => TypeTranslation(
    id: JsonReader.text(json, 'id'),
    prompt: JsonReader.text(json, 'prompt'),
    acceptedAnswers: JsonReader.strings(json, 'acceptedAnswers'),
  );

  @override
  JsonMap toJson() => {
    'id': id,
    'type': 'typeTranslation',
    'prompt': prompt,
    'acceptedAnswers': acceptedAnswers.toList(),
  };
}
```

## lib/features/lessons/domain/lesson.dart

```dart
import '../../../core/utils/json_reader.dart';
import '../../exercises/domain/exercise.dart';

final class Lesson {
  Lesson({
    required this.id,
    required this.title,
    required List<String> wordIds,
    required List<Exercise> exercises,
  }) : wordIds = List.unmodifiable(wordIds),
       exercises = List.unmodifiable(exercises);

  final String id;
  final String title;
  final List<String> wordIds;
  final List<Exercise> exercises;

  factory Lesson.fromJson(JsonMap json) => Lesson(
    id: JsonReader.text(json, 'id'),
    title: JsonReader.text(json, 'title'),
    wordIds: JsonReader.strings(json, 'wordIds'),
    exercises: JsonReader.list(json, 'exercises')
        .map((value) => Exercise.fromJson(JsonReader.object(value, 'exercise')))
        .toList(),
  );

  JsonMap toJson() => {
    'id': id,
    'title': title,
    'wordIds': wordIds.toList(),
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
  };
}
```

## lib/features/lessons/domain/unit.dart

```dart
import '../../../core/utils/json_reader.dart';
import 'lesson.dart';

final class Unit {
  Unit({required this.id, required this.title, required List<Lesson> lessons})
    : lessons = List.unmodifiable(lessons);

  final String id;
  final String title;
  final List<Lesson> lessons;

  factory Unit.fromJson(JsonMap json) => Unit(
    id: JsonReader.text(json, 'id'),
    title: JsonReader.text(json, 'title'),
    lessons: JsonReader.list(json, 'lessons')
        .map((value) => Lesson.fromJson(JsonReader.object(value, 'lesson')))
        .toList(),
  );

  JsonMap toJson() => {
    'id': id,
    'title': title,
    'lessons': lessons.map((lesson) => lesson.toJson()).toList(),
  };
}
```

## lib/features/lessons/domain/course.dart

```dart
import '../../../core/utils/json_reader.dart';
import '../../flashcards/domain/word.dart';
import 'unit.dart';

final class Course {
  Course({
    required this.id,
    required this.title,
    required this.targetLanguage,
    required this.nativeLanguage,
    required List<Word> words,
    required List<Unit> units,
  }) : words = List.unmodifiable(words),
       units = List.unmodifiable(units);

  final String id;
  final String title;
  final String targetLanguage;
  final String nativeLanguage;
  final List<Word> words;
  final List<Unit> units;

  factory Course.fromJson(JsonMap json) {
    if (JsonReader.integer(json, 'schemaVersion') != 1) {
      throw const FormatException('Unsupported course schemaVersion');
    }
    final course = Course(
      id: JsonReader.text(json, 'id'),
      title: JsonReader.text(json, 'title'),
      targetLanguage: JsonReader.text(json, 'targetLanguage'),
      nativeLanguage: JsonReader.text(json, 'nativeLanguage'),
      words: JsonReader.list(json, 'words')
          .map((value) => Word.fromJson(JsonReader.object(value, 'word')))
          .toList(),
      units: JsonReader.list(json, 'units')
          .map((value) => Unit.fromJson(JsonReader.object(value, 'unit')))
          .toList(),
    );
    final lessons = course.units.expand((unit) => unit.lessons).toList();
    JsonReader.unique(course.words.map((word) => word.id), 'word ID');
    JsonReader.unique(course.units.map((unit) => unit.id), 'unit ID');
    JsonReader.unique(lessons.map((lesson) => lesson.id), 'lesson ID');
    JsonReader.unique(
      lessons
          .expand((lesson) => lesson.exercises)
          .map((exercise) => exercise.id),
      'exercise ID',
    );
    final wordIds = course.words.map((word) => word.id).toSet();
    for (final lesson in lessons) {
      if (lesson.wordIds.any((id) => !wordIds.contains(id))) {
        throw FormatException('Unknown word reference in ${lesson.id}');
      }
    }
    return course;
  }

  JsonMap toJson() => {
    'schemaVersion': 1,
    'id': id,
    'title': title,
    'targetLanguage': targetLanguage,
    'nativeLanguage': nativeLanguage,
    'words': words.map((word) => word.toJson()).toList(),
    'units': units.map((unit) => unit.toJson()).toList(),
  };
}
```

## lib/features/lessons/data/course_repository.dart

```dart
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/json_reader.dart';
import '../domain/course.dart';

final courseAssetPathProvider = Provider<String>(
  (ref) => const String.fromEnvironment(
    'COURSE_ASSET',
    defaultValue: 'assets/courses/japanese_basics.json',
  ),
);

final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => CourseRepository(bundle: rootBundle),
);

final courseProvider = FutureProvider<Course>((ref) {
  return ref
      .watch(courseRepositoryProvider)
      .loadCourse(ref.watch(courseAssetPathProvider));
});

class CourseRepository {
  const CourseRepository({required this.bundle});

  final AssetBundle bundle;

  Future<Course> loadCourse(String assetPath) async {
    final content = await bundle.loadString(assetPath);
    try {
      return Course.fromJson(JsonReader.object(jsonDecode(content), 'course'));
    } on FormatException catch (error) {
      throw FormatException(
        'Invalid course asset $assetPath: ${error.message}',
      );
    }
  }
}
```

## lib/core/database/app_database.dart

```dart
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
```

## test/course_content_test.dart

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/utils/json_reader.dart';
import 'package:myapp/features/exercises/domain/exercise.dart';
import 'package:myapp/features/flashcards/domain/word.dart';
import 'package:myapp/features/lessons/data/course_repository.dart';
import 'package:myapp/features/lessons/domain/course.dart';
import 'package:myapp/features/lessons/domain/lesson.dart';
import 'package:myapp/features/lessons/domain/unit.dart';

const assetPath = 'assets/courses/japanese_basics.json';

JsonMap readSample() =>
    JsonReader.object(jsonDecode(File(assetPath).readAsStringSync()), 'course');

void checkRequiredFields(
  JsonMap json,
  Object Function(JsonMap) parse,
  Iterable<String> fields,
) {
  for (final field in fields) {
    expect(
      () => parse({...json}..remove(field)),
      throwsFormatException,
      reason: 'Missing $field',
    );
    expect(
      () => parse({...json, field: null}),
      throwsFormatException,
      reason: 'Null $field',
    );
  }
}

class MemoryAssetBundle extends CachingAssetBundle {
  MemoryAssetBundle(this.content);
  final String content;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(utf8.encode(content));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sample has 2 units, 6 lessons, 36 exercises and 60 referenced words',
    () {
      final course = Course.fromJson(readSample());
      expect(course.units, hasLength(2));
      expect(course.words, hasLength(60));
      expect(course.targetLanguage, 'Japanese');
      expect(course.nativeLanguage, 'English');
      final usedWordIds = <String>{};
      final types = <Type>{};
      var exerciseCount = 0;
      for (final unit in course.units) {
        expect(unit.lessons, hasLength(3));
        for (final lesson in unit.lessons) {
          expect(lesson.exercises.length, inInclusiveRange(5, 8));
          expect(lesson.wordIds, hasLength(10));
          usedWordIds.addAll(lesson.wordIds);
          exerciseCount += lesson.exercises.length;
          types.addAll(
            lesson.exercises.map((exercise) => exercise.runtimeType),
          );
        }
      }
      expect(usedWordIds, course.words.map((word) => word.id).toSet());
      expect(exerciseCount, 36);
      expect(types, {MultipleChoice, MatchPairs, FillInBlank, TypeTranslation});
    },
  );

  test('every required field is rejected when missing or null', () {
    final json = readSample();
    checkRequiredFields(json, Course.fromJson, [
      'schemaVersion',
      'id',
      'title',
      'targetLanguage',
      'nativeLanguage',
      'words',
      'units',
    ]);
    for (final value in json['words'] as List) {
      checkRequiredFields(value as JsonMap, Word.fromJson, [
        'id',
        'text',
        'translation',
        'example',
        'exampleTranslation',
        'tags',
      ]);
    }
    for (final unit in json['units'] as List) {
      checkRequiredFields(unit as JsonMap, Unit.fromJson, [
        'id',
        'title',
        'lessons',
      ]);
      for (final lesson in unit['lessons'] as List) {
        checkRequiredFields(lesson as JsonMap, Lesson.fromJson, [
          'id',
          'title',
          'wordIds',
          'exercises',
        ]);
        for (final exercise in lesson['exercises'] as List) {
          final fields = switch (exercise['type']) {
            'multipleChoice' => ['prompt', 'options', 'correctIndex'],
            'matchPairs' => ['pairs'],
            'fillInBlank' => ['sentenceWithBlank', 'answer', 'choices'],
            'typeTranslation' => ['prompt', 'acceptedAnswers'],
            _ => throw StateError('Unexpected exercise'),
          };
          checkRequiredFields(exercise as JsonMap, Exercise.fromJson, [
            'id',
            'type',
            ...fields,
          ]);
          if (exercise['type'] == 'matchPairs') {
            for (final pair in exercise['pairs'] as List) {
              checkRequiredFields(pair as JsonMap, MatchPair.fromJson, [
                'left',
                'right',
              ]);
            }
          }
        }
      }
    }
  });

  test('round trips all models and preserves optional audio', () {
    final json = readSample();
    expect(Course.fromJson(json).toJson(), json);
    final word = (json['words'] as List).first as JsonMap;
    expect(Word.fromJson(word).audioUrl, isNull);
    expect(Word.fromJson({...word, 'audioUrl': null}).audioUrl, isNull);
    final withAudio = {...word, 'audioUrl': 'https://example.org/hello.mp3'};
    expect(Word.fromJson(withAudio).toJson(), withAudio);
  });

  test('model collections cannot be mutated', () {
    final course = Course.fromJson(readSample());
    final lesson = course.units.first.lessons.first;
    expect(() => course.words.clear(), throwsUnsupportedError);
    expect(() => course.units.clear(), throwsUnsupportedError);
    expect(() => course.units.first.lessons.clear(), throwsUnsupportedError);
    expect(() => course.words.first.tags.clear(), throwsUnsupportedError);
    expect(() => lesson.wordIds.clear(), throwsUnsupportedError);
    expect(() => lesson.exercises.clear(), throwsUnsupportedError);
    for (final exercise in lesson.exercises) {
      expect(() {
        switch (exercise) {
          case MultipleChoice():
            exercise.options.clear();
          case MatchPairs():
            exercise.pairs.clear();
          case FillInBlank():
            exercise.choices.clear();
          case TypeTranslation():
            exercise.acceptedAnswers.clear();
        }
      }, throwsUnsupportedError);
    }
    final tags = ['beginner'];
    final word = Word.fromJson({...course.words.first.toJson(), 'tags': tags});
    tags.clear();
    expect(word.tags, ['beginner']);
  });

  test(
    'rejects corrupt types, indexes, blanks, references, versions and IDs',
    () {
      final json = readSample();
      final exercises =
          ((json['units'] as List).first['lessons'] as List).first['exercises']
              as List;
      expect(
        () => Exercise.fromJson({
          ...exercises.first as JsonMap,
          'type': 'unknown',
        }),
        throwsFormatException,
      );
      expect(
        () => Exercise.fromJson({
          ...exercises.first as JsonMap,
          'correctIndex': 99,
        }),
        throwsFormatException,
      );
      expect(
        () => Exercise.fromJson({
          ...exercises.first as JsonMap,
          'options': 'wrong',
        }),
        throwsFormatException,
      );
      expect(
        () => Exercise.fromJson({
          ...exercises[3] as JsonMap,
          'sentenceWithBlank': 'No blank',
        }),
        throwsFormatException,
      );
      expect(
        () => Exercise.fromJson({
          ...exercises[3] as JsonMap,
          'answer': 'missing',
        }),
        throwsFormatException,
      );
      expect(
        () => Exercise.fromJson({
          ...exercises.last as JsonMap,
          'acceptedAnswers': [],
        }),
        throwsFormatException,
      );
      expect(
        () => Course.fromJson({...json, 'schemaVersion': 2}),
        throwsFormatException,
      );
      final invalidRef = readSample();
      invalidRef['units'][0]['lessons'][0]['wordIds'] = ['missing'];
      expect(() => Course.fromJson(invalidRef), throwsFormatException);
      final duplicate = readSample();
      duplicate['words'][1]['id'] = duplicate['words'][0]['id'];
      expect(() => Course.fromJson(duplicate), throwsFormatException);
    },
  );

  test(
    'repository and Riverpod load a course from an injected bundle',
    () async {
      final repository = CourseRepository(
        bundle: MemoryAssetBundle(jsonEncode(readSample())),
      );
      final container = ProviderContainer(
        overrides: [courseRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final course = await container.read(courseProvider.future);
      expect(course.words, hasLength(60));
    },
  );

  test('registered Flutter asset loads using rootBundle', () async {
    final course = await CourseRepository(bundle: rootBundle)
        .loadCourse(assetPath);
    expect(course.id, 'ja_basics_en');
  });

  test('repository errors contain the asset path', () async {
    final repository = CourseRepository(bundle: MemoryAssetBundle('{broken'));
    await expectLater(
      repository.loadCourse(assetPath),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains(assetPath),
        ),
      ),
    );
  });
}
```

## test/app_database_test.dart

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  test('fresh database has a single zeroed stats row', () async {
    final stats = await database.select(database.userStats).getSingle();
    expect(stats.id, 1);
    expect(stats.xp, 0);
    expect(stats.streak, 0);
    expect(stats.lastActiveDate, isNull);
  });

  test(
    'lesson and word progress store requested fields and defaults',
    () async {
      await database
          .into(database.lessonProgress)
          .insert(LessonProgressCompanion.insert(lessonId: 'ja_greetings'));
      final initial = await database
          .select(database.lessonProgress)
          .getSingle();
      expect(initial.completed, isFalse);
      expect(initial.bestScore, 0);
      expect(initial.completedAt, isNull);
      final date = DateTime.utc(2026, 11, 8);
      await database
          .into(database.lessonProgress)
          .insertOnConflictUpdate(
            LessonProgressCompanion.insert(
              lessonId: 'ja_greetings',
              completed: const Value(true),
              bestScore: const Value(90),
              completedAt: Value(date),
            ),
          );
      final completed = await database
          .select(database.lessonProgress)
          .getSingle();
      expect(completed.completed, isTrue);
      expect(completed.bestScore, 90);
      expect(completed.completedAt!.toUtc(), date);
      await database
          .into(database.wordProgress)
          .insert(
            WordProgressCompanion.insert(wordId: 'ja_hello', dueDate: date),
          );
      final word = await database.select(database.wordProgress).getSingle();
      expect(word.wordId, 'ja_hello');
      expect(word.easeFactor, 2.5);
      expect(word.intervalDays, 0);
      expect(word.repetitions, 0);
      expect(word.dueDate.toUtc(), date);
    },
  );

  test(
    'constraints reject invalid scores and multiple stats identities',
    () async {
      await expectLater(
        database
            .into(database.lessonProgress)
            .insert(
              LessonProgressCompanion.insert(
                lessonId: 'bad',
                bestScore: const Value(101),
              ),
            ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        database
            .into(database.userStats)
            .insert(UserStatsCompanion.insert(id: const Value(2))),
        throwsA(isA<Exception>()),
      );
    },
  );
}
```

## pubspec.yaml

```yaml
name: myapp
description: A language-learning app, built phase by phase.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.13.5

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.5.0
  go_router: ^18.1.3
  drift: ^2.35.3
  drift_flutter: ^0.3.1
  shared_preferences: ^2.5.6
  dio: ^5.11.1
  intl: ^0.20.3
  flutter_dotenv: ^6.0.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  drift_dev: ^2.35.2
  build_runner: ^2.17.1
  flutter_lints: ^6.0.0
  mocktail: ^1.0.5

flutter:
  uses-material-design: true
  assets:
    - assets/courses/japanese_basics.json
```

## assets/courses/japanese_basics.json

```json
{
  "schemaVersion": 1,
  "id": "ja_basics_en",
  "title": "Japanese Basics",
  "targetLanguage": "Japanese",
  "nativeLanguage": "English",
  "words": [
    {
      "id": "ja_hello",
      "text": "こんにちは",
      "translation": "hello",
      "example": "こんにちは、せんせい。",
      "exampleTranslation": "Hello, teacher.",
      "tags": [
        "beginner",
        "greetings"
      ]
    },
    {
      "id": "ja_good_morning",
      "text": "おはよう",
      "translation": "good morning",
      "example": "おはよう、みんな。",
      "exampleTranslation": "Good morning, everyone.",
      "tags": [
        "beginner",
        "greetings"
      ]
    },
    {
      "id": "ja_good_evening",
      "text": "こんばんは",
      "translation": "good evening",
      "example": "こんばんは、せんせい。",
      "exampleTranslation": "Good evening, teacher.",
      "tags": [
        "beginner",
        "greetings"
      ]
    },
    {
      "id": "ja_thank_you",
      "text": "ありがとう",
      "translation": "thank you",
      "example": "ありがとう、たすかりました。",
      "exampleTranslation": "Thank you, that helped.",
      "tags": [
        "beginner",
        "greetings"
      ]
    },
    {
      "id": "ja_excuse_me",
      "text": "すみません",
      "translation": "excuse me",
      "example": "すみません、えきは どこですか。",
      "exampleTranslation": "Excuse me, where is the station?",
      "tags": [
        "beginner",
        "greetings"
      ]
    },
    {
      "id": "ja_yes",
      "text": "はい",
      "translation": "yes",
      "example": "はい、そうです。",
      "exampleTranslation": "Yes, that is right.",
      "tags": [
        "beginner",
        "greetings"
      ]
    },
    {
      "id": "ja_no",
      "text": "いいえ",
      "translation": "no",
      "example": "いいえ、ちがいます。",
      "exampleTranslation": "No, that is incorrect.",
      "tags": [
        "beginner",
        "greetings"
      ]
    },
    {
      "id": "ja_goodbye",
      "text": "さようなら",
      "translation": "goodbye",
      "example": "さようなら、せんせい。",
      "exampleTranslation": "Goodbye, teacher.",
      "tags": [
        "beginner",
        "greetings"
      ]
    },
    {
      "id": "ja_see_you",
      "text": "またね",
      "translation": "see you",
      "example": "またね、あした。",
      "exampleTranslation": "See you tomorrow.",
      "tags": [
        "beginner",
        "greetings"
      ]
    },
    {
      "id": "ja_good_night",
      "text": "おやすみ",
      "translation": "good night",
      "example": "おやすみ、また あした。",
      "exampleTranslation": "Good night, see you tomorrow.",
      "tags": [
        "beginner",
        "greetings"
      ]
    },
    {
      "id": "ja_i",
      "text": "わたし",
      "translation": "I",
      "example": "わたしは がくせいです。",
      "exampleTranslation": "I am a student.",
      "tags": [
        "beginner",
        "people"
      ]
    },
    {
      "id": "ja_you",
      "text": "あなた",
      "translation": "you",
      "example": "あなたの なまえは なんですか。",
      "exampleTranslation": "What is your name?",
      "tags": [
        "beginner",
        "people"
      ]
    },
    {
      "id": "ja_friend",
      "text": "ともだち",
      "translation": "friend",
      "example": "ともだちと はなします。",
      "exampleTranslation": "I talk with a friend.",
      "tags": [
        "beginner",
        "people"
      ]
    },
    {
      "id": "ja_family",
      "text": "かぞく",
      "translation": "family",
      "example": "かぞくと ごはんを たべます。",
      "exampleTranslation": "I eat a meal with my family.",
      "tags": [
        "beginner",
        "people"
      ]
    },
    {
      "id": "ja_mother",
      "text": "はは",
      "translation": "my mother",
      "example": "ははは いえに います。",
      "exampleTranslation": "My mother is at home.",
      "tags": [
        "beginner",
        "people"
      ]
    },
    {
      "id": "ja_father",
      "text": "ちち",
      "translation": "my father",
      "example": "ちちは ほんを よみます。",
      "exampleTranslation": "My father reads a book.",
      "tags": [
        "beginner",
        "people"
      ]
    },
    {
      "id": "ja_teacher",
      "text": "せんせい",
      "translation": "teacher",
      "example": "せんせいに ききます。",
      "exampleTranslation": "I ask the teacher.",
      "tags": [
        "beginner",
        "people"
      ]
    },
    {
      "id": "ja_student",
      "text": "がくせい",
      "translation": "student",
      "example": "わたしは がくせいです。",
      "exampleTranslation": "I am a student.",
      "tags": [
        "beginner",
        "people"
      ]
    },
    {
      "id": "ja_child",
      "text": "こども",
      "translation": "child",
      "example": "こどもが こうえんに います。",
      "exampleTranslation": "A child is in the park.",
      "tags": [
        "beginner",
        "people"
      ]
    },
    {
      "id": "ja_name",
      "text": "なまえ",
      "translation": "name",
      "example": "なまえを かいてください。",
      "exampleTranslation": "Please write your name.",
      "tags": [
        "beginner",
        "people"
      ]
    },
    {
      "id": "ja_one",
      "text": "いち",
      "translation": "one",
      "example": "いちと いってください。",
      "exampleTranslation": "Please say one.",
      "tags": [
        "beginner",
        "numbers"
      ]
    },
    {
      "id": "ja_two",
      "text": "に",
      "translation": "two",
      "example": "にと いってください。",
      "exampleTranslation": "Please say two.",
      "tags": [
        "beginner",
        "numbers"
      ]
    },
    {
      "id": "ja_three",
      "text": "さん",
      "translation": "three",
      "example": "さんと いってください。",
      "exampleTranslation": "Please say three.",
      "tags": [
        "beginner",
        "numbers"
      ]
    },
    {
      "id": "ja_four",
      "text": "よん",
      "translation": "four",
      "example": "よんと いってください。",
      "exampleTranslation": "Please say four.",
      "tags": [
        "beginner",
        "numbers"
      ]
    },
    {
      "id": "ja_five",
      "text": "ご",
      "translation": "five",
      "example": "ごと いってください。",
      "exampleTranslation": "Please say five.",
      "tags": [
        "beginner",
        "numbers"
      ]
    },
    {
      "id": "ja_six",
      "text": "ろく",
      "translation": "six",
      "example": "ろくと いってください。",
      "exampleTranslation": "Please say six.",
      "tags": [
        "beginner",
        "numbers"
      ]
    },
    {
      "id": "ja_seven",
      "text": "なな",
      "translation": "seven",
      "example": "ななと いってください。",
      "exampleTranslation": "Please say seven.",
      "tags": [
        "beginner",
        "numbers"
      ]
    },
    {
      "id": "ja_eight",
      "text": "はち",
      "translation": "eight",
      "example": "はちと いってください。",
      "exampleTranslation": "Please say eight.",
      "tags": [
        "beginner",
        "numbers"
      ]
    },
    {
      "id": "ja_nine",
      "text": "きゅう",
      "translation": "nine",
      "example": "きゅうと いってください。",
      "exampleTranslation": "Please say nine.",
      "tags": [
        "beginner",
        "numbers"
      ]
    },
    {
      "id": "ja_ten",
      "text": "じゅう",
      "translation": "ten",
      "example": "じゅうと いってください。",
      "exampleTranslation": "Please say ten.",
      "tags": [
        "beginner",
        "numbers"
      ]
    },
    {
      "id": "ja_water",
      "text": "みず",
      "translation": "water",
      "example": "みずを のみます。",
      "exampleTranslation": "I drink water.",
      "tags": [
        "beginner",
        "food"
      ]
    },
    {
      "id": "ja_tea",
      "text": "おちゃ",
      "translation": "tea",
      "example": "おちゃを のみます。",
      "exampleTranslation": "I drink tea.",
      "tags": [
        "beginner",
        "food"
      ]
    },
    {
      "id": "ja_rice",
      "text": "ごはん",
      "translation": "rice or meal",
      "example": "ごはんを たべます。",
      "exampleTranslation": "I eat rice.",
      "tags": [
        "beginner",
        "food"
      ]
    },
    {
      "id": "ja_bread",
      "text": "パン",
      "translation": "bread",
      "example": "パンを かいます。",
      "exampleTranslation": "I buy bread.",
      "tags": [
        "beginner",
        "food"
      ]
    },
    {
      "id": "ja_apple",
      "text": "りんご",
      "translation": "apple",
      "example": "りんごを たべます。",
      "exampleTranslation": "I eat an apple.",
      "tags": [
        "beginner",
        "food"
      ]
    },
    {
      "id": "ja_fish",
      "text": "さかな",
      "translation": "fish",
      "example": "さかなが すきです。",
      "exampleTranslation": "I like fish.",
      "tags": [
        "beginner",
        "food"
      ]
    },
    {
      "id": "ja_meat",
      "text": "にく",
      "translation": "meat",
      "example": "にくを たべます。",
      "exampleTranslation": "I eat meat.",
      "tags": [
        "beginner",
        "food"
      ]
    },
    {
      "id": "ja_vegetables",
      "text": "やさい",
      "translation": "vegetables",
      "example": "やさいを かいます。",
      "exampleTranslation": "I buy vegetables.",
      "tags": [
        "beginner",
        "food"
      ]
    },
    {
      "id": "ja_egg",
      "text": "たまご",
      "translation": "egg",
      "example": "たまごを たべます。",
      "exampleTranslation": "I eat an egg.",
      "tags": [
        "beginner",
        "food"
      ]
    },
    {
      "id": "ja_milk",
      "text": "ぎゅうにゅう",
      "translation": "milk",
      "example": "ぎゅうにゅうを のみます。",
      "exampleTranslation": "I drink milk.",
      "tags": [
        "beginner",
        "food"
      ]
    },
    {
      "id": "ja_home",
      "text": "いえ",
      "translation": "house or home",
      "example": "いえに かえります。",
      "exampleTranslation": "I return home.",
      "tags": [
        "beginner",
        "places"
      ]
    },
    {
      "id": "ja_school",
      "text": "がっこう",
      "translation": "school",
      "example": "がっこうに いきます。",
      "exampleTranslation": "I go to school.",
      "tags": [
        "beginner",
        "places"
      ]
    },
    {
      "id": "ja_station",
      "text": "えき",
      "translation": "station",
      "example": "えきは どこですか。",
      "exampleTranslation": "Where is the station?",
      "tags": [
        "beginner",
        "places"
      ]
    },
    {
      "id": "ja_shop",
      "text": "みせ",
      "translation": "shop",
      "example": "みせで パンを かいます。",
      "exampleTranslation": "I buy bread at the shop.",
      "tags": [
        "beginner",
        "places"
      ]
    },
    {
      "id": "ja_hospital",
      "text": "びょういん",
      "translation": "hospital",
      "example": "びょういんに いきます。",
      "exampleTranslation": "I go to the hospital.",
      "tags": [
        "beginner",
        "places"
      ]
    },
    {
      "id": "ja_library",
      "text": "としょかん",
      "translation": "library",
      "example": "としょかんで ほんを よみます。",
      "exampleTranslation": "I read a book at the library.",
      "tags": [
        "beginner",
        "places"
      ]
    },
    {
      "id": "ja_park",
      "text": "こうえん",
      "translation": "park",
      "example": "こうえんを さんぽします。",
      "exampleTranslation": "I take a walk in the park.",
      "tags": [
        "beginner",
        "places"
      ]
    },
    {
      "id": "ja_room",
      "text": "へや",
      "translation": "room",
      "example": "へやに います。",
      "exampleTranslation": "I am in the room.",
      "tags": [
        "beginner",
        "places"
      ]
    },
    {
      "id": "ja_restroom",
      "text": "トイレ",
      "translation": "restroom",
      "example": "トイレは どこですか。",
      "exampleTranslation": "Where is the restroom?",
      "tags": [
        "beginner",
        "places"
      ]
    },
    {
      "id": "ja_restaurant",
      "text": "レストラン",
      "translation": "restaurant",
      "example": "レストランで たべます。",
      "exampleTranslation": "I eat at a restaurant.",
      "tags": [
        "beginner",
        "places"
      ]
    },
    {
      "id": "ja_eat",
      "text": "たべる",
      "translation": "to eat",
      "example": "パンを たべる。",
      "exampleTranslation": "I eat bread.",
      "tags": [
        "beginner",
        "actions"
      ]
    },
    {
      "id": "ja_drink",
      "text": "のむ",
      "translation": "to drink",
      "example": "みずを のむ。",
      "exampleTranslation": "I drink water.",
      "tags": [
        "beginner",
        "actions"
      ]
    },
    {
      "id": "ja_go",
      "text": "いく",
      "translation": "to go",
      "example": "がっこうに いく。",
      "exampleTranslation": "I go to school.",
      "tags": [
        "beginner",
        "actions"
      ]
    },
    {
      "id": "ja_come",
      "text": "くる",
      "translation": "to come",
      "example": "ともだちが くる。",
      "exampleTranslation": "A friend comes.",
      "tags": [
        "beginner",
        "actions"
      ]
    },
    {
      "id": "ja_see",
      "text": "みる",
      "translation": "to see or watch",
      "example": "テレビを みる。",
      "exampleTranslation": "I watch television.",
      "tags": [
        "beginner",
        "actions"
      ]
    },
    {
      "id": "ja_listen",
      "text": "きく",
      "translation": "to listen or ask",
      "example": "おんがくを きく。",
      "exampleTranslation": "I listen to music.",
      "tags": [
        "beginner",
        "actions"
      ]
    },
    {
      "id": "ja_speak",
      "text": "はなす",
      "translation": "to speak",
      "example": "にほんごを はなす。",
      "exampleTranslation": "I speak Japanese.",
      "tags": [
        "beginner",
        "actions"
      ]
    },
    {
      "id": "ja_read",
      "text": "よむ",
      "translation": "to read",
      "example": "ほんを よむ。",
      "exampleTranslation": "I read a book.",
      "tags": [
        "beginner",
        "actions"
      ]
    },
    {
      "id": "ja_write",
      "text": "かく",
      "translation": "to write",
      "example": "なまえを かく。",
      "exampleTranslation": "I write my name.",
      "tags": [
        "beginner",
        "actions"
      ]
    },
    {
      "id": "ja_sleep",
      "text": "ねる",
      "translation": "to sleep",
      "example": "よるに ねる。",
      "exampleTranslation": "I sleep at night.",
      "tags": [
        "beginner",
        "actions"
      ]
    }
  ],
  "units": [
    {
      "id": "ja_first_steps",
      "title": "First steps",
      "lessons": [
        {
          "id": "ja_greetings",
          "title": "Greetings and courtesy",
          "wordIds": [
            "ja_hello",
            "ja_good_morning",
            "ja_good_evening",
            "ja_thank_you",
            "ja_excuse_me",
            "ja_yes",
            "ja_no",
            "ja_goodbye",
            "ja_see_you",
            "ja_good_night"
          ],
          "exercises": [
            {
              "id": "ja_greetings_01",
              "type": "multipleChoice",
              "prompt": "What does こんにちは mean?",
              "options": [
                "hello",
                "good morning",
                "good evening"
              ],
              "correctIndex": 0
            },
            {
              "id": "ja_greetings_02",
              "type": "multipleChoice",
              "prompt": "Choose the Japanese for: good morning",
              "options": [
                "ありがとう",
                "こんにちは",
                "おはよう"
              ],
              "correctIndex": 2
            },
            {
              "id": "ja_greetings_03",
              "type": "matchPairs",
              "pairs": [
                {
                  "left": "こんばんは",
                  "right": "good evening"
                },
                {
                  "left": "ありがとう",
                  "right": "thank you"
                },
                {
                  "left": "すみません",
                  "right": "excuse me"
                },
                {
                  "left": "はい",
                  "right": "yes"
                },
                {
                  "left": "おやすみ",
                  "right": "good night"
                }
              ]
            },
            {
              "id": "ja_greetings_04",
              "type": "fillInBlank",
              "sentenceWithBlank": "___、ちがいます。 (No, that is incorrect.)",
              "answer": "いいえ",
              "choices": [
                "はい",
                "いいえ",
                "さようなら"
              ]
            },
            {
              "id": "ja_greetings_05",
              "type": "fillInBlank",
              "sentenceWithBlank": "___、せんせい。 (Goodbye, teacher.)",
              "answer": "さようなら",
              "choices": [
                "さようなら",
                "またね",
                "おやすみ"
              ]
            },
            {
              "id": "ja_greetings_06",
              "type": "typeTranslation",
              "prompt": "Translate into Japanese: see you",
              "acceptedAnswers": [
                "またね"
              ]
            }
          ]
        },
        {
          "id": "ja_people",
          "title": "People and family",
          "wordIds": [
            "ja_i",
            "ja_you",
            "ja_friend",
            "ja_family",
            "ja_mother",
            "ja_father",
            "ja_teacher",
            "ja_student",
            "ja_child",
            "ja_name"
          ],
          "exercises": [
            {
              "id": "ja_people_01",
              "type": "multipleChoice",
              "prompt": "What does わたし mean?",
              "options": [
                "I",
                "you",
                "friend"
              ],
              "correctIndex": 0
            },
            {
              "id": "ja_people_02",
              "type": "multipleChoice",
              "prompt": "Choose the Japanese for: you",
              "options": [
                "かぞく",
                "わたし",
                "あなた"
              ],
              "correctIndex": 2
            },
            {
              "id": "ja_people_03",
              "type": "matchPairs",
              "pairs": [
                {
                  "left": "ともだち",
                  "right": "friend"
                },
                {
                  "left": "かぞく",
                  "right": "family"
                },
                {
                  "left": "はは",
                  "right": "my mother"
                },
                {
                  "left": "ちち",
                  "right": "my father"
                },
                {
                  "left": "なまえ",
                  "right": "name"
                }
              ]
            },
            {
              "id": "ja_people_04",
              "type": "fillInBlank",
              "sentenceWithBlank": "___に ききます。 (I ask the teacher.)",
              "answer": "せんせい",
              "choices": [
                "ちち",
                "せんせい",
                "がくせい"
              ]
            },
            {
              "id": "ja_people_05",
              "type": "fillInBlank",
              "sentenceWithBlank": "わたしは ___です。 (I am a student.)",
              "answer": "がくせい",
              "choices": [
                "がくせい",
                "こども",
                "なまえ"
              ]
            },
            {
              "id": "ja_people_06",
              "type": "typeTranslation",
              "prompt": "Translate into Japanese: child",
              "acceptedAnswers": [
                "こども"
              ]
            }
          ]
        },
        {
          "id": "ja_numbers",
          "title": "Numbers one to ten",
          "wordIds": [
            "ja_one",
            "ja_two",
            "ja_three",
            "ja_four",
            "ja_five",
            "ja_six",
            "ja_seven",
            "ja_eight",
            "ja_nine",
            "ja_ten"
          ],
          "exercises": [
            {
              "id": "ja_numbers_01",
              "type": "multipleChoice",
              "prompt": "What does いち mean?",
              "options": [
                "one",
                "two",
                "three"
              ],
              "correctIndex": 0
            },
            {
              "id": "ja_numbers_02",
              "type": "multipleChoice",
              "prompt": "Choose the Japanese for: two",
              "options": [
                "よん",
                "いち",
                "に"
              ],
              "correctIndex": 2
            },
            {
              "id": "ja_numbers_03",
              "type": "matchPairs",
              "pairs": [
                {
                  "left": "さん",
                  "right": "three"
                },
                {
                  "left": "よん",
                  "right": "four"
                },
                {
                  "left": "ご",
                  "right": "five"
                },
                {
                  "left": "ろく",
                  "right": "six"
                },
                {
                  "left": "じゅう",
                  "right": "ten"
                }
              ]
            },
            {
              "id": "ja_numbers_04",
              "type": "fillInBlank",
              "sentenceWithBlank": "___と いってください。 (Please say seven.)",
              "answer": "なな",
              "choices": [
                "ろく",
                "なな",
                "はち"
              ]
            },
            {
              "id": "ja_numbers_05",
              "type": "fillInBlank",
              "sentenceWithBlank": "___と いってください。 (Please say eight.)",
              "answer": "はち",
              "choices": [
                "はち",
                "きゅう",
                "じゅう"
              ]
            },
            {
              "id": "ja_numbers_06",
              "type": "typeTranslation",
              "prompt": "Translate into Japanese: nine",
              "acceptedAnswers": [
                "きゅう"
              ]
            }
          ]
        }
      ]
    },
    {
      "id": "ja_daily_life",
      "title": "Daily life",
      "lessons": [
        {
          "id": "ja_food",
          "title": "Food and drinks",
          "wordIds": [
            "ja_water",
            "ja_tea",
            "ja_rice",
            "ja_bread",
            "ja_apple",
            "ja_fish",
            "ja_meat",
            "ja_vegetables",
            "ja_egg",
            "ja_milk"
          ],
          "exercises": [
            {
              "id": "ja_food_01",
              "type": "multipleChoice",
              "prompt": "What does みず mean?",
              "options": [
                "water",
                "tea",
                "rice or meal"
              ],
              "correctIndex": 0
            },
            {
              "id": "ja_food_02",
              "type": "multipleChoice",
              "prompt": "Choose the Japanese for: tea",
              "options": [
                "パン",
                "みず",
                "おちゃ"
              ],
              "correctIndex": 2
            },
            {
              "id": "ja_food_03",
              "type": "matchPairs",
              "pairs": [
                {
                  "left": "ごはん",
                  "right": "rice or meal"
                },
                {
                  "left": "パン",
                  "right": "bread"
                },
                {
                  "left": "りんご",
                  "right": "apple"
                },
                {
                  "left": "さかな",
                  "right": "fish"
                },
                {
                  "left": "ぎゅうにゅう",
                  "right": "milk"
                }
              ]
            },
            {
              "id": "ja_food_04",
              "type": "fillInBlank",
              "sentenceWithBlank": "___を たべます。 (I eat meat.)",
              "answer": "にく",
              "choices": [
                "さかな",
                "にく",
                "やさい"
              ]
            },
            {
              "id": "ja_food_05",
              "type": "fillInBlank",
              "sentenceWithBlank": "___を かいます。 (I buy vegetables.)",
              "answer": "やさい",
              "choices": [
                "やさい",
                "たまご",
                "ぎゅうにゅう"
              ]
            },
            {
              "id": "ja_food_06",
              "type": "typeTranslation",
              "prompt": "Translate into Japanese: egg",
              "acceptedAnswers": [
                "たまご"
              ]
            }
          ]
        },
        {
          "id": "ja_places",
          "title": "Places around town",
          "wordIds": [
            "ja_home",
            "ja_school",
            "ja_station",
            "ja_shop",
            "ja_hospital",
            "ja_library",
            "ja_park",
            "ja_room",
            "ja_restroom",
            "ja_restaurant"
          ],
          "exercises": [
            {
              "id": "ja_places_01",
              "type": "multipleChoice",
              "prompt": "What does いえ mean?",
              "options": [
                "house or home",
                "school",
                "station"
              ],
              "correctIndex": 0
            },
            {
              "id": "ja_places_02",
              "type": "multipleChoice",
              "prompt": "Choose the Japanese for: school",
              "options": [
                "みせ",
                "いえ",
                "がっこう"
              ],
              "correctIndex": 2
            },
            {
              "id": "ja_places_03",
              "type": "matchPairs",
              "pairs": [
                {
                  "left": "えき",
                  "right": "station"
                },
                {
                  "left": "みせ",
                  "right": "shop"
                },
                {
                  "left": "びょういん",
                  "right": "hospital"
                },
                {
                  "left": "としょかん",
                  "right": "library"
                },
                {
                  "left": "レストラン",
                  "right": "restaurant"
                }
              ]
            },
            {
              "id": "ja_places_04",
              "type": "fillInBlank",
              "sentenceWithBlank": "___を さんぽします。 (I take a walk in the park.)",
              "answer": "こうえん",
              "choices": [
                "としょかん",
                "こうえん",
                "へや"
              ]
            },
            {
              "id": "ja_places_05",
              "type": "fillInBlank",
              "sentenceWithBlank": "___に います。 (I am in the room.)",
              "answer": "へや",
              "choices": [
                "へや",
                "トイレ",
                "レストラン"
              ]
            },
            {
              "id": "ja_places_06",
              "type": "typeTranslation",
              "prompt": "Translate into Japanese: restroom",
              "acceptedAnswers": [
                "トイレ"
              ]
            }
          ]
        },
        {
          "id": "ja_actions",
          "title": "Everyday actions",
          "wordIds": [
            "ja_eat",
            "ja_drink",
            "ja_go",
            "ja_come",
            "ja_see",
            "ja_listen",
            "ja_speak",
            "ja_read",
            "ja_write",
            "ja_sleep"
          ],
          "exercises": [
            {
              "id": "ja_actions_01",
              "type": "multipleChoice",
              "prompt": "What does たべる mean?",
              "options": [
                "to eat",
                "to drink",
                "to go"
              ],
              "correctIndex": 0
            },
            {
              "id": "ja_actions_02",
              "type": "multipleChoice",
              "prompt": "Choose the Japanese for: to drink",
              "options": [
                "くる",
                "たべる",
                "のむ"
              ],
              "correctIndex": 2
            },
            {
              "id": "ja_actions_03",
              "type": "matchPairs",
              "pairs": [
                {
                  "left": "いく",
                  "right": "to go"
                },
                {
                  "left": "くる",
                  "right": "to come"
                },
                {
                  "left": "みる",
                  "right": "to see or watch"
                },
                {
                  "left": "きく",
                  "right": "to listen or ask"
                },
                {
                  "left": "ねる",
                  "right": "to sleep"
                }
              ]
            },
            {
              "id": "ja_actions_04",
              "type": "fillInBlank",
              "sentenceWithBlank": "にほんごを ___。 (I speak Japanese.)",
              "answer": "はなす",
              "choices": [
                "きく",
                "はなす",
                "よむ"
              ]
            },
            {
              "id": "ja_actions_05",
              "type": "fillInBlank",
              "sentenceWithBlank": "ほんを ___。 (I read a book.)",
              "answer": "よむ",
              "choices": [
                "よむ",
                "かく",
                "ねる"
              ]
            },
            {
              "id": "ja_actions_06",
              "type": "typeTranslation",
              "prompt": "Translate into Japanese: to write",
              "acceptedAnswers": [
                "かく"
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

## README.md

````markdown
# Language learning app - Phases 1 and 2

This project contains Material 3 light/dark themes, Riverpod, go_router, and
placeholder routes for welcome, Learn, lesson details, Review, and Profile.
Phase 2 adds course content, immutable models, asset loading, and Drift tables.
Backend integration and learning logic belong to later phases.

## Create a separate project

Replace MYHANDLE and app_name before running. Keep app_name lowercase_with_underscores.
Do not recreate the existing project to run it.

```powershell
flutter doctor -v
flutter create --org com.MYHANDLE --project-name app_name app_name
cd app_name
```

The existing project keeps package name myapp and its existing native identifiers.
Changing the org flag only affects newly created projects. In another package,
replace package:myapp/ imports in tests with package:app_name/.

## Android setup and run

Your current doctor output reports missing Android SDK Command-line Tools and
unknown Android license status. In Android Studio, open Tools > SDK Manager >
SDK Tools, install Android SDK Command-line Tools (latest), and then run:

```powershell
flutter doctor --android-licenses
flutter doctor -v
cd C:\Langunge_flutter\myapp
flutter pub get
flutter emulators
flutter emulators --launch Medium_Phone_API_37.0
flutter devices
```

Wait until the emulator boots. Use the Android device ID printed by flutter devices
(e.g. emulator-5554, which can vary):

```powershell
flutter run -d emulator-5554 --dart-define="APP_NAME=My Language App" --dart-define="TARGET_LANGUAGE=Japanese" --dart-define="NATIVE_LANGUAGE=English"
```

Press r for hot reload, R for hot restart, and q to quit. Change dart-defines by
stopping and rerunning. AppConfig uses dart-defines; flutter_dotenv is installed
but no .env file or asset registration is needed in this phase.
Client configuration is not a place for private server credentials.

## Verify

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Widget tests cover welcome configuration, all bottom tabs, lesson IDs, back
navigation, direct routes, an unknown route, and 320x568 layouts at 200% text
scale in both light and dark themes. An Android build has not been verified.

## Structure

- lib/app: root app widget.
- lib/core/config: compile-time configuration.
- lib/core/theme: shared ColorScheme and typography.
- lib/core/constants: route constants.
- lib/core/router: go_router configuration.
- lib/core/utils: reserved for shared utilities.
- lib/features/{onboarding,home,lessons,exercises,flashcards,profile}/:
  each feature has data, domain, and presentation folders.
- lib/shared/widgets: reusable widgets.

Empty folders have empty .gitkeep files so Git can retain them.
ProviderScope supplies Riverpod providers, much like React context.
ConsumerWidget can watch those providers and rebuild when their values change.
StatefulShellRoute.indexedStack keeps each bottom tab's navigation state.
context.go changes location; context.push stacks a page so Back returns to Learn.
ThemeMode.system follows the device light/dark setting. The text theme inherits
platform fonts, then customizes weights and line heights.

## Dependencies and Git

Direct dependency versions were checked against pub.dev's latest stable metadata.
drift_dev and build_runner are dev dependencies for the Drift database generator;
see the Phase 2 commands below to regenerate it after schema edits.
Commit pubspec.lock in this application to reproduce resolved dependencies.
.gitignore excludes build output, local env files, SDK paths, and signing files.
This directory currently has no Git repository; initialize one when ready.
See PHASE1_FILES.md for complete setup file contents and the dependency lockfile.

## Phase 2: content and persistence

Sample language assumption: Japanese for English speakers. The registered asset
is assets/courses/japanese_basics.json: 1 course, 2 units, 3 lessons per unit,
6 exercises per lesson, and 60 common words/phrases (10 per lesson). Topics are
greetings, people, numbers, food, places, and actions. Example sentences may
include supporting vocabulary beyond the 60 study entries. Audio URLs are optional
and omitted because no recordings have been supplied.

All content models are handwritten immutable classes. Their lists are copied
into unmodifiable lists, and fromJson rejects missing/invalid required fields.
Exercises use a sealed hierarchy with a type discriminator in JSON.

CourseRepository loads the Flutter asset through an injectable AssetBundle.
courseProvider is a FutureProvider<Course>, so consumers receive an AsyncValue
that represents loading, data, or an error. No lesson screen is connected yet.
The sample path can be overridden via COURSE_ASSET using --dart-define; any
replacement asset must also be registered in pubspec.yaml. App display language
configuration does not translate or select content automatically.

The Drift database lives in lib/core/database/app_database.dart and is exposed
through appDatabaseProvider. It opens lazily when a consumer first queries it.
Only Drift infrastructure uses code generation; the content models do not.
Tables use IDs matching content IDs, but no SQL foreign keys reference the JSON
asset. Word dueDate is required; completedAt and lastActiveDate are nullable.
bestScore is a percentage from 0 to 100. UserStats adds an internal primary key
restricted to 1, ensuring one local user's stats row, initialized on creation.
No XP, streak, scoring, or spaced-repetition algorithms are implemented yet.

After editing the database schema, regenerate its code:

```powershell
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

Keep app_database.g.dart with the source, and do not edit it manually. Schema
version is 1; later schema changes will need a version bump and a migration.
The native database setup targets Android/iOS/desktop; running the database on
web requires Drift's separate web worker/WASM setup in a later phase.

Tests check every required sample field for missing and null values, JSON round
trips, optional audio, immutable collections, exercise validation, duplicate IDs,
broken word references, injected/registered asset loading, database defaults,
progress round trips, and database constraints. SQLite tests use an in-memory DB.
See PHASE2_FILES.md for the short JSON schema table and every Phase 2 file in full.
````

## lib/core/database/app_database.g.dart

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LessonProgressTable extends LessonProgress
    with TableInfo<$LessonProgressTable, LessonProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LessonProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<String> lessonId = GeneratedColumn<String>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _bestScoreMeta = const VerificationMeta(
    'bestScore',
  );
  @override
  late final GeneratedColumn<int> bestScore = GeneratedColumn<int>(
    'best_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    lessonId,
    completed,
    bestScore,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lesson_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<LessonProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('best_score')) {
      context.handle(
        _bestScoreMeta,
        bestScore.isAcceptableOrUnknown(data['best_score']!, _bestScoreMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {lessonId};
  @override
  LessonProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LessonProgressRow(
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lesson_id'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      bestScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}best_score'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $LessonProgressTable createAlias(String alias) {
    return $LessonProgressTable(attachedDatabase, alias);
  }
}

class LessonProgressRow extends DataClass
    implements Insertable<LessonProgressRow> {
  final String lessonId;
  final bool completed;
  final int bestScore;
  final DateTime? completedAt;
  const LessonProgressRow({
    required this.lessonId,
    required this.completed,
    required this.bestScore,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['lesson_id'] = Variable<String>(lessonId);
    map['completed'] = Variable<bool>(completed);
    map['best_score'] = Variable<int>(bestScore);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  LessonProgressCompanion toCompanion(bool nullToAbsent) {
    return LessonProgressCompanion(
      lessonId: Value(lessonId),
      completed: Value(completed),
      bestScore: Value(bestScore),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory LessonProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LessonProgressRow(
      lessonId: serializer.fromJson<String>(json['lessonId']),
      completed: serializer.fromJson<bool>(json['completed']),
      bestScore: serializer.fromJson<int>(json['bestScore']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'lessonId': serializer.toJson<String>(lessonId),
      'completed': serializer.toJson<bool>(completed),
      'bestScore': serializer.toJson<int>(bestScore),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  LessonProgressRow copyWith({
    String? lessonId,
    bool? completed,
    int? bestScore,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => LessonProgressRow(
    lessonId: lessonId ?? this.lessonId,
    completed: completed ?? this.completed,
    bestScore: bestScore ?? this.bestScore,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  LessonProgressRow copyWithCompanion(LessonProgressCompanion data) {
    return LessonProgressRow(
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      completed: data.completed.present ? data.completed.value : this.completed,
      bestScore: data.bestScore.present ? data.bestScore.value : this.bestScore,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LessonProgressRow(')
          ..write('lessonId: $lessonId, ')
          ..write('completed: $completed, ')
          ..write('bestScore: $bestScore, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(lessonId, completed, bestScore, completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LessonProgressRow &&
          other.lessonId == this.lessonId &&
          other.completed == this.completed &&
          other.bestScore == this.bestScore &&
          other.completedAt == this.completedAt);
}

class LessonProgressCompanion extends UpdateCompanion<LessonProgressRow> {
  final Value<String> lessonId;
  final Value<bool> completed;
  final Value<int> bestScore;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const LessonProgressCompanion({
    this.lessonId = const Value.absent(),
    this.completed = const Value.absent(),
    this.bestScore = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LessonProgressCompanion.insert({
    required String lessonId,
    this.completed = const Value.absent(),
    this.bestScore = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : lessonId = Value(lessonId);
  static Insertable<LessonProgressRow> custom({
    Expression<String>? lessonId,
    Expression<bool>? completed,
    Expression<int>? bestScore,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (lessonId != null) 'lesson_id': lessonId,
      if (completed != null) 'completed': completed,
      if (bestScore != null) 'best_score': bestScore,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LessonProgressCompanion copyWith({
    Value<String>? lessonId,
    Value<bool>? completed,
    Value<int>? bestScore,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return LessonProgressCompanion(
      lessonId: lessonId ?? this.lessonId,
      completed: completed ?? this.completed,
      bestScore: bestScore ?? this.bestScore,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (lessonId.present) {
      map['lesson_id'] = Variable<String>(lessonId.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (bestScore.present) {
      map['best_score'] = Variable<int>(bestScore.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LessonProgressCompanion(')
          ..write('lessonId: $lessonId, ')
          ..write('completed: $completed, ')
          ..write('bestScore: $bestScore, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WordProgressTable extends WordProgress
    with TableInfo<$WordProgressTable, WordProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _wordIdMeta = const VerificationMeta('wordId');
  @override
  late final GeneratedColumn<String> wordId = GeneratedColumn<String>(
    'word_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _easeFactorMeta = const VerificationMeta(
    'easeFactor',
  );
  @override
  late final GeneratedColumn<double> easeFactor = GeneratedColumn<double>(
    'ease_factor',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(2.5),
  );
  static const VerificationMeta _intervalDaysMeta = const VerificationMeta(
    'intervalDays',
  );
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
    'interval_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _repetitionsMeta = const VerificationMeta(
    'repetitions',
  );
  @override
  late final GeneratedColumn<int> repetitions = GeneratedColumn<int>(
    'repetitions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    wordId,
    easeFactor,
    intervalDays,
    repetitions,
    dueDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'word_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<WordProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word_id')) {
      context.handle(
        _wordIdMeta,
        wordId.isAcceptableOrUnknown(data['word_id']!, _wordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_wordIdMeta);
    }
    if (data.containsKey('ease_factor')) {
      context.handle(
        _easeFactorMeta,
        easeFactor.isAcceptableOrUnknown(data['ease_factor']!, _easeFactorMeta),
      );
    }
    if (data.containsKey('interval_days')) {
      context.handle(
        _intervalDaysMeta,
        intervalDays.isAcceptableOrUnknown(
          data['interval_days']!,
          _intervalDaysMeta,
        ),
      );
    }
    if (data.containsKey('repetitions')) {
      context.handle(
        _repetitionsMeta,
        repetitions.isAcceptableOrUnknown(
          data['repetitions']!,
          _repetitionsMeta,
        ),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    } else if (isInserting) {
      context.missing(_dueDateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {wordId};
  @override
  WordProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordProgressRow(
      wordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_id'],
      )!,
      easeFactor: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ease_factor'],
      )!,
      intervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_days'],
      )!,
      repetitions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repetitions'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      )!,
    );
  }

  @override
  $WordProgressTable createAlias(String alias) {
    return $WordProgressTable(attachedDatabase, alias);
  }
}

class WordProgressRow extends DataClass implements Insertable<WordProgressRow> {
  final String wordId;
  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final DateTime dueDate;
  const WordProgressRow({
    required this.wordId,
    required this.easeFactor,
    required this.intervalDays,
    required this.repetitions,
    required this.dueDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['word_id'] = Variable<String>(wordId);
    map['ease_factor'] = Variable<double>(easeFactor);
    map['interval_days'] = Variable<int>(intervalDays);
    map['repetitions'] = Variable<int>(repetitions);
    map['due_date'] = Variable<DateTime>(dueDate);
    return map;
  }

  WordProgressCompanion toCompanion(bool nullToAbsent) {
    return WordProgressCompanion(
      wordId: Value(wordId),
      easeFactor: Value(easeFactor),
      intervalDays: Value(intervalDays),
      repetitions: Value(repetitions),
      dueDate: Value(dueDate),
    );
  }

  factory WordProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordProgressRow(
      wordId: serializer.fromJson<String>(json['wordId']),
      easeFactor: serializer.fromJson<double>(json['easeFactor']),
      intervalDays: serializer.fromJson<int>(json['intervalDays']),
      repetitions: serializer.fromJson<int>(json['repetitions']),
      dueDate: serializer.fromJson<DateTime>(json['dueDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'wordId': serializer.toJson<String>(wordId),
      'easeFactor': serializer.toJson<double>(easeFactor),
      'intervalDays': serializer.toJson<int>(intervalDays),
      'repetitions': serializer.toJson<int>(repetitions),
      'dueDate': serializer.toJson<DateTime>(dueDate),
    };
  }

  WordProgressRow copyWith({
    String? wordId,
    double? easeFactor,
    int? intervalDays,
    int? repetitions,
    DateTime? dueDate,
  }) => WordProgressRow(
    wordId: wordId ?? this.wordId,
    easeFactor: easeFactor ?? this.easeFactor,
    intervalDays: intervalDays ?? this.intervalDays,
    repetitions: repetitions ?? this.repetitions,
    dueDate: dueDate ?? this.dueDate,
  );
  WordProgressRow copyWithCompanion(WordProgressCompanion data) {
    return WordProgressRow(
      wordId: data.wordId.present ? data.wordId.value : this.wordId,
      easeFactor: data.easeFactor.present
          ? data.easeFactor.value
          : this.easeFactor,
      intervalDays: data.intervalDays.present
          ? data.intervalDays.value
          : this.intervalDays,
      repetitions: data.repetitions.present
          ? data.repetitions.value
          : this.repetitions,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordProgressRow(')
          ..write('wordId: $wordId, ')
          ..write('easeFactor: $easeFactor, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('repetitions: $repetitions, ')
          ..write('dueDate: $dueDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(wordId, easeFactor, intervalDays, repetitions, dueDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordProgressRow &&
          other.wordId == this.wordId &&
          other.easeFactor == this.easeFactor &&
          other.intervalDays == this.intervalDays &&
          other.repetitions == this.repetitions &&
          other.dueDate == this.dueDate);
}

class WordProgressCompanion extends UpdateCompanion<WordProgressRow> {
  final Value<String> wordId;
  final Value<double> easeFactor;
  final Value<int> intervalDays;
  final Value<int> repetitions;
  final Value<DateTime> dueDate;
  final Value<int> rowid;
  const WordProgressCompanion({
    this.wordId = const Value.absent(),
    this.easeFactor = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.repetitions = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WordProgressCompanion.insert({
    required String wordId,
    this.easeFactor = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.repetitions = const Value.absent(),
    required DateTime dueDate,
    this.rowid = const Value.absent(),
  }) : wordId = Value(wordId),
       dueDate = Value(dueDate);
  static Insertable<WordProgressRow> custom({
    Expression<String>? wordId,
    Expression<double>? easeFactor,
    Expression<int>? intervalDays,
    Expression<int>? repetitions,
    Expression<DateTime>? dueDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (wordId != null) 'word_id': wordId,
      if (easeFactor != null) 'ease_factor': easeFactor,
      if (intervalDays != null) 'interval_days': intervalDays,
      if (repetitions != null) 'repetitions': repetitions,
      if (dueDate != null) 'due_date': dueDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordProgressCompanion copyWith({
    Value<String>? wordId,
    Value<double>? easeFactor,
    Value<int>? intervalDays,
    Value<int>? repetitions,
    Value<DateTime>? dueDate,
    Value<int>? rowid,
  }) {
    return WordProgressCompanion(
      wordId: wordId ?? this.wordId,
      easeFactor: easeFactor ?? this.easeFactor,
      intervalDays: intervalDays ?? this.intervalDays,
      repetitions: repetitions ?? this.repetitions,
      dueDate: dueDate ?? this.dueDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (wordId.present) {
      map['word_id'] = Variable<String>(wordId.value);
    }
    if (easeFactor.present) {
      map['ease_factor'] = Variable<double>(easeFactor.value);
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    if (repetitions.present) {
      map['repetitions'] = Variable<int>(repetitions.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordProgressCompanion(')
          ..write('wordId: $wordId, ')
          ..write('easeFactor: $easeFactor, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('repetitions: $repetitions, ')
          ..write('dueDate: $dueDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserStatsTable extends UserStats
    with TableInfo<$UserStatsTable, UserStatsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _xpMeta = const VerificationMeta('xp');
  @override
  late final GeneratedColumn<int> xp = GeneratedColumn<int>(
    'xp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _streakMeta = const VerificationMeta('streak');
  @override
  late final GeneratedColumn<int> streak = GeneratedColumn<int>(
    'streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastActiveDateMeta = const VerificationMeta(
    'lastActiveDate',
  );
  @override
  late final GeneratedColumn<DateTime> lastActiveDate =
      GeneratedColumn<DateTime>(
        'last_active_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [id, xp, streak, lastActiveDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserStatsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('xp')) {
      context.handle(_xpMeta, xp.isAcceptableOrUnknown(data['xp']!, _xpMeta));
    }
    if (data.containsKey('streak')) {
      context.handle(
        _streakMeta,
        streak.isAcceptableOrUnknown(data['streak']!, _streakMeta),
      );
    }
    if (data.containsKey('last_active_date')) {
      context.handle(
        _lastActiveDateMeta,
        lastActiveDate.isAcceptableOrUnknown(
          data['last_active_date']!,
          _lastActiveDateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserStatsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserStatsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      xp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}xp'],
      )!,
      streak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}streak'],
      )!,
      lastActiveDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_active_date'],
      ),
    );
  }

  @override
  $UserStatsTable createAlias(String alias) {
    return $UserStatsTable(attachedDatabase, alias);
  }
}

class UserStatsRow extends DataClass implements Insertable<UserStatsRow> {
  final int id;
  final int xp;
  final int streak;
  final DateTime? lastActiveDate;
  const UserStatsRow({
    required this.id,
    required this.xp,
    required this.streak,
    this.lastActiveDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['xp'] = Variable<int>(xp);
    map['streak'] = Variable<int>(streak);
    if (!nullToAbsent || lastActiveDate != null) {
      map['last_active_date'] = Variable<DateTime>(lastActiveDate);
    }
    return map;
  }

  UserStatsCompanion toCompanion(bool nullToAbsent) {
    return UserStatsCompanion(
      id: Value(id),
      xp: Value(xp),
      streak: Value(streak),
      lastActiveDate: lastActiveDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastActiveDate),
    );
  }

  factory UserStatsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserStatsRow(
      id: serializer.fromJson<int>(json['id']),
      xp: serializer.fromJson<int>(json['xp']),
      streak: serializer.fromJson<int>(json['streak']),
      lastActiveDate: serializer.fromJson<DateTime?>(json['lastActiveDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'xp': serializer.toJson<int>(xp),
      'streak': serializer.toJson<int>(streak),
      'lastActiveDate': serializer.toJson<DateTime?>(lastActiveDate),
    };
  }

  UserStatsRow copyWith({
    int? id,
    int? xp,
    int? streak,
    Value<DateTime?> lastActiveDate = const Value.absent(),
  }) => UserStatsRow(
    id: id ?? this.id,
    xp: xp ?? this.xp,
    streak: streak ?? this.streak,
    lastActiveDate: lastActiveDate.present
        ? lastActiveDate.value
        : this.lastActiveDate,
  );
  UserStatsRow copyWithCompanion(UserStatsCompanion data) {
    return UserStatsRow(
      id: data.id.present ? data.id.value : this.id,
      xp: data.xp.present ? data.xp.value : this.xp,
      streak: data.streak.present ? data.streak.value : this.streak,
      lastActiveDate: data.lastActiveDate.present
          ? data.lastActiveDate.value
          : this.lastActiveDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserStatsRow(')
          ..write('id: $id, ')
          ..write('xp: $xp, ')
          ..write('streak: $streak, ')
          ..write('lastActiveDate: $lastActiveDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, xp, streak, lastActiveDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserStatsRow &&
          other.id == this.id &&
          other.xp == this.xp &&
          other.streak == this.streak &&
          other.lastActiveDate == this.lastActiveDate);
}

class UserStatsCompanion extends UpdateCompanion<UserStatsRow> {
  final Value<int> id;
  final Value<int> xp;
  final Value<int> streak;
  final Value<DateTime?> lastActiveDate;
  const UserStatsCompanion({
    this.id = const Value.absent(),
    this.xp = const Value.absent(),
    this.streak = const Value.absent(),
    this.lastActiveDate = const Value.absent(),
  });
  UserStatsCompanion.insert({
    this.id = const Value.absent(),
    this.xp = const Value.absent(),
    this.streak = const Value.absent(),
    this.lastActiveDate = const Value.absent(),
  });
  static Insertable<UserStatsRow> custom({
    Expression<int>? id,
    Expression<int>? xp,
    Expression<int>? streak,
    Expression<DateTime>? lastActiveDate,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (xp != null) 'xp': xp,
      if (streak != null) 'streak': streak,
      if (lastActiveDate != null) 'last_active_date': lastActiveDate,
    });
  }

  UserStatsCompanion copyWith({
    Value<int>? id,
    Value<int>? xp,
    Value<int>? streak,
    Value<DateTime?>? lastActiveDate,
  }) {
    return UserStatsCompanion(
      id: id ?? this.id,
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (xp.present) {
      map['xp'] = Variable<int>(xp.value);
    }
    if (streak.present) {
      map['streak'] = Variable<int>(streak.value);
    }
    if (lastActiveDate.present) {
      map['last_active_date'] = Variable<DateTime>(lastActiveDate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserStatsCompanion(')
          ..write('id: $id, ')
          ..write('xp: $xp, ')
          ..write('streak: $streak, ')
          ..write('lastActiveDate: $lastActiveDate')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LessonProgressTable lessonProgress = $LessonProgressTable(this);
  late final $WordProgressTable wordProgress = $WordProgressTable(this);
  late final $UserStatsTable userStats = $UserStatsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    lessonProgress,
    wordProgress,
    userStats,
  ];
}

typedef $$LessonProgressTableCreateCompanionBuilder =
    LessonProgressCompanion Function({
      required String lessonId,
      Value<bool> completed,
      Value<int> bestScore,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$LessonProgressTableUpdateCompanionBuilder =
    LessonProgressCompanion Function({
      Value<String> lessonId,
      Value<bool> completed,
      Value<int> bestScore,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

class $$LessonProgressTableFilterComposer
    extends Composer<_$AppDatabase, $LessonProgressTable> {
  $$LessonProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bestScore => $composableBuilder(
    column: $table.bestScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LessonProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $LessonProgressTable> {
  $$LessonProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bestScore => $composableBuilder(
    column: $table.bestScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LessonProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $LessonProgressTable> {
  $$LessonProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<int> get bestScore =>
      $composableBuilder(column: $table.bestScore, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$LessonProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LessonProgressTable,
          LessonProgressRow,
          $$LessonProgressTableFilterComposer,
          $$LessonProgressTableOrderingComposer,
          $$LessonProgressTableAnnotationComposer,
          $$LessonProgressTableCreateCompanionBuilder,
          $$LessonProgressTableUpdateCompanionBuilder,
          (
            LessonProgressRow,
            BaseReferences<
              _$AppDatabase,
              $LessonProgressTable,
              LessonProgressRow
            >,
          ),
          LessonProgressRow,
          PrefetchHooks Function()
        > {
  $$LessonProgressTableTableManager(
    _$AppDatabase db,
    $LessonProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LessonProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LessonProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LessonProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> lessonId = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int> bestScore = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LessonProgressCompanion(
                lessonId: lessonId,
                completed: completed,
                bestScore: bestScore,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String lessonId,
                Value<bool> completed = const Value.absent(),
                Value<int> bestScore = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LessonProgressCompanion.insert(
                lessonId: lessonId,
                completed: completed,
                bestScore: bestScore,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LessonProgressTable, LessonProgressRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LessonProgressTable,
                    LessonProgressRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LessonProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LessonProgressTable,
      LessonProgressRow,
      $$LessonProgressTableFilterComposer,
      $$LessonProgressTableOrderingComposer,
      $$LessonProgressTableAnnotationComposer,
      $$LessonProgressTableCreateCompanionBuilder,
      $$LessonProgressTableUpdateCompanionBuilder,
      (
        LessonProgressRow,
        BaseReferences<_$AppDatabase, $LessonProgressTable, LessonProgressRow>,
      ),
      LessonProgressRow,
      PrefetchHooks Function()
    >;
typedef $$WordProgressTableCreateCompanionBuilder =
    WordProgressCompanion Function({
      required String wordId,
      Value<double> easeFactor,
      Value<int> intervalDays,
      Value<int> repetitions,
      required DateTime dueDate,
      Value<int> rowid,
    });
typedef $$WordProgressTableUpdateCompanionBuilder =
    WordProgressCompanion Function({
      Value<String> wordId,
      Value<double> easeFactor,
      Value<int> intervalDays,
      Value<int> repetitions,
      Value<DateTime> dueDate,
      Value<int> rowid,
    });

class $$WordProgressTableFilterComposer
    extends Composer<_$AppDatabase, $WordProgressTable> {
  $$WordProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get wordId => $composableBuilder(
    column: $table.wordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get easeFactor => $composableBuilder(
    column: $table.easeFactor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repetitions => $composableBuilder(
    column: $table.repetitions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WordProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $WordProgressTable> {
  $$WordProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get wordId => $composableBuilder(
    column: $table.wordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get easeFactor => $composableBuilder(
    column: $table.easeFactor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repetitions => $composableBuilder(
    column: $table.repetitions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WordProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $WordProgressTable> {
  $$WordProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get wordId =>
      $composableBuilder(column: $table.wordId, builder: (column) => column);

  GeneratedColumn<double> get easeFactor => $composableBuilder(
    column: $table.easeFactor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repetitions => $composableBuilder(
    column: $table.repetitions,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);
}

class $$WordProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WordProgressTable,
          WordProgressRow,
          $$WordProgressTableFilterComposer,
          $$WordProgressTableOrderingComposer,
          $$WordProgressTableAnnotationComposer,
          $$WordProgressTableCreateCompanionBuilder,
          $$WordProgressTableUpdateCompanionBuilder,
          (
            WordProgressRow,
            BaseReferences<_$AppDatabase, $WordProgressTable, WordProgressRow>,
          ),
          WordProgressRow,
          PrefetchHooks Function()
        > {
  $$WordProgressTableTableManager(_$AppDatabase db, $WordProgressTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> wordId = const Value.absent(),
                Value<double> easeFactor = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<int> repetitions = const Value.absent(),
                Value<DateTime> dueDate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordProgressCompanion(
                wordId: wordId,
                easeFactor: easeFactor,
                intervalDays: intervalDays,
                repetitions: repetitions,
                dueDate: dueDate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String wordId,
                Value<double> easeFactor = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<int> repetitions = const Value.absent(),
                required DateTime dueDate,
                Value<int> rowid = const Value.absent(),
              }) => WordProgressCompanion.insert(
                wordId: wordId,
                easeFactor: easeFactor,
                intervalDays: intervalDays,
                repetitions: repetitions,
                dueDate: dueDate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WordProgressTable, WordProgressRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $WordProgressTable,
                    WordProgressRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WordProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WordProgressTable,
      WordProgressRow,
      $$WordProgressTableFilterComposer,
      $$WordProgressTableOrderingComposer,
      $$WordProgressTableAnnotationComposer,
      $$WordProgressTableCreateCompanionBuilder,
      $$WordProgressTableUpdateCompanionBuilder,
      (
        WordProgressRow,
        BaseReferences<_$AppDatabase, $WordProgressTable, WordProgressRow>,
      ),
      WordProgressRow,
      PrefetchHooks Function()
    >;
typedef $$UserStatsTableCreateCompanionBuilder = UserStatsCompanion Function({
  Value<int> id,
  Value<int> xp,
  Value<int> streak,
  Value<DateTime?> lastActiveDate,
});
typedef $$UserStatsTableUpdateCompanionBuilder = UserStatsCompanion Function({
  Value<int> id,
  Value<int> xp,
  Value<int> streak,
  Value<DateTime?> lastActiveDate,
});

class $$UserStatsTableFilterComposer
    extends Composer<_$AppDatabase, $UserStatsTable> {
  $$UserStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get xp => $composableBuilder(
    column: $table.xp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get streak => $composableBuilder(
    column: $table.streak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastActiveDate => $composableBuilder(
    column: $table.lastActiveDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserStatsTable> {
  $$UserStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get xp => $composableBuilder(
    column: $table.xp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get streak => $composableBuilder(
    column: $table.streak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastActiveDate => $composableBuilder(
    column: $table.lastActiveDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserStatsTable> {
  $$UserStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get xp =>
      $composableBuilder(column: $table.xp, builder: (column) => column);

  GeneratedColumn<int> get streak =>
      $composableBuilder(column: $table.streak, builder: (column) => column);

  GeneratedColumn<DateTime> get lastActiveDate => $composableBuilder(
    column: $table.lastActiveDate,
    builder: (column) => column,
  );
}

class $$UserStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserStatsTable,
          UserStatsRow,
          $$UserStatsTableFilterComposer,
          $$UserStatsTableOrderingComposer,
          $$UserStatsTableAnnotationComposer,
          $$UserStatsTableCreateCompanionBuilder,
          $$UserStatsTableUpdateCompanionBuilder,
          (
            UserStatsRow,
            BaseReferences<_$AppDatabase, $UserStatsTable, UserStatsRow>,
          ),
          UserStatsRow,
          PrefetchHooks Function()
        > {
  $$UserStatsTableTableManager(_$AppDatabase db, $UserStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> xp = const Value.absent(),
                Value<int> streak = const Value.absent(),
                Value<DateTime?> lastActiveDate = const Value.absent(),
              }) => UserStatsCompanion(
                id: id,
                xp: xp,
                streak: streak,
                lastActiveDate: lastActiveDate,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> xp = const Value.absent(),
                Value<int> streak = const Value.absent(),
                Value<DateTime?> lastActiveDate = const Value.absent(),
              }) => UserStatsCompanion.insert(
                id: id,
                xp: xp,
                streak: streak,
                lastActiveDate: lastActiveDate,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserStatsTable, UserStatsRow>(table),
                  BaseReferences<_$AppDatabase, $UserStatsTable, UserStatsRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserStatsTable,
      UserStatsRow,
      $$UserStatsTableFilterComposer,
      $$UserStatsTableOrderingComposer,
      $$UserStatsTableAnnotationComposer,
      $$UserStatsTableCreateCompanionBuilder,
      $$UserStatsTableUpdateCompanionBuilder,
      (
        UserStatsRow,
        BaseReferences<_$AppDatabase, $UserStatsTable, UserStatsRow>,
      ),
      UserStatsRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LessonProgressTableTableManager get lessonProgress =>
      $$LessonProgressTableTableManager(_db, _db.lessonProgress);
  $$WordProgressTableTableManager get wordProgress =>
      $$WordProgressTableTableManager(_db, _db.wordProgress);
  $$UserStatsTableTableManager get userStats =>
      $$UserStatsTableTableManager(_db, _db.userStats);
}
```

