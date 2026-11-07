import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/exercises/domain/exercise_grader.dart';

import 'support/exercise_fixtures.dart';

void main() {
  test(
    'multiple choice grades the selected option and supplies the answer',
    () {
      final exercise = choiceExercise();
      expect(gradeExercise(exercise, const ChoiceAnswer(0)).correct, isTrue);
      final wrong = gradeExercise(exercise, const ChoiceAnswer(1));
      expect(wrong.correct, isFalse);
      expect(wrong.correctAnswer, 'hello');
      expect(gradeExercise(exercise, const ChoiceAnswer(99)).correct, isFalse);
      expect(canCheckAnswer(exercise, null), isFalse);
    },
  );

  test(
    'fill in blank uses the selected choice rather than the option index',
    () {
      final exercise = blankExercise();
      expect(gradeExercise(exercise, const ChoiceAnswer(1)).correct, isTrue);
      expect(gradeExercise(exercise, const ChoiceAnswer(0)).correct, isFalse);
      expect(gradeExercise(exercise, const ChoiceAnswer(-1)).correct, isFalse);
    },
  );

  test(
    'typing ignores case and surrounding spaces and accepts every alternative',
    () {
      final exercise = translationExercise();
      for (final answer in ['hello', ' HELLO ', 'Hi', '  hI\n']) {
        expect(
          gradeExercise(exercise, TranslationAnswer(answer)).correct,
          isTrue,
        );
      }
      expect(canCheckAnswer(exercise, const TranslationAnswer('  ')), isFalse);
      expect(
        gradeExercise(exercise, const TranslationAnswer('goodbye')).correct,
        isFalse,
      );
      expect(gradeExercise(exercise, const ChoiceAnswer(0)).correct, isFalse);
    },
  );

  test(
    'pairs require a complete bijection and grade independently of tap order',
    () {
      final exercise = pairsExercise();
      expect(
        gradeExercise(exercise, PairsAnswer({1: 1, 0: 0})).correct,
        isTrue,
      );
      final mismatch = gradeExercise(exercise, PairsAnswer({0: 1, 1: 0}));
      expect(mismatch.correct, isFalse);
      expect(mismatch.correctAnswer, contains('こんにちは → hello'));
      for (final invalid in [
        {0: 0},
        {0: 0, 1: 0},
        {0: 0, 2: 1},
        {0: -1, 1: 1},
      ]) {
        expect(canCheckAnswer(exercise, PairsAnswer(invalid)), isFalse);
        expect(gradeExercise(exercise, PairsAnswer(invalid)).correct, isFalse);
      }
    },
  );
}
