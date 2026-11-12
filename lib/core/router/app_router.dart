import '../../shared/widgets/lingo_components.dart';
import '../localization/lingo_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../features/settings/presentation/settings_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/dev/presentation/components_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/auth_screens.dart';
import '../../features/auth/presentation/auth_loading_screen.dart';
import '../../features/sync/presentation/sync_providers.dart';

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
  ref.listen(authStateProvider, (previous, next) => refresh.value++);
  ref.listen(accountReadyProvider, (previous, next) => refresh.value++);
  ref.listen(onboardingProvider, (previous, next) => refresh.value++);
  ref.listen(
    onboardingFlowProvider.select((draft) => draft.courseId),
    (previous, next) => refresh.value++,
  );
  final router = GoRouter(
    initialLocation: AppRoutes.welcome,
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.uri.path;
      final auth = ref.read(authStateProvider);
      const authPaths = {
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
      };
      if (auth.isLoading) {
        return path == AppRoutes.authLoading ? null : AppRoutes.authLoading;
      }
      final identity = auth.asData?.value;
      if (identity == null) {
        return authPaths.contains(path) ? null : AppRoutes.login;
      }
      if (identity.needsPasswordReset) {
        return path == AppRoutes.resetPassword ? null : AppRoutes.resetPassword;
      }
      final ready = ref.read(accountReadyProvider);
      if (ready.isLoading || ready.hasError) {
        return path == AppRoutes.authLoading ? null : AppRoutes.authLoading;
      }
      if (authPaths.contains(path) ||
          path == AppRoutes.authLoading ||
          path == AppRoutes.resetPassword) {
        return AppRoutes.home;
      }
      final settings = ref.read(onboardingProvider);
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
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.authLoading,
        builder: (context, state) => const AuthLoadingScreen(),
      ),
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const ChatScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      if (kDebugMode)
        GoRoute(
          path: '/dev/components',
          builder: (context, state) => const ComponentsScreen(),
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
      title: context.l10n.text('uibc3023b360'),
      message: context.l10n.text('ui54089b3094'),
      action: LingoButton(
        onPressed: () => context.go(AppRoutes.home),
        child: Text(context.l10n.text('uia2b44457dc')),
      ),
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
