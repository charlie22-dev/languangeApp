# Phase 4 - exercise engine

Success means clearing all original exercises and retries with at least one heart. Accuracy uses all checked attempts. A perfect exercise is correct on its first attempt. Successful runs earn 10 base XP + 5 per perfect exercise; failed or abandoned runs earn 0. The final correction is shown before Continue opens results when hearts reach zero.

Grading and session/result models are pure Dart. LessonController is a Riverpod Notifier family scoped to an active lesson. Wrong exercises are re-queued; input is locked during feedback. Match pairs supports either tap direction and unpairing. Successful results save completion and XP in one Drift transaction, retain bestScore and the first completion date, and unlock the next lesson through existing streams. Each new successful replay awards XP; repeated saves within the same controller do not.

Validation: all 61 tests passed; flutter analyze found no issues; dart format reports no changes. Coverage includes pure grading, controller transitions, retry queues, hearts exhaustion, persistence rollback, all four views, exit confirmation, save retry, live unlocking, 320px layouts at 200% text scale in both themes, and a visible keyboard. An Android emulator run was not performed in this phase.

## Created files

- [lib/features/exercises/domain/exercise_grader.dart](lib/features/exercises/domain/exercise_grader.dart)
- [lib/features/exercises/presentation/multiple_choice_view.dart](lib/features/exercises/presentation/multiple_choice_view.dart)
- [lib/features/exercises/presentation/match_pairs_view.dart](lib/features/exercises/presentation/match_pairs_view.dart)
- [lib/features/exercises/presentation/fill_in_blank_view.dart](lib/features/exercises/presentation/fill_in_blank_view.dart)
- [lib/features/exercises/presentation/type_translation_view.dart](lib/features/exercises/presentation/type_translation_view.dart)
- [lib/features/lessons/domain/lesson_session.dart](lib/features/lessons/domain/lesson_session.dart)
- [lib/features/lessons/data/lesson_completion_repository.dart](lib/features/lessons/data/lesson_completion_repository.dart)
- [lib/features/lessons/presentation/lesson_controller.dart](lib/features/lessons/presentation/lesson_controller.dart)
- [lib/features/lessons/presentation/exercise_content.dart](lib/features/lessons/presentation/exercise_content.dart)
- [lib/features/lessons/presentation/lesson_runner.dart](lib/features/lessons/presentation/lesson_runner.dart)
- [lib/features/lessons/presentation/lesson_action_bar.dart](lib/features/lessons/presentation/lesson_action_bar.dart)
- [lib/features/lessons/presentation/results_screen.dart](lib/features/lessons/presentation/results_screen.dart)
- [lib/shared/widgets/answer_option.dart](lib/shared/widgets/answer_option.dart)
- [lib/shared/widgets/answer_feedback_sheet.dart](lib/shared/widgets/answer_feedback_sheet.dart)
- [lib/shared/widgets/lesson_status_header.dart](lib/shared/widgets/lesson_status_header.dart)
- [test/support/exercise_fixtures.dart](test/support/exercise_fixtures.dart)
- [test/exercise_grader_test.dart](test/exercise_grader_test.dart)
- [test/lesson_controller_test.dart](test/lesson_controller_test.dart)
- [test/lesson_completion_repository_test.dart](test/lesson_completion_repository_test.dart)
- [test/lesson_engine_widget_test.dart](test/lesson_engine_widget_test.dart)
- PHASE4_FILES.md (this manifest and source snapshot)

## Edited files

- [lib/features/lessons/presentation/lesson_screen.dart](lib/features/lessons/presentation/lesson_screen.dart)
- [test/widget_test.dart](test/widget_test.dart)
- [README.md](README.md)

No dependencies or database schema changes were needed. Run commands and manual test steps are in the README section below. Full source follows.

## lib/features/exercises/domain/exercise_grader.dart

```dart
import 'exercise.dart';

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
  const AnswerFeedback({required this.correct, required this.correctAnswer});
  final bool correct;
  final String correctAnswer;
}

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
    MatchPairs() =>
      exercise.pairs.map((pair) => '${pair.left} → ${pair.right}').join('\n'),
  };
  final correct =
      canCheckAnswer(exercise, answer) &&
      switch ((exercise, answer)) {
        (MultipleChoice(:final correctIndex), ChoiceAnswer(:final index)) =>
          correctIndex == index,
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
  return AnswerFeedback(correct: correct, correctAnswer: expected);
}
```

## lib/features/exercises/presentation/multiple_choice_view.dart

```dart
import 'package:flutter/material.dart';

import '../../../shared/widgets/answer_option.dart';
import '../domain/exercise.dart';

class MultipleChoiceView extends StatelessWidget {
  const MultipleChoiceView({
    super.key,
    required this.exercise,
    required this.selectedIndex,
    required this.enabled,
    required this.onSelected,
  });
  final MultipleChoice exercise;
  final int? selectedIndex;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(exercise.prompt, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 24),
      for (var i = 0; i < exercise.options.length; i++)
        AnswerOption(
          key: ValueKey('choice-$i'),
          label: exercise.options[i],
          selected: selectedIndex == i,
          onTap: enabled ? () => onSelected(i) : null,
        ),
    ],
  );
}
```

## lib/features/exercises/presentation/match_pairs_view.dart

