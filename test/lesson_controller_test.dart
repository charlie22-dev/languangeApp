import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/exercises/domain/exercise_grader.dart';
import 'package:myapp/features/lessons/data/lesson_completion_repository.dart';
import 'package:myapp/features/lessons/domain/lesson.dart';
import 'package:myapp/features/lessons/domain/lesson_session.dart';
import 'package:myapp/features/lessons/presentation/lesson_controller.dart';

import 'support/exercise_fixtures.dart';

class MemoryCompletionRepository extends Fake
    implements LessonCompletionRepository {
  final saved = <LessonResult>[];
  bool fail = false;
  int calls = 0;
  Completer<void>? gate;

  @override
  Future<void> save(
    LessonResult result, {
    required List<String> wordIds,
  }) async {
    calls++;
    await gate?.future;
    if (fail) throw StateError('Save failed');
    saved.add(result);
  }
}

void main() {
  late ProviderContainer container;
  late MemoryCompletionRepository repository;
  setUp(() {
    repository = MemoryCompletionRepository();
    container = ProviderContainer(
      overrides: [
        lessonCompletionRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });
  tearDown(() => container.dispose());

  LessonController start(Lesson lesson) {
    final subscription = container.listen(
      lessonControllerProvider(lesson),
      (_, next) {},
    );
    addTearDown(subscription.close);
    return container.read(lessonControllerProvider(lesson).notifier);
  }

  test('starts with 3 hearts, first exercise and disabled empty check', () {
    final lesson = engineLesson();
    final controller = start(lesson);
    final initial = container.read(lessonControllerProvider(lesson));
    expect(initial.hearts, 3);
    expect(initial.currentIndex, 0);
    expect(initial.correctCount, 0);
    expect(initial.phase, LessonPhase.answering);
    controller.check();
    controller.continueLesson();
    expect(container.read(lessonControllerProvider(lesson)).attempts, 0);
  });

  test('correct check enters feedback once and Continue clears the draft', () {
    final lesson = engineLesson();
    final controller = start(lesson);
    controller.selectChoice(0);
    controller.check();
    controller.check();
    controller.selectChoice(1);
    final checked = container.read(lessonControllerProvider(lesson));
    expect(checked.feedback!.correct, isTrue);
    expect(checked.hearts, 3);
    expect(checked.correctCount, 1);
    expect(checked.attempts, 1);
    controller.continueLesson();
    final next = container.read(lessonControllerProvider(lesson));
    expect(next.currentIndex, 1);
    expect(next.phase, LessonPhase.answering);
    expect(next.answer, isNull);
    expect(next.feedback, isNull);
  });

  test(
    'wrong answer loses one heart, queues at the end and reduces first-try XP',
    () async {
      final lesson = engineLesson([choiceExercise('a'), choiceExercise('b')]);
      final controller = start(lesson);
      controller.selectChoice(1);
      controller.check();
      var state = container.read(lessonControllerProvider(lesson));
      expect(state.hearts, 2);
      expect(state.exercises.map((exercise) => exercise.id), ['a', 'b', 'a']);
      expect(state.progress, 0);
      controller.continueLesson();
      controller.selectChoice(0);
      controller.check();
      controller.continueLesson();
      expect(
        container.read(lessonControllerProvider(lesson)).currentExercise!.id,
        'a',
      );
      controller.selectChoice(0);
      controller.check();
      controller.continueLesson();
      await Future<void>.delayed(Duration.zero);
      state = container.read(lessonControllerProvider(lesson));
      expect(state.phase, LessonPhase.finished);
      expect(state.result!.success, isTrue);
      expect(state.result!.score, 67);
      expect(state.result!.perfectCount, 1);
      expect(state.result!.xp, 15);
      expect(state.saved, isTrue);
    },
  );

  test(
    'three wrong attempts exhaust hearts and finish without XP or writes',
    () {
      final lesson = engineLesson([choiceExercise()]);
      final controller = start(lesson);
      for (var i = 0; i < 3; i++) {
        controller.selectChoice(1);
        controller.check();
        expect(container.read(lessonControllerProvider(lesson)).hearts, 2 - i);
        controller.continueLesson();
      }
      final state = container.read(lessonControllerProvider(lesson));
      expect(state.phase, LessonPhase.finished);
      expect(state.result!.success, isFalse);
      expect(state.result!.xp, 0);
      controller.check();
      controller.continueLesson();
      expect(repository.calls, 0);
    },
  );

  test('pairing works in either direction and tapping a pair unpairs it', () {
    final lesson = engineLesson([pairsExercise()]);
    final controller = start(lesson);
    controller.selectPair(left: false, index: 1);
    controller.selectPair(left: true, index: 1);
    controller.selectPair(left: true, index: 0);
    controller.selectPair(left: false, index: 0);
    expect(container.read(lessonControllerProvider(lesson)).canCheck, isTrue);
    controller.selectPair(left: false, index: 0);
    expect(container.read(lessonControllerProvider(lesson)).canCheck, isFalse);
    controller.selectPair(left: true, index: 0);
    controller.selectPair(left: false, index: 0);
    expect(
      (container.read(lessonControllerProvider(lesson)).answer as PairsAnswer)
          .matches,
      {0: 0, 1: 1},
    );
    controller.check();
    expect(
      container.read(lessonControllerProvider(lesson)).feedback!.correct,
      isTrue,
    );
  });

  test(
    'successful perfect run earns 10 plus 5 per exercise and saves once',
    () async {
      final lesson = engineLesson([choiceExercise()]);
      final controller = start(lesson);
      repository.gate = Completer<void>();
      controller.selectChoice(0);
      controller.check();
      controller.continueLesson();
      expect(container.read(lessonControllerProvider(lesson)).saving, isTrue);
      await controller.saveResult();
      controller.continueLesson();
      expect(repository.calls, 1);
      repository.gate!.complete();
      await Future<void>.delayed(Duration.zero);
      final state = container.read(lessonControllerProvider(lesson));
      expect(state.result!.score, 100);
      expect(state.result!.xp, 15);
      expect(state.saved, isTrue);
      await controller.saveResult();
      expect(repository.calls, 1);
    },
  );

  test('failed save can be retried without losing the result', () async {
    final lesson = engineLesson([choiceExercise()]);
    final controller = start(lesson);
    repository.fail = true;
    controller.selectChoice(0);
    controller.check();
    controller.continueLesson();
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(lessonControllerProvider(lesson)).saveError,
      isNotNull,
    );
    repository.fail = false;
    await controller.saveResult();
    expect(container.read(lessonControllerProvider(lesson)).saveError, isNull);
    expect(container.read(lessonControllerProvider(lesson)).saved, isTrue);
    expect(repository.saved, hasLength(1));
  });

  test('empty and duplicate-ID exercise lists are rejected', () {
    for (final lesson in [
      engineLesson([]),
      engineLesson([choiceExercise(), choiceExercise()]),
    ]) {
      expect(
        () => container.read(lessonControllerProvider(lesson)),
        throwsA(anything),
      );
    }
  });
}
