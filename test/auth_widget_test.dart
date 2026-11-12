import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/router/app_router.dart';
import 'package:myapp/features/auth/domain/auth_models.dart';

import 'support/auth_fixtures.dart';
import 'support/phase3_fixtures.dart';
import 'widget_test.dart' show AppHarness, mount, tapText;

Future<void> enter(WidgetTester tester, String key, String value) async {
  final target = find.byKey(ValueKey(key));
  final field = key == 'auth-email'
      ? target
      : find.descendant(of: target, matching: find.byType(TextFormField));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
}

Future<void> submit(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'session expiry redirects an open lesson to Login without crashing',
    (tester) async {
      final repository = MemoryAuthRepository(
        identity: const AuthIdentity(id: 'account-a', email: 'a@example.com'),
      );
      addTearDown(repository.close);
      final harness = AppHarness(
        authRepository: repository,
        settings: completedSettings(),
      );
      await mount(tester, harness);
      final router = harness.container.read(appRouterProvider);
      router.go('/lesson/ja_greetings');
      await tester.pumpAndSettle();
      repository.emit(null);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/login');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'missing Supabase configuration shows a login error instead of crashing',
    (tester) async {
      final harness = AppHarness(useRealAuth: true);
      await mount(tester, harness);
      expect(
        harness.container.read(appRouterProvider).state.uri.path,
        '/login',
      );
      expect(
        find.text('Sign-in is unavailable on this build.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'logged-out routes redirect to login; valid login returns to Learn',
    (tester) async {
      final repository = MemoryAuthRepository();
      addTearDown(repository.close);
      final harness = AppHarness(
        authRepository: repository,
        settings: completedSettings(),
      );
      await mount(tester, harness);
      final router = harness.container.read(appRouterProvider);
      expect(router.state.uri.path, '/login');
      router.go('/lesson/ja_greetings');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/login');
      await submit(tester, 'Sign in');
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      await enter(tester, 'auth-email', 'a@example.com');
      await enter(tester, 'auth-password', 'password123');
      await submit(tester, 'Sign in');
      expect(router.state.uri.path, '/home');
      await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
      await tester.pumpAndSettle();
      expect(find.text('a@example.com'), findsOneWidget);
      await tapText(tester, 'Sign out');
      expect(router.state.uri.path, '/login');
    },
  );

  testWidgets(
    'registration validates confirmation and explains email verification',
    (tester) async {
      final repository = MemoryAuthRepository();
      addTearDown(repository.close);
      final harness = AppHarness(authRepository: repository);
      await mount(tester, harness);
      await tapText(tester, 'Create an account');
      await enter(tester, 'auth-email', 'new@example.com');
      await enter(tester, 'auth-password', 'password123');
      await enter(tester, 'auth-confirmation', 'different');
      await submit(tester, 'Register');
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await enter(tester, 'auth-confirmation', 'password123');
      await submit(tester, 'Register');
      expect(
        find.text('Check your email to confirm your account, then sign in.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'forgot-password email and recovery link complete the reset flow',
    (tester) async {
      final repository = MemoryAuthRepository();
      addTearDown(repository.close);
      final harness = AppHarness(
        authRepository: repository,
        settings: completedSettings(),
      );
      await mount(tester, harness);
      await tapText(tester, 'Forgot password?');
      await enter(tester, 'auth-email', 'reset@example.com');
      await submit(tester, 'Send reset link');
      expect(repository.resetEmail, 'reset@example.com');
      expect(find.textContaining('If an account exists'), findsOneWidget);
      repository.emit(
        const AuthIdentity(
          id: 'account-a',
          email: 'reset@example.com',
          needsPasswordReset: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        harness.container.read(appRouterProvider).state.uri.path,
        '/reset-password',
      );
      await enter(tester, 'auth-password', 'newpassword123');
      await enter(tester, 'auth-confirmation', 'newpassword123');
      await submit(tester, 'Update password');
      expect(repository.updatedPassword, 'newpassword123');
      expect(harness.container.read(appRouterProvider).state.uri.path, '/home');
    },
  );

  testWidgets(
    'login errors preserve input and in-flight submits cannot repeat',
    (tester) async {
      final repository = MemoryAuthRepository()..failLogin = true;
      addTearDown(repository.close);
      final harness = AppHarness(
        authRepository: repository,
        settings: completedSettings(),
      );
      await mount(tester, harness);
      await enter(tester, 'auth-email', 'a@example.com');
      await enter(tester, 'auth-password', 'password123');
      await submit(tester, 'Sign in');
      expect(find.text('The email or password is incorrect.'), findsOneWidget);
      repository.failLogin = false;
      repository.loginGate = Completer<void>();
      await submit(tester, 'Sign in');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Please wait…'),
            )
            .onPressed,
        isNull,
      );
      expect(repository.loginCalls, 2);
      repository.loginGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('Google starts OAuth and its auth callback opens the app', (
    tester,
  ) async {
    final repository = MemoryAuthRepository();
    addTearDown(repository.close);
    final harness = AppHarness(
      authRepository: repository,
      settings: completedSettings(),
    );
    await mount(tester, harness);
    await tapText(tester, 'Continue with Google');
    expect(repository.googleCalls, 1);
    expect(find.text('Finish signing in in the browser.'), findsOneWidget);
    repository.emit(
      const AuthIdentity(id: 'google-account', email: 'google@example.com'),
    );
    await tester.pumpAndSettle();
    expect(harness.container.read(appRouterProvider).state.uri.path, '/home');
  });

  for (final brightness in Brightness.values) {
    testWidgets('auth forms fit 320px with 200% text in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final repository = MemoryAuthRepository();
      addTearDown(repository.close);
      final harness = AppHarness(authRepository: repository);
      await mount(tester, harness);
      for (final route in ['/login', '/register', '/forgot-password']) {
        harness.container.read(appRouterProvider).go(route);
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
      }
      repository.emit(
        const AuthIdentity(
          id: 'account-a',
          email: 'a@example.com',
          needsPasswordReset: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Set a new password'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