```dart
import 'package:flutter/material.dart';

import '../../../shared/widgets/answer_option.dart';
import '../domain/exercise.dart';

class MatchPairsView extends StatelessWidget {
  const MatchPairsView({
    super.key,
    required this.exercise,
    required this.matches,
    required this.rightOrder,
    required this.selectedLeft,
    required this.selectedRight,
    required this.enabled,
    required this.onLeft,
    required this.onRight,
  });
  final MatchPairs exercise;
  final Map<int, int> matches;
  final List<int> rightOrder;
  final int? selectedLeft;
  final int? selectedRight;
  final bool enabled;
  final ValueChanged<int> onLeft;
  final ValueChanged<int> onRight;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Match the pairs', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      const Text(
        'Tap one card in each column. Tap a paired card to change it.',
      ),
      const SizedBox(height: 24),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < exercise.pairs.length; i++)
                  AnswerOption(
                    key: ValueKey('pair-left-$i'),
                    label: exercise.pairs[i].left,
                    selected: selectedLeft == i || matches.containsKey(i),
                    pairLabel: matches.containsKey(i) ? 'Pair ${i + 1}' : null,
                    onTap: enabled ? () => onLeft(i) : null,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                for (final i in rightOrder)
                  _RightCard(
                    index: i,
                    exercise: exercise,
                    matches: matches,
                    pending: selectedRight == i,
                    onTap: enabled ? () => onRight(i) : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

class _RightCard extends StatelessWidget {
  const _RightCard({
    required this.index,
    required this.exercise,
    required this.matches,
    required this.pending,
    this.onTap,
  });
  final int index;
  final MatchPairs exercise;
  final Map<int, int> matches;
  final bool pending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final paired = matches.entries
        .where((entry) => entry.value == index)
        .firstOrNull;
    return AnswerOption(
      key: ValueKey('pair-right-$index'),
      label: exercise.pairs[index].right,
      selected: pending || paired != null,
      pairLabel: paired == null ? null : 'Pair ${paired.key + 1}',
      onTap: onTap,
    );
  }
}
```

## lib/features/exercises/presentation/fill_in_blank_view.dart

```dart
import 'package:flutter/material.dart';

import '../../../shared/widgets/answer_option.dart';
import '../domain/exercise.dart';

class FillInBlankView extends StatelessWidget {
  const FillInBlankView({
    super.key,
    required this.exercise,
    required this.selectedIndex,
    required this.enabled,
    required this.onSelected,
  });
  final FillInBlank exercise;
  final int? selectedIndex;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Fill in the blank',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 16),
      Text(
        exercise.sentenceWithBlank,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 24),
      for (var i = 0; i < exercise.choices.length; i++)
        AnswerOption(
          key: ValueKey('choice-$i'),
          label: exercise.choices[i],
          selected: selectedIndex == i,
          onTap: enabled ? () => onSelected(i) : null,
        ),
    ],
  );
}
```

## lib/features/exercises/presentation/type_translation_view.dart

```dart
import 'package:flutter/material.dart';

import '../domain/exercise.dart';

class TypeTranslationView extends StatelessWidget {
  const TypeTranslationView({
    super.key,
    required this.exercise,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
  });
  final TypeTranslation exercise;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(exercise.prompt, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 24),
      TextFormField(
        key: const ValueKey('translation-input'),
        initialValue: value,
        readOnly: !enabled,
        minLines: 1,
        maxLines: 4,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Your translation',
          border: OutlineInputBorder(),
        ),
        onChanged: onChanged,
        onFieldSubmitted: enabled ? (_) => onSubmitted() : null,
      ),
    ],
  );
}
```

## lib/features/lessons/domain/lesson_session.dart

```dart
import '../../exercises/domain/exercise.dart';
import '../../exercises/domain/exercise_grader.dart';

enum LessonPhase { answering, feedback, finished }

final class LessonResult {
  const LessonResult({
    required this.lessonId,
    required this.totalExercises,
    required this.correctCount,
    required this.attempts,
    required this.perfectCount,
    required this.hearts,
  });

  final String lessonId;
  final int totalExercises;
  final int correctCount;
  final int attempts;
  final int perfectCount;
  final int hearts;

  bool get success =>
      totalExercises > 0 && correctCount == totalExercises && hearts > 0;
  double get accuracy => attempts == 0 ? 0 : correctCount / attempts;
  int get score => (accuracy * 100).round();
  int get xp => success ? 10 + 5 * perfectCount : 0;
}

final class LessonSession {
  LessonSession({
    required List<Exercise> exercises,
    required this.originalCount,
    this.currentIndex = 0,
    this.hearts = 3,
    this.correctCount = 0,
    this.attempts = 0,
    this.perfectCount = 0,
    Set<String> mistakenIds = const {},
    this.phase = LessonPhase.answering,
    this.answer,
    this.feedback,
    this.selectedLeft,
    this.selectedRight,
    List<int> rightOrder = const [],
    this.result,
    this.saving = false,
    this.saved = false,
    this.saveError,
  }) : exercises = List.unmodifiable(exercises),
       mistakenIds = Set.unmodifiable(mistakenIds),
       rightOrder = List.unmodifiable(rightOrder);

  final List<Exercise> exercises;
  final int originalCount;
  final int currentIndex;
  final int hearts;
  final int correctCount;
  final int attempts;
  final int perfectCount;
  final Set<String> mistakenIds;
  final LessonPhase phase;
  final ExerciseAnswer? answer;
  final AnswerFeedback? feedback;
  final int? selectedLeft;
  final int? selectedRight;
  final List<int> rightOrder;
  final LessonResult? result;
  final bool saving;
  final bool saved;
  final String? saveError;

  Exercise? get currentExercise =>
      phase == LessonPhase.finished ? null : exercises[currentIndex];
  bool get canCheck =>
      phase == LessonPhase.answering &&
      currentExercise != null &&
      canCheckAnswer(currentExercise!, answer);
  double get progress => originalCount == 0 ? 0 : correctCount / originalCount;

  // Draft fields are reset explicitly between exercises; persistence updates retain them.
  LessonSession copyWith({
    List<Exercise>? exercises,
    int? currentIndex,
    int? hearts,
    int? correctCount,
    int? attempts,
    int? perfectCount,
    Set<String>? mistakenIds,
    LessonPhase? phase,
    ExerciseAnswer? answer,
    AnswerFeedback? feedback,
    int? selectedLeft,
    int? selectedRight,
    List<int>? rightOrder,
    LessonResult? result,
    bool? saving,
    bool? saved,
    String? saveError,
    bool clearDraft = false,
    bool clearSelection = false,
  }) => LessonSession(
    exercises: exercises ?? this.exercises,
    originalCount: originalCount,
    currentIndex: currentIndex ?? this.currentIndex,
    hearts: hearts ?? this.hearts,
    correctCount: correctCount ?? this.correctCount,
    attempts: attempts ?? this.attempts,
    perfectCount: perfectCount ?? this.perfectCount,
    mistakenIds: mistakenIds ?? this.mistakenIds,
    phase: phase ?? this.phase,
    answer: clearDraft ? null : answer ?? this.answer,
    feedback: clearDraft ? null : feedback ?? this.feedback,
    selectedLeft: clearDraft || clearSelection
        ? null
        : selectedLeft ?? this.selectedLeft,
    selectedRight: clearDraft || clearSelection
        ? null
        : selectedRight ?? this.selectedRight,
    rightOrder: rightOrder ?? this.rightOrder,
    result: result ?? this.result,
    saving: saving ?? this.saving,
    saved: saved ?? this.saved,
    saveError: saveError,
  );
}
```

