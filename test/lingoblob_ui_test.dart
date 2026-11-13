import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/core/theme/app_theme.dart';
import 'package:myapp/core/theme/lingo_tokens.dart';
import 'package:myapp/core/theme/appearance_controller.dart';
import 'package:myapp/core/router/app_router.dart';
import 'package:myapp/shared/widgets/pip_mascot.dart';
import 'package:myapp/features/onboarding/presentation/onboarding_controller.dart';
import 'package:myapp/features/sync/data/sync_service.dart';
import 'package:myapp/features/sync/presentation/sync_providers.dart';

import 'support/auth_fixtures.dart';

import 'support/phase3_fixtures.dart';
import 'widget_test.dart' show AppHarness, mount;

double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return ((first > second ? first : second) + .05) /
      ((first < second ? first : second) + .05);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('palette preserves brand tokens and readable text in both modes', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final c = theme.colorScheme;
      expect(c.primary, LingoPalette.lime);
      expect(c.onPrimary, LingoPalette.ink);
      for (final pair in [
        (c.onSurface, c.surface),
        (c.onSurface, theme.scaffoldBackgroundColor),
        (c.onSurfaceVariant, c.surface),
        (c.onPrimary, c.primary),
        (c.onSecondary, c.secondary),
        (c.onError, c.error),
        (c.onTertiary, c.tertiary),
      ]) {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
      expect(theme.cardTheme.elevation, 0);
      final selectedLabel = WidgetStateProperty.resolveAs<TextStyle>(
        theme.chipTheme.labelStyle!,
        {WidgetState.selected},
      );
      expect(
        contrast(
          WidgetStateProperty.resolveAs<Color>(selectedLabel.color!, {
            WidgetState.selected,
          }),
          theme.chipTheme.selectedColor!,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect((theme.cardTheme.shape! as RoundedRectangleBorder).side.width, 2);
      expect(theme.textTheme.displayLarge!.fontSize, 32);
      expect(theme.textTheme.displayLarge!.fontWeight, FontWeight.w800);
    }
  });
  test(
    'appearance restores a saved mode after a new provider container',
    () async {
      final first = ProviderContainer();
      await first.read(appearanceProvider.notifier).select(ThemeMode.dark);
      first.dispose();
      final second = ProviderContainer();
      addTearDown(second.dispose);
      final controller = second.read(appearanceProvider.notifier);
      await controller.restored;
      expect(second.read(appearanceProvider).mode, ThemeMode.dark);
      await controller.select(ThemeMode.system);
      expect(
        (await SharedPreferences.getInstance()).getString(
          AppearanceController.key,
        ),
        'system',
      );
    },
  );
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    void smallPhone(WidgetTester tester) {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }

    testWidgets('onboarding states fit 360dp/200% in ${mode.name}', (
      tester,
    ) async {
      smallPhone(tester);
      final harness = AppHarness();
      await harness.container.read(appearanceProvider.notifier).select(mode);
      await mount(tester, harness);
      for (final path in ['/welcome', '/languages', '/daily-goal']) {
        if (path == '/daily-goal') {
          harness.container
              .read(onboardingFlowProvider.notifier)
              .selectCourse(harness.course.id);
        }
        harness.container.read(appRouterProvider).go(path);
        await tester.pumpAndSettle();
        expect(harness.container.read(appRouterProvider).state.uri.path, path);
        expect(tester.takeException(), isNull);
      }
    });
    testWidgets('email-sent state fits 360dp/200% in ${mode.name}', (
      tester,
    ) async {
      smallPhone(tester);
      final auth = MemoryAuthRepository();
      addTearDown(auth.close);
      final harness = AppHarness(authRepository: auth);
      await harness.container.read(appearanceProvider.notifier).select(mode);
      await mount(tester, harness);
      harness.container.read(appRouterProvider).go('/forgot-password');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('auth-email')),
        'learner@example.com',
      );
      final send = find.widgetWithText(FilledButton, 'Send reset link');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.text('Check your inbox!'), findsWidgets);
      expect(find.textContaining('If an account exists'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('sync banner fits 360dp/200% in ${mode.name}', (tester) async {
      smallPhone(tester);
      final harness = AppHarness(settings: completedSettings());
      await harness.container.read(appearanceProvider.notifier).select(mode);
      harness.container
          .read(syncStatusProvider.notifier)
          .update(SyncStatus.offline);
      await mount(tester, harness);
      expect(
        find.text(
          'Sync is unavailable. Your progress is saved on this device.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
    for (final path in [
      '/home',
      '/review',
      '/profile',
      '/chat',
      '/settings',
      '/dev/components',
    ]) {
      testWidgets('$path fits 360dp and 200% text in ${mode.name}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final harness = AppHarness(settings: completedSettings());
        await harness.container.read(appearanceProvider.notifier).select(mode);
        await mount(tester, harness);
        harness.container.read(appRouterProvider).go(path);
        await tester.pumpAndSettle();
        expect(harness.container.read(appRouterProvider).state.uri.path, path);
        expect(tester.takeException(), isNull);
        final semantics = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
        if (path == '/chat') {
          expect(find.text('Practice with Pip'), findsOneWidget);
          expect(find.byType(TextField), findsNothing);
        }
        if (path == '/dev/components') {
          expect(find.byType(PipMascot), findsNWidgets(6));
        }
      });
    }
  }
}
