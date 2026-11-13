import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myapp/core/router/app_router.dart';
import 'package:myapp/core/theme/appearance_controller.dart';
import 'package:myapp/features/activity/data/activity_repository.dart';
import 'package:myapp/features/notifications/data/reminder_service.dart';
import 'package:myapp/features/settings/presentation/settings_controller.dart';
import 'package:myapp/features/auth/domain/auth_models.dart';

import 'support/auth_fixtures.dart';

import 'support/phase3_fixtures.dart';
import 'support/reminder_fixtures.dart';
import 'widget_test.dart' show AppHarness, mount, tapText;

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('Phase 7 controls fit large fonts in ${mode.name}', (
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
        clock: () => DateTime(2026, 11, 13, 10),
      );
      await harness.container.read(appearanceProvider.notifier).select(mode);
      await mount(tester, harness);
      await tester.runAsync(
        () => harness.container
            .read(activityRepositoryProvider)
            .award(60, DateTime(2026, 11, 13, 10)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      harness.container.read(appRouterProvider).go('/profile');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      harness.container.read(appRouterProvider).go('/settings');
      await tester.pumpAndSettle();
      await tapText(tester, 'Reset progress');
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Cancel');
      final toggle = find.widgetWithText(SwitchListTile, 'Daily reminder');
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Not now');
    });
  }
  testWidgets('goal completion suppresses today and logout cancels reminders', (
    tester,
  ) async {
    final auth = MemoryAuthRepository(
      identity: const AuthIdentity(id: 'account-a', email: 'a@example.com'),
    );
    addTearDown(auth.close);
    final harness = AppHarness(
      authRepository: auth,
      settings: completedSettings(),
      clock: () => DateTime(2026, 11, 13, 10),
    );
    final backend =
        harness.container.read(reminderServiceProvider) as TestReminderService;
    await mount(tester, harness);
    await harness.container
        .read(practiceSettingsProvider.notifier)
        .setReminder(true);
    await tester.pumpAndSettle();
    expect(backend.calls.last.enabled, isTrue);
    expect(backend.calls.last.goalDone, isFalse);
    await tester.runAsync(
      () => harness.container
          .read(activityRepositoryProvider)
          .award(60, DateTime(2026, 11, 13, 10)),
    );
    await tester.pumpAndSettle();
    expect(backend.calls.last.goalDone, isTrue);
    auth.emit(null);
    await tester.pumpAndSettle();
    expect(backend.calls.last.userId, isNull);
    expect(backend.calls.last.enabled, isFalse);
  });

  testWidgets(
    'goal ring and profile use real daily XP; reset needs confirmation',
    (tester) async {
      final harness = AppHarness(
        settings: completedSettings(),
        clock: () => DateTime(2026, 11, 13, 10),
      );
      await mount(tester, harness);
      await tester.runAsync(
        () => harness.database.transaction(
          () => harness.container
              .read(activityRepositoryProvider)
              .award(60, DateTime(2026, 11, 13, 10)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('60 / 50 XP today'), findsOneWidget);
      expect(
        find.text('Daily goal reached! Great practice today.'),
        findsOneWidget,
      );
      final router = harness.container.read(appRouterProvider);
      router.go('/profile');
      await tester.pumpAndSettle();
      expect(find.text('Longest streak: 1 day'), findsOneWidget);
      expect(find.text('60 XP in the last 7 days'), findsOneWidget);
      router.go('/settings');
      await tester.pumpAndSettle();
      await tapText(tester, 'Reset progress');
      expect(find.text('Reset your learning progress?'), findsOneWidget);
      await tapText(tester, 'Cancel');
      expect(
        (await harness.database.select(harness.database.userStats).getSingle())
            .xp,
        60,
      );
      await tapText(tester, 'Reset progress');
      await tester.tap(find.widgetWithText(TextButton, 'Reset progress'));
      await tester.pumpAndSettle();
      expect(
        (await harness.database.select(harness.database.userStats).getSingle())
            .xp,
        0,
      );
    },
  );

  testWidgets('reminder permission waits for explicit Settings opt-in', (
    tester,
  ) async {
    final harness = AppHarness(settings: completedSettings());
    final reminders =
        harness.container.read(reminderServiceProvider) as TestReminderService;
    await mount(tester, harness);
    expect(reminders.permissionRequests, 0);
    harness.container.read(appRouterProvider).go('/settings');
    await tester.pumpAndSettle();
    final toggle = find.widgetWithText(SwitchListTile, 'Daily reminder');
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tapText(tester, 'Not now');
    expect(reminders.permissionRequests, 0);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tapText(tester, 'Enable reminders');
    expect(reminders.permissionRequests, 1);
    expect(
      harness.container.read(practiceSettingsProvider).asData!.value.reminders,
      isTrue,
    );
    final sound = find.widgetWithText(SwitchListTile, 'Sound effects');
    await tester.ensureVisible(sound);
    await tester.tap(sound);
    await tester.pumpAndSettle();
    expect(
      harness.container.read(practiceSettingsProvider).asData!.value.sound,
      isFalse,
    );
  });
}
