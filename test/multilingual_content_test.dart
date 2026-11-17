import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/audio/domain/language_locale.dart';
import 'package:myapp/features/exercises/domain/exercise.dart';
import 'package:myapp/features/exercises/domain/exercise_grader.dart';
import 'package:myapp/features/exercises/domain/writing_hints.dart';
import 'package:myapp/features/lessons/data/course_repository.dart';
import 'package:myapp/features/lessons/domain/course.dart';
import 'package:myapp/features/onboarding/data/course_catalog.dart';

const expectedCourses = {
  'japanese': ('Japanese', 'ja-JP', 'ja_basics_en'),
  'spanish': ('Spanish', 'es-ES', 'es_basics_en'),
  'french': ('French', 'fr-FR', 'fr_basics_en'),
  'german': ('German', 'de-DE', 'de_basics_en'),
  'italian': ('Italian', 'it-IT', 'it_basics_en'),
  'portuguese': ('Portuguese', 'pt-BR', 'pt_basics_en'),
};

Course readCourse(String slug) => Course.fromJson(
  jsonDecode(File('assets/courses/${slug}_basics.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final entry in expectedCourses.entries) {
    test('${entry.key}: complete, round-trippable beginner content', () {
      final course = readCourse(entry.key);
      expect((
        course.targetLanguage,
        course.targetLocale,
        course.id,
      ), entry.value);
      expect(course.nativeLanguage, 'English');
      expect(course.units, hasLength(2));
      expect(course.words, hasLength(60));
      final used = <String>[];
      for (final word in course.words) {
        for (final text in [
          word.text,
          word.translation,
          word.example,
          word.exampleTranslation,
        ]) {
          expect(text.trim(), isNotEmpty);
          expect(
            text,
            isNot(contains('\uFFFD')),
            reason: 'Invalid UTF-8: ${word.id}',
          );
        }
        expect(word.tags, isNotEmpty);
      }
      for (final unit in course.units) {
        expect(unit.lessons, hasLength(3));
        for (final lesson in unit.lessons) {
          expect(lesson.wordIds, hasLength(10));
          used.addAll(lesson.wordIds);
          expect(lesson.exercises, hasLength(8));
          expect(lesson.exercises.map((e) => e.runtimeType).toSet(), {
            MultipleChoice,
            MatchPairs,
            FillInBlank,
            TypeTranslation,
            Listening,
            Speaking,
          });
          for (final exercise in lesson.exercises) {
            expect(
              Exercise.fromJson(exercise.toJson()).toJson(),
              exercise.toJson(),
            );
            if (exercise is Listening) {
              if (exercise.options.isNotEmpty) {
                expect(exercise.options, containsAll(exercise.acceptedAnswers));
              }
              expect(exercise.audioText, isNotEmpty);
            }
          }
        }
      }
      expect(used, hasLength(60));
      expect(used.toSet(), course.words.map((w) => w.id).toSet());
      expect(Course.fromJson(course.toJson()).toJson(), course.toJson());
    });
  }
  test('IDs never collide across courses in shared progress tables', () {
    final wordIds = <String>{},
        lessonIds = <String>{},
        exerciseIds = <String>{},
        unitIds = <String>{};
    for (final slug in expectedCourses.keys) {
      final course = readCourse(slug);
      for (final word in course.words) {
        expect(wordIds.add(word.id), isTrue, reason: word.id);
      }
      for (final unit in course.units) {
        expect(unitIds.add(unit.id), isTrue, reason: unit.id);
        for (final lesson in unit.lessons) {
          expect(lessonIds.add(lesson.id), isTrue, reason: lesson.id);
          for (final e in lesson.exercises) {
            expect(exerciseIds.add(e.id), isTrue, reason: e.id);
          }
        }
      }
    }
    expect(wordIds, hasLength(360));
    expect(lessonIds, hasLength(36));
    expect(exerciseIds, hasLength(288));
  });
  test('canonical answers pass the real grader for all 288 exercises', () {
    for (final slug in expectedCourses.keys) {
      for (final unit in readCourse(slug).units) {
        for (final lesson in unit.lessons) {
          for (final exercise in lesson.exercises) {
            final answer = switch (exercise) {
              MultipleChoice() => ChoiceAnswer(exercise.correctIndex),
              MatchPairs() => PairsAnswer({
                for (var i = 0; i < exercise.pairs.length; i++) i: i,
              }),
              FillInBlank() => ChoiceAnswer(
                exercise.choices.indexOf(exercise.answer),
              ),
              TypeTranslation() => TranslationAnswer(
                '  ${exercise.acceptedAnswers.first.toUpperCase()}  ',
              ),
              Listening() =>
                exercise.options.isEmpty
                    ? TranslationAnswer(exercise.acceptedAnswers.first)
                    : ChoiceAnswer(
                        exercise.options.indexOf(
                          exercise.acceptedAnswers.first,
                        ),
                      ),
              Speaking() => TranslationAnswer(exercise.phrase),
            };
            expect(
              gradeExercise(exercise, answer).correct,
              isTrue,
              reason: exercise.id,
            );
          }
        }
      }
    }
  });
  test(
    'catalog loads every course from the actual Flutter asset bundle',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final courses = await container.read(courseCatalogProvider.future);
      expect(courses.map((c) => c.id), expectedCourses.values.map((v) => v.$3));
      for (final path in container.read(courseCatalogPathsProvider)) {
        expect(await rootBundle.loadString(path), isNotEmpty);
      }
    },
  );
  test('a configured course asset is deduplicated in the catalog', () async {
    final container = ProviderContainer(
      overrides: [
        courseAssetPathProvider.overrideWithValue(
          'assets/courses/french_basics.json',
        ),
      ],
    );
    addTearDown(container.dispose);
    final courses = await container.read(courseCatalogProvider.future);
    expect(courses.first.targetLanguage, 'French');
    expect(courses.map((c) => c.id).toSet(), hasLength(courses.length));
  });
  test('every bundled language has a matching pronunciation locale', () {
    for (final entry in expectedCourses.values) {
      expect(localeForLanguage(entry.$1), entry.$2);
    }
    expect(localeForLanguage('Brazilian Portuguese'), 'pt-BR');
    expect(localeForLanguage('it'), 'it-IT');
    expect(localeForLanguage('pt'), 'pt-BR');
  });
  test(
    'writing hints cover all new alphabets and keep unknown locales empty',
    () {
      expect(writingHints('fr-FR'), contains('œ'));
      expect(writingHints('de_DE'), contains('ß'));
      expect(writingHints('it-IT'), contains('ì'));
      expect(writingHints('pt-BR'), contains('ã'));
      expect(writingHints('es-ES'), contains('ñ'));
      expect(writingHints('ja-JP'), isEmpty);
      expect(writingHints(null), isEmpty);
      expect(writingHints('unknown'), isEmpty);
    },
  );
}
