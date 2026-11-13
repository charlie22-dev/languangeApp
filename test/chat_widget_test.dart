import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/router/app_router.dart';
import 'package:myapp/core/theme/appearance_controller.dart';
import 'package:myapp/features/chat/domain/chat_models.dart';
import 'package:myapp/features/chat/presentation/chat_controller.dart';
import 'package:myapp/features/flashcards/presentation/review_providers.dart';

import 'support/phase3_fixtures.dart';
import 'support/chat_fixtures.dart';
import 'support/audio_fixtures.dart';
import 'widget_test.dart' show AppHarness, mount, tapText;

Future<void> openChat(WidgetTester tester, AppHarness harness) async {
  await mount(tester, harness);
  harness.container.read(appRouterProvider).go('/chat');
  await tester.pumpAndSettle();
}

Future<void> sendText(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('chat-input')), text);
  await tester.pump();
  await tester.tap(find.byTooltip('Send message'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'corrections attach to user, translations are hidden, suggested word saves into review',
    (tester) async {
      final api = FakeChatApi()
        ..response = sampleTutorTurn(
          corrections: const [
            ChatCorrection(
              original: 'hello',
              corrected: 'こんにちは',
              explanation: 'Use the Japanese greeting.',
            ),
          ],
        );
      final harness = AppHarness(settings: completedSettings(), chatApi: api);
      await openChat(tester, harness);
      await sendText(tester, 'hello');
      expect(find.text('A gentle correction'), findsOneWidget);
      expect(find.text('Hello. What is your name?'), findsNothing);
      await tapText(tester, 'Translate');
      expect(find.text('Hello. What is your name?'), findsOneWidget);
      await tapText(tester, 'New words (1)');
      await tester.ensureVisible(find.text('Save word'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save word'));
      await tester.pumpAndSettle();
      expect(
        (await harness.database.select(harness.database.wordProgress).get())
            .length,
        1,
      );
      expect(
        (await harness.database
                .select(harness.database.savedVocabulary)
                .getSingle())
            .wordText,
        '猫',
      );
      harness.container.read(appRouterProvider).go('/review');
      await tester.pumpAndSettle();
      expect(
        harness.container.read(reviewOverviewProvider).requireValue.dueCount,
        1,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('offline retry does not duplicate the user message', (
    tester,
  ) async {
    final api = FakeChatApi()..error = 'chatOffline';
    final harness = AppHarness(settings: completedSettings(), chatApi: api);
    await openChat(tester, harness);
    await sendText(tester, 'hello');
    expect(
      find.textContaining('Check your internet connection'),
      findsOneWidget,
    );
    api.error = null;
    await tapText(tester, 'Retry');
    expect(
      harness.container
          .read(chatControllerProvider)
          .requireValue
          .messages
          .length,
      2,
    );
    expect(api.calls, 2);
  });
  testWidgets('typing indicator follows the real pending request', (
    tester,
  ) async {
    final gate = Completer<TutorTurn>();
    final api = FakeChatApi()..gate = gate;
    final harness = AppHarness(settings: completedSettings(), chatApi: api);
    await openChat(tester, harness);
    await tester.enterText(find.byKey(const ValueKey('chat-input')), 'hello');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('Pip is thinking...'), findsOneWidget);
    gate.complete(sampleTutorTurn());
    await tester.pumpAndSettle();
    expect(find.text('Pip is thinking...'), findsNothing);
  });
  testWidgets(
    'dictation asks first and fills text without sending automatically',
    (tester) async {
      final speech = FakeSpeechService();
      final api = FakeChatApi();
      final harness = AppHarness(
        settings: completedSettings(),
        chatApi: api,
        speechService: speech,
        audioService: fakeAudio(),
      );
      await openChat(tester, harness);
      await tester.tap(find.byTooltip('Start recording'));
      await tester.pumpAndSettle();
      expect(speech.starts, 0);
      await tester.tap(find.widgetWithText(TextButton, 'Start recording'));
      await tester.pumpAndSettle();
      speech.result('こんにちは');
      await tester.pumpAndSettle();
      expect(api.calls, 0);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('chat-input')))
            .controller!
            .text,
        'こんにちは',
      );
      await tester.tap(find.widgetWithText(NavigationDestination, 'Learn'));
      await tester.pumpAndSettle();
      expect(speech.active, isFalse);
    },
  );
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('chat fits 360dp at 200 percent in ${mode.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final harness = AppHarness(
        settings: completedSettings(),
        chatApi: FakeChatApi(),
      );
      await harness.container.read(appearanceProvider.notifier).select(mode);
      await openChat(tester, harness);
      await sendText(tester, 'hello');
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
