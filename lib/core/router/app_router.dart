import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/flashcards/presentation/review_screen.dart';
import '../../features/flashcards/presentation/review_session_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/learn_screen.dart';
import '../../features/lessons/presentation/lesson_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/onboarding/presentation/daily_goal_screen.dart';
import '../../features/onboarding/presentation/language_screen.dart';
import '../../features/onboarding/presentation/onboarding_controller.dart';
import '../../features/onboarding/presentation/startup_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../shared/widgets/placeholder_page.dart';
import '../constants/app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Refresh redirects when preferences change without rebuilding the router.
  final refresh = ValueNotifier(0);
  ref.listen(onboardingProvider, (previous, next) => refresh.value++);
  ref.listen(
    onboardingFlowProvider.select((draft) => draft.courseId),
    (previous, next) => refresh.value++,
  );
  final router = GoRouter(
    initialLocation: AppRoutes.welcome,
    refreshListenable: refresh,
    redirect: (context, state) {
      final settings = ref.read(onboardingProvider);
      final path = state.uri.path;
      const onboardingPaths = {
        AppRoutes.welcome,
        AppRoutes.languages,
        AppRoutes.dailyGoal,
      };
      if (settings.isLoading || settings.hasError) {
        return path == AppRoutes.startup ? null : AppRoutes.startup;
      }
      if (settings.requireValue == null) {
        if (!onboardingPaths.contains(path)) return AppRoutes.welcome;
        if (path == AppRoutes.dailyGoal &&
            ref.read(onboardingFlowProvider).courseId == null) {
          return AppRoutes.languages;
        }
        return null;
      }
      return onboardingPaths.contains(path) ||
              path == '/' ||
              path == AppRoutes.startup
          ? AppRoutes.home
          : null;
    },
    routes: [
      GoRoute(path: '/', redirect: (context, state) => AppRoutes.welcome),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.startup,
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(
        path: AppRoutes.languages,
        builder: (context, state) => const LanguageScreen(),
      ),
      GoRoute(
        path: AppRoutes.dailyGoal,
        builder: (context, state) => const DailyGoalScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeScreen(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const LearnScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.review,
                builder: (context, state) => const ReviewScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.lesson,
        builder: (context, state) =>
            LessonScreen(lessonId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.reviewSession,
        builder: (context, state) => const ReviewSessionScreen(),
      ),
    ],
    errorBuilder: (context, state) => PlaceholderPage(
      title: 'Page not found',
      message: 'This page is unavailable.',
      action: FilledButton(
        onPressed: () => context.go(AppRoutes.home),
        child: const Text('Go to Learn'),
      ),
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
