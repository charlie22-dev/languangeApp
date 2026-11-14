import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myapp/app/app.dart';
import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/core/router/app_router.dart';
import 'package:myapp/features/auth/data/auth_repository.dart';
import 'package:myapp/features/auth/domain/auth_models.dart';
import 'package:myapp/features/audio/data/audio_service.dart';
import 'package:myapp/features/audio/data/speech_service.dart';
import 'package:myapp/features/exercises/domain/exercise.dart';
import 'package:myapp/features/lessons/presentation/lesson_controller.dart';
import 'package:myapp/features/home/data/home_providers.dart';
import 'package:myapp/features/home/domain/learning_path.dart';
import 'package:myapp/features/lessons/data/course_repository.dart';
import 'package:myapp/features/notifications/presentation/reminder_coordinator.dart';
import 'package:myapp/features/onboarding/data/course_catalog.dart';
import 'package:myapp/features/onboarding/data/onboarding_repository.dart';
import 'package:myapp/features/onboarding/domain/onboarding_settings.dart';
import 'package:myapp/features/sync/presentation/sync_providers.dart';

import '../test/lesson_engine_widget_test.dart' show answerCorrectly;
import '../test/support/audio_fixtures.dart';
import '../test/support/phase3_fixtures.dart' show MemoryOnboardingRepository;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'completes a bundled lesson and persists XP after database reopen',
    (tester) async {
      // The flow tests editable widgets and grading, not a particular OS keyboard.
      tester.testTextInput.register();
      addTearDown(tester.testTextInput.unregister);
      const testAccount = 'phase10-integration-only';
      final database = AppDatabase(userId: testAccount);
      // This deliberately isolated account never reads or resets a real learner's DB.
      await database.transaction(() async {
        for (final table in database.allTables) {
          await database.delete(table).go();
        }
        await database
            .into(database.userStats)
            .insert(UserStatsCompanion.insert());
      });
      final course = await CourseRepository(bundle: rootBundle)
          .loadCourse('assets/courses/japanese_basics.json');
      final speech = FakeSpeechService();
      final audio = fakeAudio();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              const AuthIdentity(
                id: testAccount,
                email: 'integration@example.invalid',
              ),
            ),
          ),
          syncServiceProvider.overrideWithValue(null),
          accountReadyProvider.overrideWith((ref) async {}),
          reminderCoordinatorProvider.overrideWith((ref) async {}),
          onboardingRepositoryProvider.overrideWithValue(
            MemoryOnboardingRepository(
              saved: OnboardingSettings(courseId: course.id, goalMinutes: 10),
            ),
          ),
          courseCatalogProvider.overrideWith((ref) async => [course]),
          audioServiceProvider.overrideWithValue(audio),
          speechServiceProvider.overrideWithValue(speech),
        ],
      );
      var closed = false;
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const LanguageApp(),
          ),
        );
        await tester.pumpAndSettle();
        final lesson = course.units.first.lessons.first;
        final router = container.read(appRouterProvider);
        router.go('/lesson/${lesson.id}');
        await tester.pumpAndSettle();
        for (final exercise in lesson.exercises) {
          debugPrint(
            'Integration exercise: ${exercise.id} (${exercise.runtimeType})',
          );
          // Audio/STT ports are fake, but grading, navigation, XP and SQLite are real.
          if (exercise is Speaking) {
            await answerCorrectly(tester, exercise, speech: speech);
          } else {
            try {
              await answerCorrectly(tester, exercise);
            } catch (_) {
              final session = container.read(lessonControllerProvider(lesson));
              debugPrint(
                'Exercise failed at ${session.currentIndex}, phase ${session.phase}, canCheck ${session.canCheck}, feedback ${session.feedback?.correct}',
              );
              rethrow;
            }
          }
        }
        expect(find.text('Lesson complete!'), findsOneWidget);
        expect(
          (await database.select(database.lessonProgress).getSingle())
              .completed,
          isTrue,
        );
        final xp = (await database.select(database.userStats).getSingle()).xp;
        expect(xp, 50);
        final path = container.read(learningPathProvider).requireValue;
        expect(
          path.findLesson(course.units.first.lessons[1].id)!.availability,
          LessonAvailability.available,
        );
        await binding.traceAction(() async {
          router.go('/home');
          await tester.pumpAndSettle();
          await tester.drag(find.byType(ListView).first, const Offset(0, -300));
          await tester.pumpAndSettle();
        }, reportKey: 'learning_path_scroll');
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await database.close();
        closed = true;
        final reopened = AppDatabase(userId: testAccount);
        try {
          expect(
            (await reopened.select(reopened.lessonProgress).getSingle())
                .bestScore,
            100,
          );
          expect(
            (await reopened.select(reopened.userStats).getSingle()).xp,
            xp,
          );
        } finally {
          await reopened.close();
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        if (!closed) {
          container.dispose();
          await database.close();
        }
        await audio.dispose();
      }
    },
  );
}
