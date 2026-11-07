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
