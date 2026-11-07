import 'package:myapp/features/exercises/domain/exercise.dart';
import 'package:myapp/features/lessons/domain/lesson.dart';

MultipleChoice choiceExercise([String id = 'choice']) => MultipleChoice(
  id: id,
  prompt: 'Choose hello',
  options: ['hello', 'goodbye'],
  correctIndex: 0,
);

MatchPairs pairsExercise([String id = 'pairs']) => MatchPairs(
  id: id,
  pairs: const [
    MatchPair(left: 'こんにちは', right: 'hello'),
    MatchPair(left: 'ありがとう', right: 'thank you'),
  ],
);

FillInBlank blankExercise([String id = 'blank']) => FillInBlank(
  id: id,
  sentenceWithBlank: 'Say ___ to greet someone.',
  answer: 'hello',
  choices: ['goodbye', 'hello'],
);

TypeTranslation translationExercise([String id = 'translation']) =>
    TypeTranslation(
      id: id,
      prompt: 'Translate hello',
      acceptedAnswers: ['Hello', 'Hi'],
    );

Lesson engineLesson([List<Exercise>? exercises]) => Lesson(
  id: 'engine-test',
  title: 'Practice',
  wordIds: const [],
  exercises:
      exercises ??
      [
        choiceExercise(),
        pairsExercise(),
        blankExercise(),
        translationExercise(),
      ],
);
