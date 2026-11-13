import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/exercises/domain/exercise.dart';
import 'package:myapp/features/exercises/domain/exercise_grader.dart';
import 'package:myapp/features/lessons/domain/lesson_session.dart';
import 'package:myapp/features/lessons/presentation/lesson_controller.dart';
import 'package:myapp/features/lessons/data/lesson_completion_repository.dart';

import 'lesson_controller_test.dart' show MemoryCompletionRepository;
import 'support/exercise_fixtures.dart';

void main() {
  test('listening handles both choices and typed accepted answers', () {
    final choice = Listening(
      id: 'l',
      audioText: 'hola',
      acceptedAnswers: ['hola'],
      options: ['hola', 'adios'],
    );
    expect(gradeExercise(choice, const ChoiceAnswer(0)).correct, isTrue);
    expect(gradeExercise(choice, const ChoiceAnswer(1)).correct, isFalse);
    expect(canCheckAnswer(choice, const ChoiceAnswer(9)), isFalse);
    final typed = Listening(
      id: 't',
      audioText: 'hola',
      acceptedAnswers: ['hola'],
    );
    expect(
      gradeExercise(typed, const TranslationAnswer(' HOLA ')).correct,
      isTrue,
    );
    expect(canCheckAnswer(typed, const TranslationAnswer(' ')), isFalse);
  });
  test('speaking grades transcript similarity with configurable threshold and variants', () {
    final speech = Speaking(id: 's', phrase: 'hello');
    expect(
      gradeExercise(speech, const TranslationAnswer('hallo')).correct,
      isTrue,
    );
    expect(
      gradeExercise(speech, const TranslationAnswer('world')).correct,
      isFalse,
    );
    expect(
      gradeExercise(speech, const TranslationAnswer('HELLO!')).speechScore,
      1,
    );
    final strict = Speaking(id: 'strict', phrase: 'hello', minimumScore: .9);
    expect(
      gradeExercise(strict, const TranslationAnswer('hallo')).correct,
      isFalse,
    );
    final japanese = Speaking(id: 'ja', phrase: 'わたし', acceptedAnswers: ['私']);
    expect(
      gradeExercise(japanese, const TranslationAnswer('私。')).correct,
      isTrue,
    );
  });
  test('audio exercise JSON round trips and rejects invalid required data', () {
    final examples = [
      Listening(
        id: 'l',
        audioText: 'hola',
        audioUrl: 'assets/audio/hola.mp3',
        acceptedAnswers: ['hola'],
        options: ['hola', 'adios'],
      ),
      Speaking(
        id: 's',
        phrase: 'hola',
        minimumScore: .9,
        acceptedAnswers: ['hola amigo'],
      ),
    ];
    for (final exercise in examples) {
      expect(Exercise.fromJson(exercise.toJson()).toJson(), exercise.toJson());
    }
    expect(
      () => Speaking(id: 's', phrase: 'hello', minimumScore: double.nan),
      throwsFormatException,
    );
    expect(
      () => Listening(id: 'l', audioText: 'hola', acceptedAnswers: []),
      throwsFormatException,
    );
  });
  test('skipped speaking has no lost heart, attempt or perfect XP; wrong listening is requeued', () async {
    final repository = MemoryCompletionRepository();
    final container = ProviderContainer(
      overrides: [
        lessonCompletionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final lesson = engineLesson([
      Speaking(id: 's', phrase: 'hello'),
      Listening(id: 'l', audioText: 'hola', acceptedAnswers: ['hola']),
    ]);
    final provider = lessonControllerProvider(lesson);
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);
    final controller = container.read(provider.notifier);
    controller.skipSpeaking();
    expect(container.read(provider).skippedCount, 1);
    expect(container.read(provider).hearts, 3);
    expect(container.read(provider).attempts, 0);
    controller.typeAnswer('wrong');
    controller.check();
    controller.continueLesson();
    expect(container.read(provider).currentExercise!.id, 'l');
    expect(container.read(provider).hearts, 2);
    controller.typeAnswer('hola');
    controller.check();
    controller.continueLesson();
    await Future<void>.delayed(Duration.zero);
    final result = container.read(provider).result!;
    expect(result.success, isTrue);
    expect(result.xp, 10);
    expect(result.skippedCount, 1);
    expect(result.attempts, 2);
    expect(container.read(provider).phase, LessonPhase.finished);
  });
  test('skipping an all-speaking lesson does not award XP', () {
    expect(
      const LessonResult(
        lessonId: 's',
        totalExercises: 1,
        correctCount: 0,
        attempts: 0,
        perfectCount: 0,
        hearts: 3,
        skippedCount: 1,
      ).xp,
      0,
    );
  });
}
