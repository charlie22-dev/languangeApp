import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app/app.dart';
import 'package:myapp/features/auth/data/auth_repository.dart';
import 'package:myapp/features/auth/domain/auth_models.dart';
import 'package:myapp/features/sync/presentation/sync_providers.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/core/config/supabase_config.dart';
import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/core/utils/clock.dart';
import 'package:myapp/features/flashcards/data/review_repository.dart';
import 'package:myapp/core/router/app_router.dart';
import 'package:myapp/features/home/data/home_providers.dart';
import 'package:myapp/features/home/domain/learning_path.dart';
import 'package:myapp/features/lessons/domain/course.dart';
import 'package:myapp/features/lessons/data/lesson_completion_repository.dart';
import 'package:myapp/features/onboarding/data/course_catalog.dart';
import 'package:myapp/features/onboarding/data/onboarding_repository.dart';
import 'package:myapp/features/onboarding/domain/onboarding_settings.dart';
import 'package:myapp/features/onboarding/presentation/onboarding_controller.dart';
import 'package:myapp/shared/widgets/lesson_path_node.dart';

import 'support/phase3_fixtures.dart';

class AppHarness {
  AppHarness({
    MemoryOnboardingRepository? repository,
    OnboardingSettings? settings,
    bool statsError = false,
    Course? course,
    LessonCompletionRepository? completionRepository,
    ReviewRepository? reviewRepository,
    DateTime Function()? clock,
    AuthRepository? authRepository,
    bool useRealAuth = false,
  }) {
    this.course = course ?? sampleCourse();
    this.repository = repository ?? MemoryOnboardingRepository(saved: settings);
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        onboardingRepositoryProvider.overrideWithValue(this.repository),
        appDatabaseProvider.overrideWithValue(database),
        syncServiceProvider.overrideWithValue(null),
        accountReadyProvider.overrideWith((ref) async {}),
        if (useRealAuth)
          supabaseConfigProvider.overrideWithValue(
            const SupabaseConfig(url: '', publishableKey: ''),
          ),
        if (authRepository != null)
          authRepositoryProvider.overrideWith((ref) async => authRepository)
        else if (!useRealAuth)
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              const AuthIdentity(id: 'test-account', email: 'test@example.com'),
            ),
          ),
        if (clock != null) clockProvider.overrideWithValue(clock),
        if (reviewRepository != null)
          reviewRepositoryProvider.overrideWithValue(reviewRepository),
        appConfigProvider.overrideWithValue(
          const AppConfig(appName: 'Test App'),
        ),
        courseCatalogProvider.overrideWith((ref) async {
          if (catalogFails) throw StateError('Catalog failure');
          return catalogGate?.future ?? [this.course];
        }),
        if (completionRepository != null)
          lessonCompletionRepositoryProvider.overrideWithValue(
            completionRepository,
          ),
        if (statsError)
          userStatsProvider.overrideWith(
            (ref) => Stream.error(StateError('Stats error')),
          ),
      ],
    );
  }
  late final Course course;
  late final MemoryOnboardingRepository repository;
  late final AppDatabase database;
  late final ProviderContainer container;
  bool catalogFails = false;
  bool closed = false;
  Completer<List<Course>>? catalogGate;

  Future<void> close() async {
    if (closed) return;
    closed = true;
    container.dispose();
    await database.close();
  }
}

Future<void> mount(
  WidgetTester tester,
  AppHarness harness, {
  bool settle = true,
}) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(harness.close);
  });
  await tester.runAsync(() => harness.database.customSelect('SELECT 1').get());
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.container,
      child: const LanguageApp(),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> reachGoal(WidgetTester tester) async {
  await tapText(tester, 'Get Started');
  await tapText(tester, 'Japanese');
  await tapText(tester, 'Continue');
}

