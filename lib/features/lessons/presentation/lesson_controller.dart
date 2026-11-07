import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../exercises/domain/exercise.dart';
import '../../exercises/domain/exercise_grader.dart';
import '../data/lesson_completion_repository.dart';
import '../domain/lesson.dart';
import '../domain/lesson_session.dart';

final lessonControllerProvider = NotifierProvider.autoDispose
    .family<LessonController, LessonSession, Lesson>(LessonController.new);

class LessonController extends Notifier<LessonSession> {
  LessonController(this.lesson);
  final Lesson lesson;

  @override
  LessonSession build() {
    if (lesson.exercises.isEmpty ||
        lesson.exercises.map((exercise) => exercise.id).toSet().length !=
            lesson.exercises.length) {
      throw ArgumentError('A lesson needs exercises with unique IDs');
    }
    return LessonSession(
      exercises: lesson.exercises,
      originalCount: lesson.exercises.length,
      rightOrder: _rightOrder(lesson.exercises.first),
    );
  }

  List<int> _rightOrder(Exercise exercise) => exercise is MatchPairs
      ? (List.generate(exercise.pairs.length, (index) => index)..shuffle())
      : [];

  void selectChoice(int index) {
    if (state.phase != LessonPhase.answering) return;
    final exercise = state.currentExercise!;
    final count = switch (exercise) {
      MultipleChoice() => exercise.options.length,
      FillInBlank() => exercise.choices.length,
      _ => 0,
    };
    if (index >= 0 && index < count) {
      state = state.copyWith(answer: ChoiceAnswer(index));
    }
  }

  void typeAnswer(String text) {
    if (state.phase == LessonPhase.answering &&
        state.currentExercise is TypeTranslation) {
      state = state.copyWith(answer: TranslationAnswer(text));
    }
  }

  void selectPair({required bool left, required int index}) {
    final exercise = state.currentExercise;
    if (state.phase != LessonPhase.answering ||
        exercise is! MatchPairs ||
        index < 0 ||
        index >= exercise.pairs.length) {
      return;
    }
    final matches = {
      ...?(state.answer is PairsAnswer
          ? (state.answer as PairsAnswer).matches
          : null),
    };
    if (left) {
      if (matches.containsKey(index)) {
        matches.remove(index);
        state = state.copyWith(
          answer: PairsAnswer(matches),
          clearSelection: true,
        );
      } else if (state.selectedRight != null) {
        matches[index] = state.selectedRight!;
        state = state.copyWith(
          answer: PairsAnswer(matches),
          clearSelection: true,
        );
      } else {
        state = state.copyWith(selectedLeft: index);
      }
    } else {
      if (matches.containsValue(index)) {
        matches.removeWhere((key, value) => value == index);
        state = state.copyWith(
          answer: PairsAnswer(matches),
          clearSelection: true,
        );
      } else if (state.selectedLeft != null) {
        matches[state.selectedLeft!] = index;
        state = state.copyWith(
          answer: PairsAnswer(matches),
          clearSelection: true,
        );
      } else {
        state = state.copyWith(selectedRight: index);
      }
    }
  }

  void check() {
    if (!state.canCheck) return;
    final exercise = state.currentExercise!;
    final feedback = gradeExercise(exercise, state.answer);
    state = state.copyWith(
      phase: LessonPhase.feedback,
      feedback: feedback,
      attempts: state.attempts + 1,
      hearts: state.hearts - (feedback.correct ? 0 : 1),
      correctCount: state.correctCount + (feedback.correct ? 1 : 0),
      perfectCount:
          state.perfectCount +
          (feedback.correct && !state.mistakenIds.contains(exercise.id)
              ? 1
              : 0),
      mistakenIds: feedback.correct
          ? state.mistakenIds
          : {...state.mistakenIds, exercise.id},
      exercises: feedback.correct
          ? state.exercises
          : [...state.exercises, exercise],
    );
  }

  void continueLesson() {
    if (state.phase != LessonPhase.feedback) return;
    final nextIndex = state.currentIndex + 1;
    if (state.hearts == 0 || nextIndex >= state.exercises.length) {
      final result = LessonResult(
        lessonId: lesson.id,
        totalExercises: state.originalCount,
        correctCount: state.correctCount,
        attempts: state.attempts,
        perfectCount: state.perfectCount,
        hearts: state.hearts,
      );
      state = state.copyWith(
        phase: LessonPhase.finished,
        result: result,
        clearDraft: true,
      );
      unawaited(saveResult());
    } else {
      state = state.copyWith(
        currentIndex: nextIndex,
        phase: LessonPhase.answering,
        clearDraft: true,
        rightOrder: _rightOrder(state.exercises[nextIndex]),
      );
    }
  }

  Future<void> saveResult() async {
    final result = state.result;
    if (state.phase != LessonPhase.finished ||
        result == null ||
        !result.success ||
        state.saving ||
        state.saved) {
      return;
    }
    state = state.copyWith(saving: true);
    try {
      await ref
          .read(lessonCompletionRepositoryProvider)
          .save(result, wordIds: lesson.wordIds);
      if (ref.mounted) state = state.copyWith(saving: false, saved: true);
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(
          saving: false,
          saveError: 'Progress could not be saved. Please try again.',
        );
      }
    }
  }
}
