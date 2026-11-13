import '../../exercises/presentation/listening_view.dart';
import '../../exercises/presentation/speaking_view.dart';

import 'package:flutter/material.dart';

import '../../exercises/domain/exercise.dart';
import '../../exercises/domain/exercise_grader.dart';
import '../../exercises/presentation/fill_in_blank_view.dart';
import '../../exercises/presentation/match_pairs_view.dart';
import '../../exercises/presentation/multiple_choice_view.dart';
import '../../exercises/presentation/type_translation_view.dart';
import '../domain/lesson_session.dart';
import 'lesson_controller.dart';

class ExerciseContent extends StatelessWidget {
  const ExerciseContent({
    super.key,
    required this.session,
    required this.controller,
    required this.onCheck,
  });
  final LessonSession session;
  final LessonController controller;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final exercise = session.currentExercise!;
    final enabled = session.phase == LessonPhase.answering;
    final selectedIndex = session.answer is ChoiceAnswer
        ? (session.answer as ChoiceAnswer).index
        : null;
    return switch (exercise) {
      Listening() => ListeningView(
        exercise: exercise,
        enabled: enabled,
        selectedIndex: selectedIndex,
        value: session.answer is TranslationAnswer
            ? (session.answer as TranslationAnswer).text
            : '',
        onSelected: controller.selectChoice,
        onChanged: controller.typeAnswer,
        onSubmitted: onCheck,
        feedbackCorrect: session.feedback?.correct,
      ),
      Speaking() => SpeakingView(
        exercise: exercise,
        enabled: enabled,
        onChanged: controller.typeAnswer,
        onSkip: controller.skipSpeaking,
      ),
      MultipleChoice() => MultipleChoiceView(
        exercise: exercise,
        selectedIndex: selectedIndex,
        enabled: enabled,
        onSelected: controller.selectChoice,
        feedbackCorrect: session.feedback?.correct,
      ),
      FillInBlank() => FillInBlankView(
        exercise: exercise,
        selectedIndex: selectedIndex,
        enabled: enabled,
        onSelected: controller.selectChoice,
        feedbackCorrect: session.feedback?.correct,
      ),
      TypeTranslation() => TypeTranslationView(
        exercise: exercise,
        value: session.answer is TranslationAnswer
            ? (session.answer as TranslationAnswer).text
            : '',
        enabled: enabled,
        onChanged: controller.typeAnswer,
        onSubmitted: onCheck,
      ),
      MatchPairs() => MatchPairsView(
        exercise: exercise,
        matches: session.answer is PairsAnswer
            ? (session.answer as PairsAnswer).matches
            : {},
        rightOrder: session.rightOrder,
        selectedLeft: session.selectedLeft,
        selectedRight: session.selectedRight,
        enabled: enabled,
        onLeft: (index) => controller.selectPair(left: true, index: index),
        onRight: (index) => controller.selectPair(left: false, index: index),
      ),
    };
  }
}
