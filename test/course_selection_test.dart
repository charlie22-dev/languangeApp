import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/router/app_router.dart';
import 'package:myapp/features/home/data/home_providers.dart';
import 'package:myapp/features/onboarding/domain/onboarding_settings.dart';
import 'package:myapp/features/onboarding/presentation/course_selection_controller.dart';
import 'package:myapp/features/onboarding/presentation/onboarding_controller.dart';

import 'multilingual_content_test.dart' show readCourse, expectedCourses;
import 'support/chat_fixtures.dart';
import 'support/phase3_fixtures.dart';
import 'widget_test.dart' show AppHarness, mount, tapText;
import 'chat_widget_test.dart' show sendText;
import 'lesson_engine_widget_test.dart' show answerCorrectly;
import 'support/audio_fixtures.dart';

import 'package:myapp/features/lessons/presentation/lesson_controller.dart';

void main() {
  testWidgets(
    'a real Spanish lesson finishes, awards XP and enrolls its words',
    (tester) async {
      final course = readCourse('spanish');
      final speech = FakeSpeechService();
      final harness = AppHarness(
        course: course,
        settings: OnboardingSettings(courseId: course.id, goalMinutes: 10),
        audioService: fakeAudio(),
        speechService: speech,
      );
      await mount(tester, harness);
      final lesson = course.units.first.lessons.first;
      harness.container.read(appRouterProvider).go('/lesson/${lesson.id}');
      await tester.pumpAndSettle();
      for (final exercise in lesson.exercises) {
        await answerCorrectly(tester, exercise, speech: speech);
      }
      expect(
        harness.container.read(lessonControllerProvider(lesson)).saved,
        isTrue,
      );
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('50 XP'), findsOneWidget);
      final progress = await tester.runAsync(
        () => harness.database
            .select(harness.database.lessonProgress)
            .getSingle(),
      );
      expect(progress?.lessonId, 'es_greetings');
      expect(progress?.completed, isTrue);
      final words = await tester.runAsync(
        () => harness.database.select(harness.database.wordProgress).get(),
      );
      expect(words, hasLength(10));
      expect(words!.every((word) => word.wordId.startsWith('es_')), isTrue);
    },
  );
  testWidgets('onboarding offers six real courses and saves Portuguese', (
    tester,
  ) async {
    final courses = expectedCourses.keys.map(readCourse).toList();
    final harness = AppHarness(availableCourses: courses);
    await mount(tester, harness);
    await tapText(tester, 'Get Started');
    for (final course in courses) {
      expect(find.byKey(ValueKey('language-${course.id}')), findsOneWidget);
    }
    await tapText(tester, 'Portuguese');
    await tapText(tester, 'Continue');
    await tapText(tester, '5 minutes');
    await tapText(tester, 'Start learning');
    expect(harness.repository.saved?.courseId, 'pt_basics_en');
    expect(harness.repository.saved?.goalMinutes, 5);
    expect(harness.container.read(appRouterProvider).state.uri.path, '/home');
    expect(
      harness.container.read(selectedCourseProvider).requireValue.targetLocale,
      'pt-BR',
    );
  });

  testWidgets(
    'Settings course switching preserves the goal at 360dp and large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final harness = AppHarness(
        settings: OnboardingSettings(courseId: 'ja_basics_en', goalMinutes: 15),
        availableCourses: expectedCourses.keys.map(readCourse).toList(),
      );
      await mount(tester, harness);
      harness.container.read(appRouterProvider).push('/settings');
      await tester.pumpAndSettle();
      await tapText(tester, 'Learning language');
      await tapText(tester, 'Italian');
      expect(harness.repository.saved?.courseId, 'it_basics_en');
      expect(harness.repository.saved?.goalMinutes, 15);
      expect(
        harness.container.read(appRouterProvider).state.uri.path,
        '/settings/language',
      );
      expect(
        await harness.container.read(selectedCourseProvider.future),
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a failed save keeps the existing course and can be retried', (
    tester,
  ) async {
    final repo = MemoryOnboardingRepository(saved: completedSettings())
      ..failSave = true;
    final harness = AppHarness(
      repository: repo,
      availableCourses: [readCourse('japanese'), readCourse('french')],
    );
    await mount(tester, harness);
    harness.container.read(appRouterProvider).push('/settings/language');
    await tester.pumpAndSettle();
    await tapText(tester, 'French');
    expect(
      find.text('Your language could not be saved. Tap a course to try again.'),
      findsOneWidget,
    );
    expect(repo.saved?.courseId, 'ja_basics_en');
    repo.failSave = false;
    await tapText(tester, 'French');
    expect(repo.saved?.courseId, 'fr_basics_en');
    expect(repo.saved?.goalMinutes, 10);
  });

  testWidgets('unavailable courses cannot overwrite saved preferences', (
    tester,
  ) async {
    final harness = AppHarness(settings: completedSettings());
    await mount(tester, harness);
    final keepAlive = harness.container.listen(
      courseSelectionProvider,
      (_, _) {},
    );
    addTearDown(keepAlive.close);
    expect(
      await harness.container
          .read(courseSelectionProvider.notifier)
          .select('missing'),
      isFalse,
    );
    expect(harness.repository.saved?.courseId, 'ja_basics_en');
    expect(harness.repository.saveCalls, 0);
  });

  testWidgets(
    'chat sends the selected locale without history from another course',
    (tester) async {
      final api = FakeChatApi();
      final harness = AppHarness(
        settings: completedSettings(),
        chatApi: api,
        availableCourses: [readCourse('japanese'), readCourse('spanish')],
      );
      await mount(tester, harness);
      harness.container.read(appRouterProvider).go('/chat');
      await tester.pumpAndSettle();
      await sendText(tester, 'Japanese introduction');
      await harness.container
          .read(onboardingProvider.notifier)
          .complete(
            OnboardingSettings(courseId: 'es_basics_en', goalMinutes: 10),
          );
      await tester.pumpAndSettle();
      await sendText(tester, 'hola');
      expect(api.locales, ['ja-JP', 'es-ES']);
      expect(api.histories.last.map((m) => m.content), ['hola']);
    },
  );
}