## lib/features/lessons/data/lesson_completion_repository.dart

```dart
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/lesson_session.dart';

final lessonCompletionRepositoryProvider = Provider<LessonCompletionRepository>(
  (ref) => LessonCompletionRepository(ref.watch(appDatabaseProvider)),
);

class LessonCompletionRepository {
  LessonCompletionRepository(this.database, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase database;
  final DateTime Function() clock;

  Future<void> save(LessonResult result) async {
    if (!result.success) return;
    await database.transaction(() async {
      final previous =
          await (database.select(database.lessonProgress)
                ..where((table) => table.lessonId.equals(result.lessonId)))
              .getSingleOrNull();
      await database
          .into(database.lessonProgress)
          .insertOnConflictUpdate(
            LessonProgressCompanion.insert(
              lessonId: result.lessonId,
              completed: const Value(true),
              bestScore: Value(max(previous?.bestScore ?? 0, result.score)),
              completedAt: Value(previous?.completedAt ?? clock().toUtc()),
            ),
          );
      final changed =
          await (database.update(
            database.userStats,
          )..where((table) => table.id.equals(1))).write(
            UserStatsCompanion.custom(
              xp: database.userStats.xp + Constant(result.xp),
            ),
          );
      if (changed != 1) throw StateError('User stats row is missing');
    });
  }
}
```

## lib/features/lessons/presentation/lesson_controller.dart

```dart
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
      await ref.read(lessonCompletionRepositoryProvider).save(result);
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
```

## lib/features/lessons/presentation/exercise_content.dart

```dart
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
      MultipleChoice() => MultipleChoiceView(
        exercise: exercise,
        selectedIndex: selectedIndex,
        enabled: enabled,
        onSelected: controller.selectChoice,
      ),
      FillInBlank() => FillInBlankView(
        exercise: exercise,
        selectedIndex: selectedIndex,
        enabled: enabled,
        onSelected: controller.selectChoice,
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
            : const {},
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
```

## lib/features/lessons/presentation/lesson_runner.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/lesson_status_header.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../domain/lesson.dart';
import '../domain/lesson_session.dart';
import 'exercise_content.dart';
import 'lesson_action_bar.dart';
import 'lesson_controller.dart';
import 'results_screen.dart';

class LessonRunner extends ConsumerStatefulWidget {
  const LessonRunner({super.key, required this.lesson});
  final Lesson lesson;

  @override
  ConsumerState<LessonRunner> createState() => _LessonRunnerState();
}

class _LessonRunnerState extends ConsumerState<LessonRunner> {
  bool _exitDialogOpen = false;

  Future<void> _requestExit() async {
    final session = ref.read(lessonControllerProvider(widget.lesson));
    if (session.saving || _exitDialogOpen) return;
    if (session.phase == LessonPhase.finished &&
        (session.saved || !session.result!.success)) {
      context.go(AppRoutes.home);
      return;
    }
    _exitDialogOpen = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this lesson?'),
        content: Text(
          session.phase == LessonPhase.finished
              ? 'Your result has not been saved. Leave without saving?'
              : 'Your progress in this lesson will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (leave == true && mounted) context.go(AppRoutes.home);
  }

  void _check() {
    FocusScope.of(context).unfocus();
    ref.read(lessonControllerProvider(widget.lesson).notifier).check();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(lessonControllerProvider(widget.lesson));
    final controller = ref.read(
      lessonControllerProvider(widget.lesson).notifier,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestExit();
      },
      child: session.phase == LessonPhase.finished
          ? ResultsScreen(
              session: session,
              onContinue: () => context.go(AppRoutes.home),
              onRetry: controller.saveResult,
              onClose: _requestExit,
            )
          : Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: Text(widget.lesson.title),
                leading: IconButton(
                  tooltip: 'Close lesson',
                  onPressed: _requestExit,
                  icon: const Icon(Icons.close),
                ),
              ),
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => Column(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.25,
                        ),
                        child: SingleChildScrollView(
                          child: LessonStatusHeader(
                            cleared: session.correctCount,
                            total: session.originalCount,
                            hearts: session.hearts,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ResponsiveBody(
                          child: ExerciseContent(
                            key: ValueKey(
                              '${session.currentIndex}:${session.currentExercise!.id}',
                            ),
                            session: session,
                            controller: controller,
                            onCheck: _check,
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.5,
                        ),
                        child: SingleChildScrollView(
                          child: LessonActionBar(
                            session: session,
                            onCheck: _check,
                            onContinue: controller.continueLesson,
                            feedbackMaxHeight: constraints.maxHeight * 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
```

## lib/features/lessons/presentation/lesson_action_bar.dart

```dart
import 'package:flutter/material.dart';

import '../../../shared/widgets/answer_feedback_sheet.dart';
import '../domain/lesson_session.dart';

class LessonActionBar extends StatelessWidget {
  const LessonActionBar({
    super.key,
    required this.session,
    required this.onCheck,
    required this.onContinue,
    required this.feedbackMaxHeight,
  });
  final LessonSession session;
  final VoidCallback onCheck;
  final VoidCallback onContinue;
  final double feedbackMaxHeight;

  @override
  Widget build(BuildContext context) {
    final feedback = session.phase == LessonPhase.feedback;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (feedback) ...[
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: feedbackMaxHeight),
              child: SingleChildScrollView(
                child: AnswerFeedbackSheet(feedback: session.feedback!),
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: feedback
                ? onContinue
                : session.canCheck
                ? onCheck
                : null,
            child: Text(feedback ? 'Continue' : 'Check'),
          ),
        ],
      ),
    );
  }
}
```

## lib/features/lessons/presentation/results_screen.dart

```dart
import 'package:flutter/material.dart';

import '../../../shared/widgets/responsive_body.dart';
import '../domain/lesson_session.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    required this.session,
    required this.onContinue,
    required this.onRetry,
    required this.onClose,
  });
  final LessonSession session;
  final VoidCallback onContinue;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final result = session.result!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Results'),
        leading: IconButton(
          tooltip: 'Close results',
          onPressed: session.saving ? null : onClose,
          icon: const Icon(Icons.close),
        ),
      ),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              result.success
                  ? Icons.emoji_events_outlined
                  : Icons.favorite_border,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              result.success ? 'Lesson complete!' : 'Out of hearts',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              result.success
                  ? 'Your practice is paying off.'
                  : 'A fresh start is another chance to learn.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            _ResultMetric(label: 'Accuracy', value: '${result.score}%'),
            _ResultMetric(label: 'XP earned', value: '${result.xp} XP'),
            _ResultMetric(
              label: 'Correct attempts',
              value: '${result.correctCount} / ${result.attempts}',
            ),
            if (result.success)
              Text(
                '10 base XP + 5 × ${result.perfectCount} first-try exercises',
              ),
            const SizedBox(height: 24),
            if (session.saving)
              Semantics(
                liveRegion: true,
                child: const Text('Saving your progress…'),
              ),
            if (session.saveError != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  session.saveError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Retry saving'),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: !result.success || session.saved ? onContinue : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card.filled(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(label),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    ),
  );
}
```

## lib/shared/widgets/answer_option.dart

```dart
import 'package:flutter/material.dart';

