import 'exercise.dart';
import '../../audio/domain/speech_similarity.dart';

sealed class ExerciseAnswer {
  const ExerciseAnswer();
}

final class ChoiceAnswer extends ExerciseAnswer {
  const ChoiceAnswer(this.index);
  final int index;
}

final class TranslationAnswer extends ExerciseAnswer {
  const TranslationAnswer(this.text);
  final String text;
}

final class PairsAnswer extends ExerciseAnswer {
  PairsAnswer(Map<int, int> matches) : matches = Map.unmodifiable(matches);
  final Map<int, int> matches;
}

final class AnswerFeedback {
  const AnswerFeedback({
    required this.correct,
    required this.correctAnswer,
    this.speechScore,
  });
  final bool correct;
  final String correctAnswer;
  final double? speechScore;
}

double scoreSpeaking(Speaking exercise, String transcript) =>
    [exercise.phrase, ...exercise.acceptedAnswers]
        .map((target) => speechSimilarity(target, transcript))
        .reduce((a, b) => a > b ? a : b);

String normalizeTranslation(String value) => value.trim().toLowerCase();

bool canCheckAnswer(Exercise exercise, ExerciseAnswer? answer) => switch ((
  exercise,
  answer,
)) {
  (MultipleChoice(:final options), ChoiceAnswer(:final index)) =>
    index >= 0 && index < options.length,
  (FillInBlank(:final choices), ChoiceAnswer(:final index)) =>
    index >= 0 && index < choices.length,
  (TypeTranslation(), TranslationAnswer(:final text)) => text.trim().isNotEmpty,
  (Speaking(), TranslationAnswer(:final text)) => normalizeSpeech(
    text,
  ).isNotEmpty,
  (Listening(:final options), ChoiceAnswer(:final index)) =>
    options.isNotEmpty && index >= 0 && index < options.length,
  (Listening(:final options), TranslationAnswer(:final text)) =>
    options.isEmpty && text.trim().isNotEmpty,
  (MatchPairs(:final pairs), PairsAnswer(:final matches)) =>
    matches.length == pairs.length &&
        matches.values.toSet().length == pairs.length &&
        matches.entries.every(
          (entry) =>
              entry.key >= 0 &&
              entry.key < pairs.length &&
              entry.value >= 0 &&
              entry.value < pairs.length,
        ),
  _ => false,
};

AnswerFeedback gradeExercise(Exercise exercise, ExerciseAnswer? answer) {
  final expected = switch (exercise) {
    MultipleChoice() => exercise.options[exercise.correctIndex],
    FillInBlank() => exercise.answer,
    TypeTranslation() => exercise.acceptedAnswers.join(' / '),
    Listening() => exercise.acceptedAnswers.join(' / '),
    Speaking() => exercise.phrase,
    MatchPairs() =>
      exercise.pairs.map((pair) => '${pair.left} → ${pair.right}').join('\n'),
  };
  final correct =
      canCheckAnswer(exercise, answer) &&
      switch ((exercise, answer)) {
        (MultipleChoice(:final correctIndex), ChoiceAnswer(:final index)) =>
          correctIndex == index,
        (
          Listening(:final options, :final acceptedAnswers),
          ChoiceAnswer(:final index),
        ) =>
          acceptedAnswers.any(
            (a) =>
                normalizeTranslation(a) == normalizeTranslation(options[index]),
          ),
        (Listening(:final acceptedAnswers), TranslationAnswer(:final text)) =>
          acceptedAnswers.any(
            (a) => normalizeTranslation(a) == normalizeTranslation(text),
          ),
        (Speaking(:final minimumScore), TranslationAnswer(:final text)) =>
          scoreSpeaking(exercise as Speaking, text) >= minimumScore,
        (
          FillInBlank(:final choices, :final answer),
          ChoiceAnswer(:final index),
        ) =>
          choices[index] == answer,
        (
          TypeTranslation(:final acceptedAnswers),
          TranslationAnswer(:final text),
        ) =>
          acceptedAnswers.any(
            (accepted) =>
                normalizeTranslation(accepted) == normalizeTranslation(text),
          ),
        (MatchPairs(), PairsAnswer(:final matches)) => matches.entries.every(
          (entry) => entry.key == entry.value,
        ),
        _ => false,
      };
  return AnswerFeedback(
    correct: correct,
    correctAnswer: expected,
    speechScore: exercise is Speaking && answer is TranslationAnswer
        ? scoreSpeaking(exercise, answer.text)
        : null,
  );
}
