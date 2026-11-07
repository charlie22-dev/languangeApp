import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/home/domain/learning_path.dart';

import 'support/phase3_fixtures.dart';

void main() {
  final course = sampleCourse();
  final lessons = course.units.expand((unit) => unit.lessons).toList();
  LessonRecord done(int index, [int score = 100]) => LessonRecord(
    lessonId: lessons[index].id,
    completed: true,
    bestScore: score,
  );

  test('only the first incomplete lesson is available', () {
    final path = LearningPath.fromCourse(course, []);
    expect(path.lessons.first.availability, LessonAvailability.available);
    expect(
      path.lessons
          .skip(1)
          .every((lesson) => lesson.availability == LessonAvailability.locked),
      isTrue,
    );
  });

  test('completion unlocks the next lesson across unit boundaries', () {
    final path = LearningPath.fromCourse(course, [done(0), done(1), done(2)]);
    expect(
      path.units.first.lessons.every(
        (lesson) => lesson.availability == LessonAvailability.completed,
      ),
      isTrue,
    );
    expect(
      path.units[1].lessons.first.availability,
      LessonAvailability.available,
    );
    expect(path.units[1].lessons[1].availability, LessonAvailability.locked);
  });

  test('an incomplete high score does not unlock the next lesson', () {
    final path = LearningPath.fromCourse(course, [
      LessonRecord(
        lessonId: lessons.first.id,
        completed: false,
        bestScore: 100,
      ),
    ]);
    expect(path.lessons.first.availability, LessonAvailability.available);
    expect(path.lessons.first.stars, 0);
    expect(path.lessons.elementAt(1).availability, LessonAvailability.locked);
  });

  test('completed scores map to one, two and three stars', () {
    final path = LearningPath.fromCourse(course, [
      done(0, 69),
      done(1, 70),
      done(2, 90),
    ]);
    expect(path.lessons.take(3).map((lesson) => lesson.stars), [1, 2, 3]);
  });

  test('all completed leaves no available lesson', () {
    final path = LearningPath.fromCourse(course, [
      for (var i = 0; i < lessons.length; i++) done(i),
    ]);
    expect(
      path.lessons.every(
        (lesson) => lesson.availability == LessonAvailability.completed,
      ),
      isTrue,
    );
  });

  test('out-of-order or stale records never unlock two incomplete lessons', () {
    final path = LearningPath.fromCourse(course, [
      done(2),
      const LessonRecord(
        lessonId: 'obsolete-id',
        completed: true,
        bestScore: 100,
      ),
    ]);
    expect(
      path.lessons.where(
        (lesson) => lesson.availability == LessonAvailability.available,
      ),
      hasLength(1),
    );
    expect(path.lessons.first.availability, LessonAvailability.available);
    expect(path.findLesson('missing'), isNull);
  });
}