class AnswerOption extends StatelessWidget {
  const AnswerOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.pairLabel,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final String? pairLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyLarge),
                if (pairLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    pairLabel!,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

## lib/shared/widgets/answer_feedback_sheet.dart

```dart
import 'package:flutter/material.dart';

import '../../features/exercises/domain/exercise_grader.dart';

class AnswerFeedbackSheet extends StatelessWidget {
  const AnswerFeedbackSheet({super.key, required this.feedback});
  final AnswerFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final success = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: theme.brightness,
    );
    final background = feedback.correct
        ? success.primaryContainer
        : theme.colorScheme.errorContainer;
    final foreground = feedback.correct
        ? success.onPrimaryContainer
        : theme.colorScheme.onErrorContainer;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  feedback.correct
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: foreground,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    feedback.correct ? 'Correct!' : 'Not quite',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Correct answer:\n${feedback.correctAnswer}',
              style: theme.textTheme.bodyLarge?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
```

## lib/shared/widgets/lesson_status_header.dart

```dart
import 'package:flutter/material.dart';

class LessonStatusHeader extends StatelessWidget {
  const LessonStatusHeader({
    super.key,
    required this.cleared,
    required this.total,
    required this.hearts,
  });
  final int cleared;
  final int total;
  final int hearts;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : cleared / total,
                semanticsLabel:
                    'Lesson progress: $cleared of $total exercises cleared',
              ),
            ),
            const SizedBox(width: 16),
            Semantics(
              label: '$hearts hearts remaining',
              liveRegion: true,
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    3,
                    (index) => Icon(
                      index < hearts ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$cleared of $total exercises cleared',
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    ),
  );
}
```

## test/support/exercise_fixtures.dart

```dart
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
```

## test/exercise_grader_test.dart

```dart
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
```

## test/lesson_controller_test.dart

```dart
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
  Future<void> save(LessonResult result) async {
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
```

## test/lesson_completion_repository_test.dart

```dart
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/features/lessons/data/lesson_completion_repository.dart';
import 'package:myapp/features/lessons/domain/lesson_session.dart';

void main() {
  late AppDatabase database;
  late LessonCompletionRepository repository;
  final now = DateTime.utc(2026, 11, 8);
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LessonCompletionRepository(database, clock: () => now);
  });
  tearDown(() => database.close());

  LessonResult result({int attempts = 2, int hearts = 3}) => LessonResult(
    lessonId: 'ja_greetings',
    totalExercises: 2,
    correctCount: hearts == 0 ? 0 : 2,
    attempts: attempts,
    perfectCount: attempts == 2 ? 2 : 1,
    hearts: hearts,
  );

  test('success writes completed progress and adds XP while preserving other stats', () async {
    await database.select(database.userStats).getSingle();
    await database
        .update(database.userStats)
        .write(const UserStatsCompanion(xp: Value(50), streak: Value(4)));
    await repository.save(result());
    final progress = await database.select(database.lessonProgress).getSingle();
    final stats = await database.select(database.userStats).getSingle();
    expect(progress.completed, isTrue);
    expect(progress.bestScore, 100);
    expect(progress.completedAt!.toUtc(), now);
    expect(stats.xp, 70);
    expect(stats.streak, 4);
  });

  test('a replay preserves the best score and first completion date', () async {
    await repository.save(result());
    await repository.save(result(attempts: 3));
    final progress = await database.select(database.lessonProgress).getSingle();
    expect(progress.bestScore, 100);
    expect(progress.completedAt!.toUtc(), now);
    expect((await database.select(database.userStats).getSingle()).xp, 35);
  });

  test('failed lessons do not save completion or XP', () async {
    await repository.save(result(attempts: 3, hearts: 0));
    expect(await database.select(database.lessonProgress).get(), isEmpty);
    expect((await database.select(database.userStats).getSingle()).xp, 0);
  });

  test(
    'transaction rolls back completion if XP update cannot be saved',
    () async {
      await database.select(database.userStats).getSingle();
      await database.delete(database.userStats).go();
      await expectLater(repository.save(result()), throwsStateError);
      expect(await database.select(database.lessonProgress).get(), isEmpty);
    },
  );
}
```

## test/lesson_engine_widget_test.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/router/app_router.dart';
import 'package:myapp/features/exercises/domain/exercise.dart';
import 'package:myapp/features/exercises/presentation/fill_in_blank_view.dart';
import 'package:myapp/features/exercises/presentation/match_pairs_view.dart';
import 'package:myapp/features/exercises/presentation/multiple_choice_view.dart';
import 'package:myapp/features/exercises/presentation/type_translation_view.dart';
import 'package:myapp/features/home/domain/learning_path.dart';
import 'package:myapp/features/lessons/domain/course.dart';
import 'package:myapp/features/lessons/domain/lesson.dart';
import 'package:myapp/features/lessons/domain/unit.dart';
import 'package:myapp/features/lessons/presentation/lesson_controller.dart';
import 'package:myapp/shared/widgets/lesson_path_node.dart';

import 'lesson_controller_test.dart' show MemoryCompletionRepository;
import 'support/exercise_fixtures.dart';
import 'support/phase3_fixtures.dart';
import 'widget_test.dart' show AppHarness, mount, tapText;

Course courseWith(Lesson lesson) => Course(
  id: 'ja_basics_en',
  title: 'Engine course',
  targetLanguage: 'Japanese',
  nativeLanguage: 'English',
  words: const [],
  units: [
    Unit(id: 'unit', title: 'Practice', lessons: [lesson]),
  ],
);

Future<void> openLesson(WidgetTester tester, AppHarness harness) async {
  await mount(tester, harness);
  harness.container
      .read(appRouterProvider)
      .go('/lesson/${harness.course.units.first.lessons.first.id}');
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> answerCorrectly(WidgetTester tester, Exercise exercise) async {
  switch (exercise) {
    case MultipleChoice():
      expect(find.byType(MultipleChoiceView), findsOneWidget);
      await tapKey(tester, 'choice-${exercise.correctIndex}');
    case FillInBlank():
      expect(find.byType(FillInBlankView), findsOneWidget);
      await tapKey(
        tester,
        'choice-${exercise.choices.indexOf(exercise.answer)}',
      );
    case TypeTranslation():
      expect(find.byType(TypeTranslationView), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('translation-input')),
        '  ${exercise.acceptedAnswers.first.toUpperCase()}  ',
      );
      await tester.pumpAndSettle();
    case MatchPairs():
      expect(find.byType(MatchPairsView), findsOneWidget);
      for (var i = 0; i < exercise.pairs.length; i++) {
        await tapKey(tester, 'pair-left-$i');
        await tapKey(tester, 'pair-right-$i');
      }
  }
  await tapText(tester, 'Check');
  expect(find.text('Correct!'), findsOneWidget);
  await tapText(tester, 'Continue');
}

void main() {
  testWidgets(
    'typing and feedback remain usable with keyboard and large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final lesson = engineLesson([translationExercise()]);
      final harness = AppHarness(
        settings: completedSettings(),
        course: courseWith(lesson),
      );
      await openLesson(tester, harness);
      await tester.enterText(
        find.byKey(const ValueKey('translation-input')),
        ' HI ',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Correct!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Continue');
      expect(find.text('Lesson complete!'), findsOneWidget);
    },
  );

  testWidgets(
    'all four views finish the real course lesson and unlock the next',
    (tester) async {
      final harness = AppHarness(settings: completedSettings());
      await openLesson(tester, harness);
      final lesson = harness.course.units.first.lessons.first;
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Check'))
            .onPressed,
        isNull,
      );
      for (final exercise in lesson.exercises) {
        await answerCorrectly(tester, exercise);
      }
      expect(find.text('Lesson complete!'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('40 XP'), findsOneWidget);
      final session = harness.container.read(lessonControllerProvider(lesson));
      expect(session.saved, isTrue);
      final progress = await harness.database
          .select(harness.database.lessonProgress)
          .getSingle();
      expect(progress.completed, isTrue);
      expect(progress.bestScore, 100);
      expect(
        (await harness.database.select(harness.database.userStats).getSingle())
            .xp,
        40,
      );
      await tapText(tester, 'Continue');
      expect(find.text('40 XP'), findsOneWidget);
      expect(
        tester
            .widget<LessonPathNode>(
              find.byKey(const ValueKey('lesson-node-ja_people')),
            )
            .entry
            .availability,
        LessonAvailability.available,
      );
    },
  );

  testWidgets(
    'wrong answer shows correction, retries, then hearts exhaustion results',
    (tester) async {
      final lesson = engineLesson([choiceExercise()]);
      final harness = AppHarness(
        settings: completedSettings(),
        course: courseWith(lesson),
      );
      await openLesson(tester, harness);
      for (var i = 0; i < 3; i++) {
        await tapKey(tester, 'choice-1');
        await tapText(tester, 'Check');
        expect(find.text('Not quite'), findsOneWidget);
        expect(find.text('Correct answer:\nhello'), findsOneWidget);
        expect(
          harness.container.read(lessonControllerProvider(lesson)).hearts,
          2 - i,
        );
        await tapText(tester, 'Continue');
      }
      expect(find.text('Out of hearts'), findsOneWidget);
      expect(find.text('0 XP'), findsOneWidget);
      expect(
        await harness.database.select(harness.database.lessonProgress).get(),
        isEmpty,
      );
      await tapText(tester, 'Continue');
      expect(harness.container.read(appRouterProvider).state.uri.path, '/home');
    },
  );

  testWidgets('close and system Back ask before abandoning an active lesson', (
    tester,
  ) async {
    final lesson = engineLesson([choiceExercise()]);
    final harness = AppHarness(
      settings: completedSettings(),
      course: courseWith(lesson),
    );
    await openLesson(tester, harness);
    await tapKey(tester, 'choice-0');
    await tester.tap(find.byTooltip('Close lesson'));
    await tester.pumpAndSettle();
    expect(find.text('Leave this lesson?'), findsOneWidget);
    await tapText(tester, 'Stay');
    expect(
      harness.container.read(lessonControllerProvider(lesson)).canCheck,
      isTrue,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave this lesson?'), findsOneWidget);
    await tapText(tester, 'Leave');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      await harness.database.select(harness.database.lessonProgress).get(),
      isEmpty,
    );
  });

  testWidgets('results preserve failed saves and retry before Continue', (
    tester,
  ) async {
    final lesson = engineLesson([choiceExercise()]);
    final repository = MemoryCompletionRepository()..fail = true;
    final harness = AppHarness(
      settings: completedSettings(),
      course: courseWith(lesson),
      completionRepository: repository,
    );
    await openLesson(tester, harness);
    await answerCorrectly(tester, lesson.exercises.first);
    expect(
      find.text('Progress could not be saved. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
    repository.fail = false;
    await tapText(tester, 'Retry saving');
    expect(repository.saved, hasLength(1));
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNotNull,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'exercise views, feedback and results fit 320px at 200% in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final lesson = engineLesson();
        final harness = AppHarness(
          settings: completedSettings(),
          course: courseWith(lesson),
        );
        await openLesson(tester, harness);
        for (final exercise in lesson.exercises) {
          await answerCorrectly(tester, exercise);
          expect(tester.takeException(), isNull, reason: exercise.id);
        }
        expect(find.text('Lesson complete!'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
```

## lib/features/lessons/presentation/lesson_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/async_status_view.dart';
import '../../../shared/widgets/placeholder_page.dart';
import '../../home/data/home_providers.dart';
import '../../home/domain/learning_path.dart';
import 'lesson_runner.dart';

class LessonScreen extends ConsumerWidget {
  const LessonScreen({super.key, required this.lessonId});
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(learningPathProvider)
      .when(
        skipLoadingOnRefresh: false,
        loading: () => Scaffold(
          appBar: AppBar(),
          body: const AsyncStatusView(
            message: 'Loading lesson…',
            loading: true,
          ),
        ),
        error: (error, stack) => Scaffold(
          appBar: AppBar(),
          body: AsyncStatusView(
            message: 'This lesson could not be loaded.',
            onRetry: () => retryLearningPath(ref),
          ),
        ),
        data: (path) {
          final entry = path.findLesson(lessonId);
          final locked = entry?.availability == LessonAvailability.locked;
          if (entry != null && !locked) {
            if (entry.lesson.exercises.isEmpty) {
              return const PlaceholderPage(
                title: 'Lesson unavailable',
                message: 'This lesson has no exercises yet.',
              );
            }
            return LessonRunner(key: ValueKey(lessonId), lesson: entry.lesson);
          }
          return PlaceholderPage(
            title: entry == null ? 'Lesson not found' : 'Lesson locked',
            message: entry == null
                ? 'This lesson is not part of your course.'
                : 'Complete the earlier lessons to unlock this one.',
            action: FilledButton.tonal(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Back to Learn'),
            ),
          );
        },
      );
}
```

## test/widget_test.dart

```dart
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app/app.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/core/router/app_router.dart';
import 'package:myapp/features/home/data/home_providers.dart';
import 'package:myapp/features/home/domain/learning_path.dart';
import 'package:myapp/features/lessons/domain/course.dart';
import 'package:myapp/features/lessons/data/lesson_completion_repository.dart';
import 'package:myapp/features/onboarding/data/course_catalog.dart';
import 'package:myapp/features/onboarding/data/onboarding_repository.dart';
import 'package:myapp/features/onboarding/domain/onboarding_settings.dart';
import 'package:myapp/features/onboarding/presentation/onboarding_controller.dart';
import 'package:myapp/shared/widgets/lesson_path_node.dart';

import 'support/phase3_fixtures.dart';

class AppHarness {
  AppHarness({
    MemoryOnboardingRepository? repository,
    OnboardingSettings? settings,
    bool statsError = false,
    Course? course,
    LessonCompletionRepository? completionRepository,
  }) {
    this.course = course ?? sampleCourse();
    this.repository = repository ?? MemoryOnboardingRepository(saved: settings);
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        onboardingRepositoryProvider.overrideWithValue(this.repository),
        appDatabaseProvider.overrideWithValue(database),
        appConfigProvider.overrideWithValue(
          const AppConfig(appName: 'Test App'),
        ),
        courseCatalogProvider.overrideWith((ref) async {
          if (catalogFails) throw StateError('Catalog failure');
          return catalogGate?.future ?? [this.course];
        }),
        if (completionRepository != null)
          lessonCompletionRepositoryProvider.overrideWithValue(
            completionRepository,
          ),
        if (statsError)
          userStatsProvider.overrideWith(
            (ref) => Stream.error(StateError('Stats error')),
          ),
      ],
    );
  }
  late final Course course;
  late final MemoryOnboardingRepository repository;
  late final AppDatabase database;
  late final ProviderContainer container;
  bool catalogFails = false;
  bool closed = false;
  Completer<List<Course>>? catalogGate;

  Future<void> close() async {
    if (closed) return;
    closed = true;
    container.dispose();
    await database.close();
  }
}

Future<void> mount(
  WidgetTester tester,
  AppHarness harness, {
  bool settle = true,
}) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(harness.close);
  });
  await tester.runAsync(() => harness.database.customSelect('SELECT 1').get());
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.container,
      child: const LanguageApp(),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> reachGoal(WidgetTester tester) async {
  await tapText(tester, 'Get Started');
  await tapText(tester, 'Japanese');
  await tapText(tester, 'Continue');
}

void main() {
  testWidgets('system Back preserves the onboarding draft', (tester) async {
    final harness = AppHarness();
    await mount(tester, harness);
    await reachGoal(tester);
    await tapText(tester, '5 minutes');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      harness.container.read(appRouterProvider).state.uri.path,
      '/languages',
    );
    expect(
      harness.container.read(onboardingFlowProvider).courseId,
      'ja_basics_en',
    );
    await tapText(tester, 'Continue');
    expect(harness.container.read(onboardingFlowProvider).goalMinutes, 5);
  });

  testWidgets('three steps persist choices; later launch skips onboarding', (
    tester,
  ) async {
    final harness = AppHarness();
    await mount(tester, harness);
    expect(find.text('Test App'), findsOneWidget);
    expect(
      harness.container.read(appRouterProvider).state.uri.path,
      '/welcome',
    );
    await reachGoal(tester);
    await tapText(tester, '15 minutes');
    await tapText(tester, 'Start learning');
    expect(harness.repository.saved!.courseId, 'ja_basics_en');
    expect(harness.repository.saved!.goalMinutes, 15);
    expect(find.text('Your daily goal: 15 minutes'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(harness.close);
    final second = AppHarness(repository: harness.repository);
    await mount(tester, second);
    final router = second.container.read(appRouterProvider);
    expect(router.state.uri.path, '/home');
    router.go('/welcome');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/home');
  });

  testWidgets('direct links cannot bypass onboarding or language selection', (
    tester,
  ) async {
    final harness = AppHarness();
    await mount(tester, harness);
    final router = harness.container.read(appRouterProvider);
    router.go('/lesson/ja_greetings');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/welcome');
    router.go('/daily-goal');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/languages');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('saving failures preserve choices and allow retry', (
    tester,
  ) async {
    final harness = AppHarness();
    harness.repository.failSave = true;
    await mount(tester, harness);
    await reachGoal(tester);
    await tapText(tester, '5 minutes');
    await tapText(tester, 'Start learning');
    expect(
      find.text('Your choices could not be saved. Please try again.'),
      findsOneWidget,
    );
    expect(harness.repository.saved, isNull);
    expect(harness.container.read(onboardingFlowProvider).goalMinutes, 5);
    harness.repository.failSave = false;
    await tapText(tester, 'Start learning');
    expect(harness.repository.saved!.goalMinutes, 5);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets(
    'in-flight save disables repeat submissions without redirecting',
    (tester) async {
      final harness = AppHarness();
      harness.repository.saveGate = Completer<void>();
      await mount(tester, harness);
      await reachGoal(tester);
      await tapText(tester, 'Start learning');
      expect(find.text('Saving…'), findsOneWidget);
      expect(
        harness.container.read(appRouterProvider).state.uri.path,
        '/daily-goal',
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull,
      );
      await harness.container.read(onboardingFlowProvider.notifier).finish();
      expect(harness.repository.saveCalls, 1);
      harness.repository.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('preferences loading and errors have a retry screen', (
    tester,
  ) async {
    final harness = AppHarness();
    harness.repository.loadGate = Completer<void>();
    await mount(tester, harness, settle: false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Get Started'), findsNothing);
    harness.repository.failLoad = true;
    harness.repository.loadGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Your preferences could not be loaded.'), findsOneWidget);
    harness.repository.failLoad = false;
    await tapText(tester, 'Try again');
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('data-driven language catalog errors can be retried', (
    tester,
  ) async {
    final harness = AppHarness()..catalogFails = true;
    await mount(tester, harness);
    await tapText(tester, 'Get Started');
    expect(find.text('Languages could not be loaded.'), findsOneWidget);
    harness.catalogFails = false;
    await tapText(tester, 'Try again');
    expect(find.text('Japanese'), findsOneWidget);
  });

  testWidgets('home loading and catalog errors can be retried', (tester) async {
    final harness = AppHarness(settings: completedSettings());
    harness.catalogGate = Completer<List<Course>>();
    await mount(tester, harness, settle: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    harness.catalogGate!.completeError(StateError('Catalog failure'));
    await tester.pumpAndSettle();
    expect(find.text('Your lessons could not be loaded.'), findsOneWidget);
    harness.catalogGate = null;
    await tapText(tester, 'Try again');
    expect(find.text('Japanese Basics'), findsOneWidget);
  });

  testWidgets('stats errors do not prevent learning path from loading', (
    tester,
  ) async {
    final harness = AppHarness(settings: completedSettings(), statsError: true);
    await mount(tester, harness);
    expect(find.text('Stats could not be loaded.'), findsOneWidget);
    expect(find.text('Retry stats'), findsOneWidget);
    expect(find.text('Japanese Basics'), findsOneWidget);
  });

  testWidgets('DB updates unlock next lesson, show stars and refresh stats', (
    tester,
  ) async {
    final harness = AppHarness(settings: completedSettings());
    await mount(tester, harness);
    expect(find.text('0 XP'), findsOneWidget);
    final secondFinder = find.byKey(const ValueKey('lesson-node-ja_people'));
    expect(
      tester.widget<LessonPathNode>(secondFinder).entry.availability,
      LessonAvailability.locked,
    );
    await harness.database
        .into(harness.database.lessonProgress)
        .insert(
          LessonProgressCompanion.insert(
            lessonId: 'ja_greetings',
            completed: const Value(true),
            bestScore: const Value(95),
          ),
        );
    await harness.database
        .update(harness.database.userStats)
        .write(const UserStatsCompanion(xp: Value(120), streak: Value(3)));
    await tester.pumpAndSettle();
    final first = tester.widget<LessonPathNode>(
      find.byKey(const ValueKey('lesson-node-ja_greetings')),
    );
    expect(first.entry.availability, LessonAvailability.completed);
    expect(first.entry.stars, 3);
    expect(
      tester.widget<LessonPathNode>(secondFinder).entry.availability,
      LessonAvailability.available,
    );
    expect(find.text('120 XP'), findsOneWidget);
    expect(find.text('3 days streak'), findsOneWidget);
    final firstButton = find.descendant(
      of: find.byKey(const ValueKey('lesson-node-ja_greetings')),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(firstButton);
    await tester.tap(firstButton);
    await tester.pumpAndSettle();
    expect(find.text('Check'), findsOneWidget);
    await tester.tap(find.byTooltip('Close lesson'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Leave');
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('tabs, locked and unknown lesson routes remain usable', (
    tester,
  ) async {
    final harness = AppHarness(settings: completedSettings());
    await mount(tester, harness);
    await tapText(tester, 'Review');
    expect(
      find.text('Flashcard reviews will appear here in a future phase.'),
      findsOneWidget,
    );
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    expect(
      find.text('Your profile will appear here in a future phase.'),
      findsOneWidget,
    );
    final router = harness.container.read(appRouterProvider);
    router.go('/lesson/ja_people');
    await tester.pumpAndSettle();
    expect(find.text('Lesson locked'), findsWidgets);
    router.go('/lesson/missing');
    await tester.pumpAndSettle();
    expect(find.text('Lesson not found'), findsWidgets);
    router.go('/missing');
    await tester.pumpAndSettle();
    await tapText(tester, 'Go to Learn');
    expect(find.text('Japanese Basics'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('320px phone with 200% text in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final harness = AppHarness();
      await mount(tester, harness);
      final router = harness.container.read(appRouterProvider);
      await reachGoal(tester);
      await tapText(tester, 'Start learning');
      for (final route in [
        '/home',
        '/review',
        '/profile',
        '/lesson/ja_greetings',
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
          brightness,
        );
        expect(tester.takeException(), isNull, reason: route);
      }
      router.go('/home');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Daily life'),
        300,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Daily life'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
```

## README.md

````markdown
# Language learning app - Phases 1 through 4

This project contains Material 3 light/dark themes, Riverpod, go_router,
three-step onboarding, a learning path, an exercise engine, and placeholder Review and Profile screens.
Phase 2 adds course content, immutable models, asset loading, and Drift tables.
Phase 3 connects onboarding preferences and database progress to the interface.
Phase 4 adds playable lessons, feedback, results, XP awards, and progress saving.
Backend integration and spaced-repetition scheduling belong to later phases.

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
that represents loading, data, or an error. Phase 3 uses the course catalog to
connect the selected course to Learn. Phase 4 renders its exercises in lesson screens.
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

## Phase 3: onboarding and Learn

First launch follows /welcome -> /languages -> /daily-goal. A language must be
selected before continuing. Daily goals are 5, 10, or 15 minutes (default 10).
OnboardingRepository stores the selected course ID and goal in one versioned JSON
document using SharedPreferencesAsync. Completion is published to Riverpod only
after saving succeeds, so a failed save stays on the goal screen with a retry.
A startup screen handles asynchronous preference loading and read errors.
Returning launches redirect to /home; completed users cannot revisit onboarding
routes. System Back preserves choices when moving between onboarding steps.

The language list is driven by courseCatalogPathsProvider. It starts with the
Japanese asset selected by courseAssetPathProvider. Add another registered asset
to the catalog to extend the choices; labels come from the course metadata.
Course IDs are stable preference keys, so changing a label does not lose selection.

Learn displays unit sections and round lesson nodes. A pure LearningPath model
flattens lessons in JSON order: the first incomplete lesson is available; later
incomplete lessons are locked; completed lessons remain open. The database's
completed flag controls unlocking, even when an unfinished lesson has a score.
Completed scores earn 1 star below 70%, 2 at 70-89%, and 3 at 90-100%.
LessonProgress and UserStats are observed with Riverpod StreamProviders: new
records update the path, XP, and streak without restarting or manually refreshing.
No completion, XP award, streak calculation, or exercise gameplay is added here.
The tests insert progress records to exercise the unlocking behavior.

Tapping an available/completed node pushes /lesson/:id. Direct links to locked
or unknown lesson IDs show explanatory pages. Loading/error states have friendly
messages and retry actions; stats failures do not hide the learning path.

Shared widgets provide responsive page bodies, loading/error feedback, choice
cards, wrapping stat badges, and accessible lesson nodes. Tests exercise 320x568
screens at 200% text scale in light and dark themes, including scrolling to unit 2.

```powershell
cd C:\Langunge_flutter\myapp
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d emulator-5554
```

Use your Android device ID in the final command. No dependency or database schema
changes were needed for Phase 3, so there is no new database generation step.
To manually test onboarding, complete the steps, quit, and reopen the app: Learn
should open directly. To see onboarding again in development, clear this app's
storage through Android Settings (this also clears its local database).
See PHASE3_FILES.md for the file manifest and full Phase 3 code.

## Phase 4: exercise engine

LessonController is an auto-disposed Riverpod Notifier family, keyed by the
loaded Lesson. A Notifier exposes immutable state and methods that change it;
widgets watch the state and invoke those methods rather than grade answers.
Auto-dispose releases a session after its lesson screen closes. Returning to the
same lesson starts a new attempt. Results are rendered on the existing lesson
route so there is no separate results URL that could lose the session.

The controller owns the exercise queue, current index, three hearts, answer draft,
pair selection, correct count, attempt count, first-try count, feedback, phase,
and save status. Phases are answering, feedback, and finished. Check stays
disabled until the answer is complete. Feedback locks the current answer.
Wrong answers cost one heart and append the whole exercise to the queue.
Continue advances after feedback, including the final correction when hearts
reach zero. Progress measures unique exercises cleared out of the original count.

The exercise grader and answer/result models contain no Flutter imports.
MultipleChoice and FillInBlank grade selected choices. MatchPairs shuffles the
right column, supports either tap direction, and allows unpairing by tapping a
paired card. Check grades a complete set of pairs as one exercise. TypeTranslation
trims leading/trailing whitespace, ignores case, and accepts any listed answer;
it does not ignore punctuation, accents, or internal spacing.

Scoring assumptions:

- Success means clearing the entire retry queue with at least one heart left.
- Accuracy is correct attempts divided by all checked attempts, rounded to a
  percentage for display and LessonProgress.bestScore.
- A perfect exercise is answered correctly on its first attempt.
- A successful run awards 10 base XP + 5 XP per perfect exercise. A perfect
  six-exercise sample lesson earns 40 XP. Failed or abandoned runs earn 0 XP.
- Each new successful replay awards its own XP. Repeated checks, Continue taps,
  and save taps in the same session cannot award XP twice.

LessonCompletionRepository writes progress and XP in one Drift transaction.
It marks the lesson complete, preserves its highest score and first completion
date, and increments UserStats.xp without changing the streak. The existing
progress streams unlock the next lesson immediately after commit. Failed saves
roll back both writes and leave the result available for retry. Successful
results allow Continue after saving; failed runs allow Continue immediately.
A close button or system Back asks before abandoning a lesson. Closing an unsaved
result also asks before discarding it; closing is disabled during the save.

The lesson layout keeps the progress/hearts header, scrolling exercise, and
Check/Continue area separate. Feedback is green/red with a correct-answer label,
including an independently scrollable list for match pairs. Header and action
areas can scroll when enlarged text or the keyboard reduces available height.

```powershell
cd C:\Langunge_flutter\myapp
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d emulator-5554
```

Use the Android device ID shown by flutter devices. Complete onboarding if needed,
tap the first available lesson, answer all exercises, and Continue from results.
Check that XP increases and the next node unlocks. Also try three mistakes and
cancel/confirm the close dialog. No new dependencies or database schema changes
were needed, so the existing generated Drift file is unchanged.
See PHASE4_FILES.md for the complete file manifest and source snapshot.
````