void main() {
  testWidgets('system Back preserves the onboarding draft', (tester) async {
    final harness = AppHarness();
    await mount(tester, harness);
    await reachGoal(tester);
    await tapText(tester, '5 minutes');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      harness.container.read(appRouterProvider).state.uri.path,
      '/languages',
    );
    expect(
      harness.container.read(onboardingFlowProvider).courseId,
      'ja_basics_en',
    );
    await tapText(tester, 'Continue');
    expect(harness.container.read(onboardingFlowProvider).goalMinutes, 5);
  });

  testWidgets('three steps persist choices; later launch skips onboarding', (
    tester,
  ) async {
    final harness = AppHarness();
    await mount(tester, harness);
    expect(find.text('Test App'), findsOneWidget);
    expect(
      harness.container.read(appRouterProvider).state.uri.path,
      '/welcome',
    );
    await reachGoal(tester);
    await tapText(tester, '15 minutes');
    await tapText(tester, 'Start learning');
    expect(harness.repository.saved!.courseId, 'ja_basics_en');
    expect(harness.repository.saved!.goalMinutes, 15);
    expect(find.text('Your daily goal: 15 minutes'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(harness.close);
    final second = AppHarness(repository: harness.repository);
    await mount(tester, second);
    final router = second.container.read(appRouterProvider);
    expect(router.state.uri.path, '/home');
    router.go('/welcome');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/home');
  });

  testWidgets('direct links cannot bypass onboarding or language selection', (
    tester,
  ) async {
    final harness = AppHarness();
    await mount(tester, harness);
    final router = harness.container.read(appRouterProvider);
    router.go('/lesson/ja_greetings');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/welcome');
    router.go('/daily-goal');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/languages');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('saving failures preserve choices and allow retry', (
    tester,
  ) async {
    final harness = AppHarness();
    harness.repository.failSave = true;
    await mount(tester, harness);
    await reachGoal(tester);
    await tapText(tester, '5 minutes');
    await tapText(tester, 'Start learning');
    expect(
      find.text('Your choices could not be saved. Please try again.'),
      findsOneWidget,
    );
    expect(harness.repository.saved, isNull);
    expect(harness.container.read(onboardingFlowProvider).goalMinutes, 5);
    harness.repository.failSave = false;
    await tapText(tester, 'Start learning');
    expect(harness.repository.saved!.goalMinutes, 5);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets(
    'in-flight save disables repeat submissions without redirecting',
    (tester) async {
      final harness = AppHarness();
      harness.repository.saveGate = Completer<void>();
      await mount(tester, harness);
      await reachGoal(tester);
      await tapText(tester, 'Start learning');
      expect(find.text('Saving…'), findsOneWidget);
      expect(
        harness.container.read(appRouterProvider).state.uri.path,
        '/daily-goal',
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull,
      );
      await harness.container.read(onboardingFlowProvider.notifier).finish();
      expect(harness.repository.saveCalls, 1);
      harness.repository.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('preferences loading and errors have a retry screen', (
    tester,
  ) async {
    final harness = AppHarness();
    harness.repository.loadGate = Completer<void>();
    await mount(tester, harness, settle: false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Get Started'), findsNothing);
    harness.repository.failLoad = true;
    harness.repository.loadGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Your preferences could not be loaded.'), findsOneWidget);
    harness.repository.failLoad = false;
    await tapText(tester, 'Try again');
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('data-driven language catalog errors can be retried', (
    tester,
  ) async {
    final harness = AppHarness()..catalogFails = true;
    await mount(tester, harness);
    await tapText(tester, 'Get Started');
    expect(find.text('Languages could not be loaded.'), findsOneWidget);
    harness.catalogFails = false;
    await tapText(tester, 'Try again');
    expect(find.text('Japanese'), findsOneWidget);
  });

  testWidgets('home loading and catalog errors can be retried', (tester) async {
    final harness = AppHarness(settings: completedSettings());
    harness.catalogGate = Completer<List<Course>>();
    await mount(tester, harness, settle: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    harness.catalogGate!.completeError(StateError('Catalog failure'));
    await tester.pumpAndSettle();
    expect(find.text('Your lessons could not be loaded.'), findsOneWidget);
    harness.catalogGate = null;
    await tapText(tester, 'Try again');
    expect(find.text('Japanese Basics'), findsOneWidget);
  });

  testWidgets('stats errors do not prevent learning path from loading', (
    tester,
  ) async {
    final harness = AppHarness(settings: completedSettings(), statsError: true);
    await mount(tester, harness);
    expect(find.text('Stats could not be loaded.'), findsOneWidget);
    expect(find.text('Retry stats'), findsOneWidget);
    expect(find.text('Japanese Basics'), findsOneWidget);
  });

  testWidgets('DB updates unlock next lesson, show stars and refresh stats', (
    tester,
  ) async {
    final harness = AppHarness(settings: completedSettings());
    await mount(tester, harness);
    expect(find.text('0 XP'), findsOneWidget);
    final secondFinder = find.byKey(const ValueKey('lesson-node-ja_people'));
    expect(
      tester.widget<LessonPathNode>(secondFinder).entry.availability,
      LessonAvailability.locked,
    );
    await harness.database
        .into(harness.database.lessonProgress)
        .insert(
          LessonProgressCompanion.insert(
            lessonId: 'ja_greetings',
            completed: const Value(true),
            bestScore: const Value(95),
          ),
        );
    await harness.database
        .update(harness.database.userStats)
        .write(const UserStatsCompanion(xp: Value(120), streak: Value(3)));
    await tester.pumpAndSettle();
    final first = tester.widget<LessonPathNode>(
      find.byKey(const ValueKey('lesson-node-ja_greetings')),
    );
    expect(first.entry.availability, LessonAvailability.completed);
    expect(first.entry.stars, 3);
    expect(
      tester.widget<LessonPathNode>(secondFinder).entry.availability,
      LessonAvailability.available,
    );
    expect(find.text('120 XP'), findsOneWidget);
    expect(find.text('3 days streak'), findsOneWidget);
    final firstButton = find.descendant(
      of: find.byKey(const ValueKey('lesson-node-ja_greetings')),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(firstButton);
    await tester.tap(firstButton);
    await tester.pumpAndSettle();
    expect(find.text('Check'), findsOneWidget);
    await tester.tap(find.byTooltip('Close lesson'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Leave');
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('tabs, locked and unknown lesson routes remain usable', (
    tester,
  ) async {
    final harness = AppHarness(settings: completedSettings());
    await mount(tester, harness);
    await tapText(tester, 'Review');
    expect(find.text('Your review deck is ready to grow.'), findsOneWidget);
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    expect(find.text('Your account'), findsOneWidget);
    final router = harness.container.read(appRouterProvider);
    router.go('/lesson/ja_people');
    await tester.pumpAndSettle();
    expect(find.text('Lesson locked'), findsWidgets);
    router.go('/lesson/missing');
    await tester.pumpAndSettle();
    expect(find.text('Lesson not found'), findsWidgets);
    router.go('/missing');
    await tester.pumpAndSettle();
    await tapText(tester, 'Go to Learn');
    expect(find.text('Japanese Basics'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('320px phone with 200% text in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final harness = AppHarness();
      await mount(tester, harness);
      final router = harness.container.read(appRouterProvider);
      await reachGoal(tester);
      await tapText(tester, 'Start learning');
      for (final route in [
        '/home',
        '/review',
        '/profile',
        '/lesson/ja_greetings',
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
          brightness,
        );
        expect(tester.takeException(), isNull, reason: route);
      }
      router.go('/home');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Daily life'),
        300,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Daily life'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
