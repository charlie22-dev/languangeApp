import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/theme/appearance_controller.dart';
import 'package:myapp/features/exercises/domain/exercise.dart';
import 'package:myapp/features/lessons/presentation/lesson_controller.dart';

import 'support/audio_fixtures.dart';
import 'support/exercise_fixtures.dart';
import 'support/phase3_fixtures.dart';
import 'lesson_engine_widget_test.dart' show courseWith, openLesson;
import 'widget_test.dart' show AppHarness, tapText;

void main() {
  testWidgets(
    'missing listening voice offers a readable fallback; typed answer grades',
    (tester) async {
      final lesson = engineLesson([
        Listening(id: 'listen', audioText: 'hola', acceptedAnswers: ['hola']),
      ]);
      final harness = AppHarness(
        settings: completedSettings(),
        course: courseWith(lesson),
        audioService: fakeAudio(tts: FakeTts()..available = false),
      );
      await openLesson(tester, harness);
      expect(find.text('hola'), findsNothing);
      await tester.tap(find.byTooltip('Play pronunciation'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No voice is available'), findsOneWidget);
      await tapText(tester, 'Show text instead');
      expect(find.text('hola'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('listening-input')),
        'HOLA',
      );
      await tester.pumpAndSettle();
      expect(
        harness.container.read(lessonControllerProvider(lesson)).canCheck,
        isTrue,
      );
      await tapText(tester, 'Check');
      expect(
        harness.container
            .read(lessonControllerProvider(lesson))
            .feedback
            ?.correct,
        isTrue,
      );
      expect(find.text('Correct!'), findsOneWidget);
    },
  );
  testWidgets(
    'speaking asks consent before capture, scores final transcript, and grades',
    (tester) async {
      final speech = FakeSpeechService();
      final lesson = engineLesson([Speaking(id: 'speak', phrase: 'hello')]);
      final harness = AppHarness(
        settings: completedSettings(),
        course: courseWith(lesson),
        audioService: fakeAudio(),
        speechService: speech,
      );
      await openLesson(tester, harness);
      expect(speech.starts, 0);
      await tapText(tester, 'Start recording');
      expect(find.text('Practice with your microphone?'), findsOneWidget);
      expect(speech.starts, 0);
      await tester.tap(find.widgetWithText(TextButton, 'Start recording'));
      await tester.pumpAndSettle();
      expect(speech.starts, 1);
      speech.result('HELLO!');
      await tester.pumpAndSettle();
      expect(find.text('Text match: 100%'), findsOneWidget);
      await tapText(tester, 'Check');
      expect(find.text('Correct!'), findsOneWidget);
      expect(
        harness.container.read(lessonControllerProvider(lesson)).hearts,
        3,
      );
    },
  );
  testWidgets(
    'OS permission denial can be skipped with no heart or XP penalty',
    (tester) async {
      final speech = FakeSpeechService()..denied = true;
      final lesson = engineLesson([Speaking(id: 'speak', phrase: 'hello')]);
      final harness = AppHarness(
        settings: completedSettings(),
        course: courseWith(lesson),
        audioService: fakeAudio(),
        speechService: speech,
      );
      await openLesson(tester, harness);
      await tapText(tester, 'Start recording');
      await tester.tap(find.widgetWithText(TextButton, 'Start recording'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Microphone access was denied'),
        findsOneWidget,
      );
      await tapText(tester, 'Skip speaking');
      final session = harness.container.read(lessonControllerProvider(lesson));
      expect(session.result!.skippedCount, 1);
      expect(session.hearts, 3);
      expect(session.result!.xp, 0);
      expect(tester.takeException(), isNull);
    },
  );
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'audio exercises and permission dialog fit large fonts in ${mode.name}',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final lesson = engineLesson([Speaking(id: 'speak', phrase: 'こんにちは')]);
        final harness = AppHarness(
          settings: completedSettings(),
          course: courseWith(lesson),
          audioService: fakeAudio(),
          speechService: FakeSpeechService(),
        );
        await harness.container.read(appearanceProvider.notifier).select(mode);
        await openLesson(tester, harness);
        await tapText(tester, 'Start recording');
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(TextButton, 'Skip speaking'),
          ),
        );
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(TextButton, 'Skip speaking'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          harness.container
              .read(lessonControllerProvider(lesson))
              .result!
              .skippedCount,
          1,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
