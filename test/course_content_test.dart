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
