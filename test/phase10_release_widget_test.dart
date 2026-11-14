import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/router/app_router.dart';
import 'package:myapp/features/lessons/presentation/lesson_controller.dart';
import 'package:myapp/features/onboarding/presentation/onboarding_controller.dart';
import 'package:myapp/features/lessons/domain/course.dart';
import 'package:myapp/features/lessons/domain/lesson.dart';
import 'package:myapp/features/lessons/domain/unit.dart';
import 'package:myapp/shared/widgets/lesson_path_node.dart';

import 'lesson_engine_widget_test.dart' show courseWith, openLesson, tapKey;
import 'support/exercise_fixtures.dart';
import 'support/phase3_fixtures.dart';
import 'widget_test.dart' show AppHarness, mount, tapText;

void main() {
  testWidgets('a long unit only builds visible lesson nodes', (tester) async {
    final course = Course(
      id: 'ja_basics_en',
      title: 'Long course',
      targetLanguage: 'Japanese',
      nativeLanguage: 'English',
      words: const [],
      units: [
        Unit(
          id: 'long-unit',
          title: 'Practice',
          lessons: List.generate(
            100,
            (i) => Lesson(
              id: 'long-$i',
              title: 'Lesson ${i + 1}',
              wordIds: const [],
              exercises: [choiceExercise('exercise-$i')],
            ),
          ),
        ),
      ],
    );
    final harness = AppHarness(settings: completedSettings(), course: course);
    await mount(tester, harness);
    final built = find.byType(LessonPathNode).evaluate().length;
    expect(built, lessThan(12));
    expect(find.byKey(const ValueKey('lesson-node-long-99')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('lesson-node-long-99')),
      500,
      maxScrolls: 120,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-node-long-99')), findsOneWidget);
    expect(find.byType(LessonPathNode).evaluate().length, lessThan(12));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'correct answer announces feedback and persists a finished lesson',
    (tester) async {
      final lesson = engineLesson([choiceExercise()]);
      final harness = AppHarness(
        settings: completedSettings(),
        course: courseWith(lesson),
      );
      await openLesson(tester, harness);
      await tapKey(tester, 'choice-0');
      await tapText(tester, 'Check');
      expect(find.text('Correct!'), findsOneWidget);
      expect(
        harness.container.read(lessonControllerProvider(lesson)).hearts,
        3,
      );
      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
      await tapText(tester, 'Continue');
      expect(find.text('Lesson complete!'), findsOneWidget);
      expect(
        (await harness.database
                .select(harness.database.lessonProgress)
                .getSingle())
            .completed,
        isTrue,
      );
      expect(
        (await harness.database.select(harness.database.userStats).getSingle())
            .xp,
        15,
      );
    },
  );
  testWidgets(
    'wrong answer loses one heart and succeeds after the requeued retry',
    (tester) async {
      final lesson = engineLesson([choiceExercise()]);
      final harness = AppHarness(
        settings: completedSettings(),
        course: courseWith(lesson),
      );
      await openLesson(tester, harness);
      await tapKey(tester, 'choice-1');
      await tapText(tester, 'Check');
      expect(find.text('Not quite'), findsOneWidget);
      expect(
        harness.container.read(lessonControllerProvider(lesson)).hearts,
        2,
      );
      await tapText(tester, 'Continue');
      await tapKey(tester, 'choice-0');
      await tapText(tester, 'Check');
      await tapText(tester, 'Continue');
      expect(find.text('Lesson complete!'), findsOneWidget);
      expect(
        (await harness.database.select(harness.database.userStats).getSingle())
            .xp,
        10,
      );
    },
  );
  testWidgets(
    'protected route redirects through onboarding and then skips it',
    (tester) async {
      final harness = AppHarness();
      await mount(tester, harness);
      final router = harness.container.read(appRouterProvider);
      router.go('/lesson/ja_greetings');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/welcome');
      await harness.container
          .read(onboardingProvider.notifier)
          .complete(completedSettings());
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/home');
      router.go('/welcome');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/home');
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );
}
