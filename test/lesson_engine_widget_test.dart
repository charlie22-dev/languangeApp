import 'support/audio_fixtures.dart';

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

Future<void> answerCorrectly(
  WidgetTester tester,
  Exercise exercise, {
  FakeSpeechService? speech,
}) async {
  switch (exercise) {
    case Listening():
      if (exercise.options.isEmpty) {
        await tester.enterText(
          find.byKey(const ValueKey('listening-input')),
          exercise.acceptedAnswers.first,
        );
      } else {
        await tapText(tester, exercise.acceptedAnswers.first);
      }
    case Speaking():
      if (speech == null) throw StateError('A fake speech backend is required');
      await tapText(tester, 'Start recording');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Start recording'),
        ),
      );
      await tester.pumpAndSettle();
      speech.result(exercise.phrase);
      await tester.pumpAndSettle();
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
    'all six views finish the real course lesson and unlock the next',
    (tester) async {
      final speech = FakeSpeechService();
      final harness = AppHarness(
        settings: completedSettings(),
        audioService: fakeAudio(),
        speechService: speech,
      );
      await openLesson(tester, harness);
      final lesson = harness.course.units.first.lessons.first;
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Check'))
            .onPressed,
        isNull,
      );
      for (final exercise in lesson.exercises) {
        await answerCorrectly(tester, exercise, speech: speech);
      }
      expect(find.text('Lesson complete!'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('50 XP'), findsOneWidget);
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
        50,
      );
      await tapText(tester, 'Continue');
      expect(find.text('50 XP'), findsOneWidget);
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
