import '../../lessons/domain/course.dart';
import '../../lessons/domain/lesson.dart';
import '../../lessons/domain/unit.dart';

enum LessonAvailability { locked, available, completed }

final class LessonRecord {
  const LessonRecord({
    required this.lessonId,
    required this.completed,
    required this.bestScore,
  });
  final String lessonId;
  final bool completed;
  final int bestScore;
}

final class LessonPathEntry {
  const LessonPathEntry({
    required this.lesson,
    required this.availability,
    required this.stars,
  });
  final Lesson lesson;
  final LessonAvailability availability;
  final int stars;
}

final class UnitPath {
  UnitPath({required this.unit, required List<LessonPathEntry> lessons})
    : lessons = List.unmodifiable(lessons);
  final Unit unit;
  final List<LessonPathEntry> lessons;
}

final class LearningPath {
  LearningPath({required this.course, required List<UnitPath> units})
    : units = List.unmodifiable(units);
  final Course course;
  final List<UnitPath> units;

  Iterable<LessonPathEntry> get lessons => units.expand((unit) => unit.lessons);

  LessonPathEntry? findLesson(String id) {
    for (final entry in lessons) {
      if (entry.lesson.id == id) return entry;
    }
    return null;
  }

  factory LearningPath.fromCourse(Course course, List<LessonRecord> records) {
    final progress = {for (final record in records) record.lessonId: record};
    var nextFound = false;
    final units = <UnitPath>[];
    for (final unit in course.units) {
      final entries = <LessonPathEntry>[];
      for (final lesson in unit.lessons) {
        final record = progress[lesson.id];
        final completed = record?.completed ?? false;
        final state = completed
            ? LessonAvailability.completed
            : nextFound
            ? LessonAvailability.locked
            : LessonAvailability.available;
        if (!completed) nextFound = true;
        final score = record?.bestScore ?? 0;
        entries.add(
          LessonPathEntry(
            lesson: lesson,
            availability: state,
            stars: completed
                ? (score >= 90
                      ? 3
                      : score >= 70
                      ? 2
                      : 1)
                : 0,
          ),
        );
      }
      units.add(UnitPath(unit: unit, lessons: entries));
    }
    return LearningPath(course: course, units: units);
  }
}
