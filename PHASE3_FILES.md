# Phase 3 - onboarding and home

Japanese is the initial language. Daily goals are 5, 10, and 15 minutes. Settings are persisted using SharedPreferencesAsync; progress and stats come from Drift streams. Lesson screens remain placeholders. Completed scores yield 1 star below 70%, 2 at 70-89%, and 3 at 90% or above.

Validation: flutter analyze passed with no issues; all 38 tests passed; dart format reports no changes. Unit/widget tests ran on the host. An Android emulator run was not performed in this phase.

## Created files

- [lib/features/onboarding/domain/onboarding_settings.dart](lib/features/onboarding/domain/onboarding_settings.dart)
- [lib/features/onboarding/data/onboarding_repository.dart](lib/features/onboarding/data/onboarding_repository.dart)
- [lib/features/onboarding/data/course_catalog.dart](lib/features/onboarding/data/course_catalog.dart)
- [lib/features/onboarding/presentation/onboarding_controller.dart](lib/features/onboarding/presentation/onboarding_controller.dart)
- [lib/features/onboarding/presentation/onboarding_frame.dart](lib/features/onboarding/presentation/onboarding_frame.dart)
- [lib/features/onboarding/presentation/language_screen.dart](lib/features/onboarding/presentation/language_screen.dart)
- [lib/features/onboarding/presentation/daily_goal_screen.dart](lib/features/onboarding/presentation/daily_goal_screen.dart)
- [lib/features/onboarding/presentation/startup_screen.dart](lib/features/onboarding/presentation/startup_screen.dart)
- [lib/features/home/domain/learning_path.dart](lib/features/home/domain/learning_path.dart)
- [lib/features/home/data/home_providers.dart](lib/features/home/data/home_providers.dart)
- [lib/features/home/presentation/learning_path_view.dart](lib/features/home/presentation/learning_path_view.dart)
- [lib/features/home/presentation/user_stats_bar.dart](lib/features/home/presentation/user_stats_bar.dart)
- [lib/shared/widgets/responsive_body.dart](lib/shared/widgets/responsive_body.dart)
- [lib/shared/widgets/async_status_view.dart](lib/shared/widgets/async_status_view.dart)
- [lib/shared/widgets/choice_card.dart](lib/shared/widgets/choice_card.dart)
- [lib/shared/widgets/stat_badge.dart](lib/shared/widgets/stat_badge.dart)
- [lib/shared/widgets/lesson_path_node.dart](lib/shared/widgets/lesson_path_node.dart)
- [test/support/phase3_fixtures.dart](test/support/phase3_fixtures.dart)
- [test/onboarding_repository_test.dart](test/onboarding_repository_test.dart)
- [test/learning_path_test.dart](test/learning_path_test.dart)
- PHASE3_FILES.md (this manifest and source snapshot)

## Edited files

- [lib/core/constants/app_routes.dart](lib/core/constants/app_routes.dart)
- [lib/core/router/app_router.dart](lib/core/router/app_router.dart)
- [lib/features/onboarding/presentation/welcome_screen.dart](lib/features/onboarding/presentation/welcome_screen.dart)
- [lib/features/home/presentation/learn_screen.dart](lib/features/home/presentation/learn_screen.dart)
- [lib/features/lessons/presentation/lesson_screen.dart](lib/features/lessons/presentation/lesson_screen.dart)
- [test/widget_test.dart](test/widget_test.dart)
- [README.md](README.md)

No dependencies or database schema were changed. The full file contents follow. Run commands and manual checks are in the README section at the end.

## lib/features/onboarding/domain/onboarding_settings.dart

```dart
import '../../../core/utils/json_reader.dart';

const dailyGoalMinutes = [5, 10, 15];

final class OnboardingSettings {
  OnboardingSettings({required this.courseId, required this.goalMinutes}) {
    if (courseId.trim().isEmpty || !dailyGoalMinutes.contains(goalMinutes)) {
      throw const FormatException('Invalid onboarding choices');
    }
  }

  final String courseId;
  final int goalMinutes;

  factory OnboardingSettings.fromJson(JsonMap json) {
    if (JsonReader.integer(json, 'version') != 1) {
      throw const FormatException('Unsupported onboarding version');
    }
    return OnboardingSettings(
      courseId: JsonReader.text(json, 'courseId'),
      goalMinutes: JsonReader.integer(json, 'goalMinutes'),
    );
  }

  JsonMap toJson() => {
    'version': 1,
    'courseId': courseId,
    'goalMinutes': goalMinutes,
  };
}
```

## lib/features/onboarding/data/onboarding_repository.dart

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/json_reader.dart';
import '../domain/onboarding_settings.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(SharedPreferencesAsync()),
);

class OnboardingRepository {
  const OnboardingRepository(this.preferences);

  static const storageKey = 'onboarding.v1';
  final SharedPreferencesAsync preferences;

  Future<OnboardingSettings?> load() async {
    final value = await preferences.getString(storageKey);
    if (value == null) return null;
    try {
      return OnboardingSettings.fromJson(
        JsonReader.object(jsonDecode(value), 'onboarding'),
      );
    } on FormatException {
      // An interrupted or obsolete settings document starts onboarding again.
      return null;
    }
  }

  Future<void> save(OnboardingSettings settings) =>
      preferences.setString(storageKey, jsonEncode(settings.toJson()));
}
```

## lib/features/onboarding/data/course_catalog.dart

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lessons/data/course_repository.dart';
import '../../lessons/domain/course.dart';

// Register additional bundled assets here to extend the language picker.
final courseCatalogPathsProvider = Provider<List<String>>(
  (ref) => [ref.watch(courseAssetPathProvider)],
);

final courseCatalogProvider = FutureProvider<List<Course>>((ref) async {
  final paths = ref.watch(courseCatalogPathsProvider);
  final repository = ref.watch(courseRepositoryProvider);
  return Future.wait(paths.map(repository.loadCourse));
}, retry: (count, error) => null);
```

## lib/features/onboarding/presentation/onboarding_controller.dart

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/course_catalog.dart';
import '../data/onboarding_repository.dart';
import '../domain/onboarding_settings.dart';

final onboardingProvider =
    AsyncNotifierProvider<OnboardingController, OnboardingSettings?>(
      OnboardingController.new,
      retry: (count, error) => null,
    );

class OnboardingController extends AsyncNotifier<OnboardingSettings?> {
  @override
  Future<OnboardingSettings?> build() =>
      ref.watch(onboardingRepositoryProvider).load();

  Future<void> complete(OnboardingSettings settings) async {
    await ref.read(onboardingRepositoryProvider).save(settings);
    if (ref.mounted) state = AsyncData(settings);
  }
}

final class OnboardingDraft {
  const OnboardingDraft({
    this.courseId,
    this.goalMinutes = 10,
    this.saving = false,
    this.error,
  });
  final String? courseId;
  final int goalMinutes;
  final bool saving;
  final String? error;
}

final onboardingFlowProvider =
    NotifierProvider<OnboardingFlowController, OnboardingDraft>(
      OnboardingFlowController.new,
    );

class OnboardingFlowController extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => const OnboardingDraft();

  void selectCourse(String courseId) {
    if (!state.saving) {
      state = OnboardingDraft(
        courseId: courseId,
        goalMinutes: state.goalMinutes,
      );
    }
  }

  void selectGoal(int minutes) {
    if (!state.saving && dailyGoalMinutes.contains(minutes)) {
      state = OnboardingDraft(courseId: state.courseId, goalMinutes: minutes);
    }
  }

  Future<void> finish() async {
    final draft = state;
    if (draft.saving || draft.courseId == null) return;
    state = OnboardingDraft(
      courseId: draft.courseId,
      goalMinutes: draft.goalMinutes,
      saving: true,
    );
    try {
      final courses = await ref.read(courseCatalogProvider.future);
      if (!courses.any((course) => course.id == draft.courseId)) {
        throw StateError('Selected course is unavailable');
      }
      await ref
          .read(onboardingProvider.notifier)
          .complete(
            OnboardingSettings(
              courseId: draft.courseId!,
              goalMinutes: draft.goalMinutes,
            ),
          );
      if (ref.mounted) {
        state = OnboardingDraft(
          courseId: draft.courseId,
          goalMinutes: draft.goalMinutes,
        );
      }
    } catch (_) {
      if (ref.mounted) {
        state = OnboardingDraft(
          courseId: draft.courseId,
          goalMinutes: draft.goalMinutes,
          error: 'Your choices could not be saved. Please try again.',
        );
      }
    }
  }
}
```

## lib/features/onboarding/presentation/onboarding_frame.dart

```dart
import 'package:flutter/material.dart';

import '../../../shared/widgets/responsive_body.dart';

class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
  });
  final int step;
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: step == 1,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) onBack?.call();
    },
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: onBack == null ? null : BackButton(onPressed: onBack),
        title: Text('Step $step of 3'),
      ),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: step / 3,
              semanticsLabel: 'Onboarding step $step of 3',
            ),
            const SizedBox(height: 32),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 32),
            child,
          ],
        ),
      ),
    ),
  );
}
```

## lib/features/onboarding/presentation/language_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/async_status_view.dart';
import '../../../shared/widgets/choice_card.dart';
import '../data/course_catalog.dart';
import 'onboarding_controller.dart';
import 'onboarding_frame.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(courseCatalogProvider);
    final selectedId = ref.watch(onboardingFlowProvider).courseId;
    return OnboardingFrame(
      step: 2,
      title: 'What would you like to learn?',
      subtitle: 'Choose a language to begin your journey.',
      onBack: () => context.go(AppRoutes.welcome),
      child: courses.when(
        skipLoadingOnRefresh: false,
        loading: () => const AsyncStatusView(
          message: 'Finding your languages…',
          loading: true,
        ),
        error: (error, stack) => AsyncStatusView(
          message: 'Languages could not be loaded.',
          onRetry: () => ref.invalidate(courseCatalogProvider),
        ),
        data: (items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (items.isEmpty)
              const Text('There are no languages available yet.'),
            for (final course in items)
              ChoiceCard(
                key: ValueKey('language-${course.id}'),
                title: course.targetLanguage,
                subtitle: 'For ${course.nativeLanguage} speakers',
                selected: course.id == selectedId,
                onTap: () => ref
                    .read(onboardingFlowProvider.notifier)
                    .selectCourse(course.id),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: items.any((course) => course.id == selectedId)
                  ? () => context.go(AppRoutes.dailyGoal)
                  : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## lib/features/onboarding/presentation/daily_goal_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/choice_card.dart';
import '../domain/onboarding_settings.dart';
import 'onboarding_controller.dart';
import 'onboarding_frame.dart';

class DailyGoalScreen extends ConsumerWidget {
  const DailyGoalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingFlowProvider);
    return OnboardingFrame(
      step: 3,
      title: 'Make a little time for learning',
      subtitle: 'Choose a daily goal that fits your day.',
      onBack: draft.saving ? null : () => context.go(AppRoutes.languages),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final minutes in dailyGoalMinutes)
            ChoiceCard(
              key: ValueKey('goal-$minutes'),
              title: '$minutes minutes',
              subtitle: switch (minutes) {
                5 => 'Start small',
                10 => 'Build a steady habit',
                _ => 'Make more time to practice',
              },
              icon: Icons.schedule,
              selected: minutes == draft.goalMinutes,
              onTap: draft.saving
                  ? null
                  : () => ref
                        .read(onboardingFlowProvider.notifier)
                        .selectGoal(minutes),
            ),
          if (draft.error != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                draft.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: draft.saving
                ? null
                : () => ref.read(onboardingFlowProvider.notifier).finish(),
            child: Text(draft.saving ? 'Saving…' : 'Start learning'),
          ),
        ],
      ),
    );
  }
}
```

## lib/features/onboarding/presentation/startup_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_status_view.dart';
import 'onboarding_controller.dart';

class StartupScreen extends ConsumerWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(onboardingProvider);
    return Scaffold(
      body: AsyncStatusView(
        message: settings.hasError
            ? 'Your preferences could not be loaded.'
            : 'Getting ready…',
        loading: !settings.hasError,
        onRetry: settings.hasError
            ? () => ref.invalidate(onboardingProvider)
            : null,
      ),
    );
  }
}
```

## lib/features/home/domain/learning_path.dart

```dart
import '../../lessons/domain/course.dart';
import '../../lessons/domain/lesson.dart';
import '../../lessons/domain/unit.dart';

enum LessonAvailability { locked, available, completed }

final class LessonRecord {
  const LessonRecord({
    required this.lessonId,
    required this.completed,
    required this.bestScore,
  });
  final String lessonId;
  final bool completed;
  final int bestScore;
}

final class LessonPathEntry {
  const LessonPathEntry({
    required this.lesson,
    required this.availability,
    required this.stars,
  });
  final Lesson lesson;
  final LessonAvailability availability;
  final int stars;
}

final class UnitPath {
  UnitPath({required this.unit, required List<LessonPathEntry> lessons})
    : lessons = List.unmodifiable(lessons);
  final Unit unit;
  final List<LessonPathEntry> lessons;
}

final class LearningPath {
  LearningPath({required this.course, required List<UnitPath> units})
    : units = List.unmodifiable(units);
  final Course course;
  final List<UnitPath> units;

  Iterable<LessonPathEntry> get lessons => units.expand((unit) => unit.lessons);

  LessonPathEntry? findLesson(String id) {
    for (final entry in lessons) {
      if (entry.lesson.id == id) return entry;
    }
    return null;
  }

  factory LearningPath.fromCourse(Course course, List<LessonRecord> records) {
    final progress = {for (final record in records) record.lessonId: record};
    var nextFound = false;
    final units = <UnitPath>[];
    for (final unit in course.units) {
      final entries = <LessonPathEntry>[];
      for (final lesson in unit.lessons) {
        final record = progress[lesson.id];
        final completed = record?.completed ?? false;
        final state = completed
            ? LessonAvailability.completed
            : nextFound
            ? LessonAvailability.locked
            : LessonAvailability.available;
        if (!completed) nextFound = true;
        final score = record?.bestScore ?? 0;
        entries.add(
          LessonPathEntry(
            lesson: lesson,
            availability: state,
            stars: completed
                ? (score >= 90
                      ? 3
                      : score >= 70
                      ? 2
                      : 1)
                : 0,
          ),
        );
      }
      units.add(UnitPath(unit: unit, lessons: entries));
    }
    return LearningPath(course: course, units: units);
  }
}
```

## lib/features/home/data/home_providers.dart

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../lessons/domain/course.dart';
import '../../onboarding/data/course_catalog.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import '../domain/learning_path.dart';

final selectedCourseProvider = FutureProvider<Course>((ref) async {
  final settings = await ref.watch(onboardingProvider.future);
  final courses = await ref.watch(courseCatalogProvider.future);
  for (final course in courses) {
    if (course.id == settings?.courseId) return course;
  }
  throw StateError('The selected course is unavailable');
}, retry: (count, error) => null);

final lessonProgressProvider = StreamProvider<List<LessonRecord>>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return database
      .select(database.lessonProgress)
      .watch()
      .map(
        (rows) => rows
            .map(
              (row) => LessonRecord(
                lessonId: row.lessonId,
                completed: row.completed,
                bestScore: row.bestScore,
              ),
            )
            .toList(),
      );
}, retry: (count, error) => null);

final userStatsProvider = StreamProvider<UserStatsRow>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return (database.select(
    database.userStats,
  )..where((table) => table.id.equals(1))).watchSingle();
}, retry: (count, error) => null);

final learningPathProvider = Provider<AsyncValue<LearningPath>>((ref) {
  final course = ref.watch(selectedCourseProvider);
  final progress = ref.watch(lessonProgressProvider);
  return course.when(
    skipLoadingOnRefresh: false,
    data: (course) => progress.when(
      skipLoadingOnRefresh: false,
      data: (records) => AsyncData(LearningPath.fromCourse(course, records)),
      error: (error, stack) => AsyncError(error, stack),
      loading: () => const AsyncLoading(),
    ),
    error: (error, stack) => AsyncError(error, stack),
    loading: () => const AsyncLoading(),
  );
});

void retryLearningPath(WidgetRef ref) {
  ref.invalidate(courseCatalogProvider);
  ref.invalidate(lessonProgressProvider);
}
```

## lib/features/home/presentation/learning_path_view.dart

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/lesson_path_node.dart';
import '../domain/learning_path.dart';

class LearningPathView extends StatelessWidget {
  const LearningPathView({
    super.key,
    required this.path,
    required this.goalMinutes,
  });
  final LearningPath path;
  final int goalMinutes;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: ListView.builder(
        key: const PageStorageKey('learning-path'),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        itemCount: path.units.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    path.course.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your daily goal: $goalMinutes minutes',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            );
          }
          final unit = path.units[index - 1];
          final offset = path.units
              .take(index - 1)
              .fold<int>(0, (count, unit) => count + unit.lessons.length);
          return _UnitSection(unit: unit, number: index, offset: offset);
        },
      ),
    ),
  );
}

class _UnitSection extends StatelessWidget {
  const _UnitSection({
    required this.unit,
    required this.number,
    required this.offset,
  });
  final UnitPath unit;
  final int number;
  final int offset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UNIT $number',
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  unit.unit.title,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: colors.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        for (var i = 0; i < unit.lessons.length; i++) ...[
          if (i > 0)
            Center(
              child: ExcludeSemantics(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  width: 3,
                  height: 28,
                  color: colors.outlineVariant,
                ),
              ),
            ),
          LessonPathNode(
            key: ValueKey('lesson-node-${unit.lessons[i].lesson.id}'),
            entry: unit.lessons[i],
            number: offset + i + 1,
            onPressed: unit.lessons[i].availability == LessonAvailability.locked
                ? null
                : () => context.push(
                    AppRoutes.lessonLocation(unit.lessons[i].lesson.id),
                  ),
          ),
        ],
        const SizedBox(height: 36),
      ],
    );
  }
}
```

## lib/features/home/presentation/user_stats_bar.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/stat_badge.dart';
import '../data/home_providers.dart';

class UserStatsBar extends ConsumerWidget {
  const UserStatsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
    child: ref
        .watch(userStatsProvider)
        .when(
          skipLoadingOnRefresh: false,
          loading: () => const LinearProgressIndicator(
            semanticsLabel: 'Loading streak and XP',
          ),
          error: (error, stack) => Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              const Text('Stats could not be loaded.'),
              TextButton(
                onPressed: () => ref.invalidate(userStatsProvider),
                child: const Text('Retry stats'),
              ),
            ],
          ),
          data: (stats) => Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              StatBadge(
                icon: Icons.local_fire_department_outlined,
                label:
                    '${stats.streak} ${stats.streak == 1 ? 'day' : 'days'} streak',
              ),
              StatBadge(icon: Icons.bolt, label: '${stats.xp} XP'),
            ],
          ),
        ),
  );
}
```

## lib/shared/widgets/responsive_body.dart

```dart
import 'package:flutter/material.dart';

class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: child,
        ),
      ),
    ),
  );
}
```

## lib/shared/widgets/async_status_view.dart

```dart
import 'package:flutter/material.dart';

import 'responsive_body.dart';

class AsyncStatusView extends StatelessWidget {
  const AsyncStatusView({
    super.key,
    required this.message,
    this.onRetry,
    this.loading = false,
  });
  final String message;
  final VoidCallback? onRetry;
  final bool loading;

  @override
  Widget build(BuildContext context) => ResponsiveBody(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading) ...[
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
        ],
        Semantics(
          liveRegion: true,
          child: Text(message, textAlign: TextAlign.center),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ],
    ),
  );
}
```

## lib/shared/widgets/choice_card.dart

```dart
import 'package:flutter/material.dart';

class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.icon = Icons.translate,
  });
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, color: colors.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: colors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

## lib/shared/widgets/stat_badge.dart

```dart
import 'package:flutter/material.dart';

class StatBadge extends StatelessWidget {
  const StatBadge({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: colors.onSecondaryContainer),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colors.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## lib/shared/widgets/lesson_path_node.dart

```dart
import 'package:flutter/material.dart';

import '../../features/home/domain/learning_path.dart';

class LessonPathNode extends StatelessWidget {
  const LessonPathNode({
    super.key,
    required this.entry,
    required this.number,
    this.onPressed,
  });
  final LessonPathEntry entry;
  final int number;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final completed = entry.availability == LessonAvailability.completed;
    final locked = entry.availability == LessonAvailability.locked;
    final label = switch (entry.availability) {
      LessonAvailability.locked => 'Locked',
      LessonAvailability.available => 'Up next',
      LessonAvailability.completed => 'Completed',
    };
    final foreground = completed
        ? colors.onTertiaryContainer
        : colors.onPrimary;
    return Semantics(
      label:
          'Lesson $number: ${entry.lesson.title}. $label${completed ? ', ${entry.stars} of 3 stars' : ''}.',
      button: true,
      enabled: !locked,
      onTap: locked ? null : onPressed,
      child: ExcludeSemantics(
        child: Column(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: FilledButton(
                onPressed: locked ? null : onPressed,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  backgroundColor: completed
                      ? colors.tertiaryContainer
                      : colors.primary,
                  foregroundColor: foreground,
                  disabledBackgroundColor: colors.surfaceContainerHighest,
                  disabledForegroundColor: colors.onSurfaceVariant,
                ),
                child: Icon(
                  locked
                      ? Icons.lock_outline
                      : completed
                      ? Icons.check
                      : Icons.play_arrow_rounded,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              entry.lesson.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            if (completed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    3,
                    (index) => Icon(
                      index < entry.stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 24,
                      color: colors.tertiary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

## test/support/phase3_fixtures.dart

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myapp/features/lessons/domain/course.dart';
import 'package:myapp/features/onboarding/data/onboarding_repository.dart';
import 'package:myapp/features/onboarding/domain/onboarding_settings.dart';

Course sampleCourse() => Course.fromJson(
  jsonDecode(File('assets/courses/japanese_basics.json').readAsStringSync())
      as Map<String, dynamic>,
);

OnboardingSettings completedSettings() =>
    OnboardingSettings(courseId: 'ja_basics_en', goalMinutes: 10);

class UnusedPreferences extends Fake implements SharedPreferencesAsync {}

class MemoryOnboardingRepository extends OnboardingRepository {
  MemoryOnboardingRepository({this.saved}) : super(UnusedPreferences());
  OnboardingSettings? saved;
  bool failLoad = false;
  bool failSave = false;
  int saveCalls = 0;
  Completer<void>? loadGate;
  Completer<void>? saveGate;

  @override
  Future<OnboardingSettings?> load() async {
    await loadGate?.future;
    if (failLoad) throw StateError('Read failure');
    return saved;
  }

  @override
  Future<void> save(OnboardingSettings settings) async {
    saveCalls++;
    await saveGate?.future;
    if (failSave) throw StateError('Write failure');
    saved = settings;
  }
}
```

## test/onboarding_repository_test.dart

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/features/onboarding/data/onboarding_repository.dart';
import 'package:myapp/features/onboarding/domain/onboarding_settings.dart';

class MockPreferences extends Mock implements SharedPreferencesAsync {}

void main() {
  late MockPreferences preferences;
  late OnboardingRepository repository;
  setUp(() {
    preferences = MockPreferences();
    repository = OnboardingRepository(preferences);
  });

  test('new installation has no saved choices', () async {
    when(() => preferences.getString(any())).thenAnswer((_) async => null);
    expect(await repository.load(), isNull);
  });

  test(
    'saves both choices in one document and reloads across instances',
    () async {
      String? stored;
      when(() => preferences.setString(any(), any())).thenAnswer((call) async {
        stored = call.positionalArguments[1] as String;
      });
      when(() => preferences.getString(any())).thenAnswer((_) async => stored);
      final settings = OnboardingSettings(
        courseId: 'ja_basics_en',
        goalMinutes: 15,
      );
      await repository.save(settings);
      verify(
        () => preferences.setString(
          OnboardingRepository.storageKey,
          jsonEncode(settings.toJson()),
        ),
      ).called(1);
      final reloaded = await OnboardingRepository(preferences).load();
      expect(reloaded!.courseId, settings.courseId);
      expect(reloaded.goalMinutes, 15);
    },
  );

  for (final corrupt in [
    '{broken',
    '{}',
    'null',
    '{"version":2}',
    '{"version":1,"courseId":"ja_basics_en","goalMinutes":7}',
  ]) {
    test('invalid stored choices restart onboarding: $corrupt', () async {
      when(() => preferences.getString(any())).thenAnswer((_) async => corrupt);
      expect(await repository.load(), isNull);
    });
  }

  test('storage read and write failures propagate for retry UI', () async {
    when(() => preferences.getString(any()))
        .thenThrow(StateError('Read failure'));
    when(() => preferences.setString(any(), any()))
        .thenAnswer((_) => Future.error(StateError('Write failure')));
    await expectLater(repository.load(), throwsStateError);
    await expectLater(
      repository.save(
        OnboardingSettings(courseId: 'ja_basics_en', goalMinutes: 5),
      ),
      throwsStateError,
    );
  });
}
```

## test/learning_path_test.dart

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/home/domain/learning_path.dart';

import 'support/phase3_fixtures.dart';

void main() {
  final course = sampleCourse();
  final lessons = course.units.expand((unit) => unit.lessons).toList();
  LessonRecord done(int index, [int score = 100]) => LessonRecord(
    lessonId: lessons[index].id,
    completed: true,
    bestScore: score,
  );

  test('only the first incomplete lesson is available', () {
    final path = LearningPath.fromCourse(course, []);
    expect(path.lessons.first.availability, LessonAvailability.available);
    expect(
      path.lessons
          .skip(1)
          .every((lesson) => lesson.availability == LessonAvailability.locked),
      isTrue,
    );
  });

  test('completion unlocks the next lesson across unit boundaries', () {
    final path = LearningPath.fromCourse(course, [done(0), done(1), done(2)]);
    expect(
      path.units.first.lessons.every(
        (lesson) => lesson.availability == LessonAvailability.completed,
      ),
      isTrue,
    );
    expect(
      path.units[1].lessons.first.availability,
      LessonAvailability.available,
    );
    expect(path.units[1].lessons[1].availability, LessonAvailability.locked);
  });

  test('an incomplete high score does not unlock the next lesson', () {
    final path = LearningPath.fromCourse(course, [
      LessonRecord(
        lessonId: lessons.first.id,
        completed: false,
        bestScore: 100,
      ),
    ]);
    expect(path.lessons.first.availability, LessonAvailability.available);
    expect(path.lessons.first.stars, 0);
    expect(path.lessons.elementAt(1).availability, LessonAvailability.locked);
  });

  test('completed scores map to one, two and three stars', () {
    final path = LearningPath.fromCourse(course, [
      done(0, 69),
      done(1, 70),
      done(2, 90),
    ]);
    expect(path.lessons.take(3).map((lesson) => lesson.stars), [1, 2, 3]);
  });

  test('all completed leaves no available lesson', () {
    final path = LearningPath.fromCourse(course, [
      for (var i = 0; i < lessons.length; i++) done(i),
    ]);
    expect(
      path.lessons.every(
        (lesson) => lesson.availability == LessonAvailability.completed,
      ),
      isTrue,
    );
  });

  test('out-of-order or stale records never unlock two incomplete lessons', () {
    final path = LearningPath.fromCourse(course, [
      done(2),
      const LessonRecord(
        lessonId: 'obsolete-id',
        completed: true,
        bestScore: 100,
      ),
    ]);
    expect(
      path.lessons.where(
        (lesson) => lesson.availability == LessonAvailability.available,
      ),
      hasLength(1),
    );
    expect(path.lessons.first.availability, LessonAvailability.available);
    expect(path.findLesson('missing'), isNull);
  });
}
```

## lib/core/constants/app_routes.dart

```dart
abstract final class AppRoutes {
  static const welcome = '/welcome';
  static const startup = '/startup';
  static const languages = '/languages';
  static const dailyGoal = '/daily-goal';
  static const home = '/home';
  static const lesson = '/lesson/:id';
  static const review = '/review';
  static const profile = '/profile';

  static String lessonLocation(String id) =>
      '/lesson/${Uri.encodeComponent(id)}';
}
```

## lib/core/router/app_router.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/flashcards/presentation/review_screen.dart';
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
```

## lib/features/onboarding/presentation/welcome_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_routes.dart';
import 'onboarding_frame.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final colors = Theme.of(context).colorScheme;
    return OnboardingFrame(
      step: 1,
      title: config.appName,
      subtitle: 'A new language. A little practice. Every day.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.translate,
                size: 48,
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            config.hasLanguagePair
                ? 'Learn ${config.targetLanguage} with guidance in ${config.nativeLanguage}.'
                : 'Start a learning habit that fits your life.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => context.go(AppRoutes.languages),
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }
}
```

## lib/features/home/presentation/learn_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../shared/widgets/async_status_view.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import '../data/home_providers.dart';
import 'learning_path_view.dart';
import 'user_stats_bar.dart';

class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(learningPathProvider);
    final goal = ref.watch(onboardingProvider).value?.goalMinutes ?? 10;
    return Scaffold(
      appBar: AppBar(title: Text(ref.watch(appConfigProvider).appName)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const UserStatsBar(),
            Expanded(
              child: path.when(
                skipLoadingOnRefresh: false,
                loading: () => const AsyncStatusView(
                  message: 'Loading your learning path…',
                  loading: true,
                ),
                error: (error, stack) => AsyncStatusView(
                  message: 'Your lessons could not be loaded.',
                  onRetry: () => retryLearningPath(ref),
                ),
                data: (path) => path.lessons.isEmpty
                    ? const AsyncStatusView(
                        message: 'There are no lessons in this course yet.',
                      )
                    : LearningPathView(path: path, goalMinutes: goal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## lib/features/lessons/presentation/lesson_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/async_status_view.dart';
import '../../../shared/widgets/placeholder_page.dart';
import '../../home/data/home_providers.dart';
import '../../home/domain/learning_path.dart';

class LessonScreen extends ConsumerWidget {
  const LessonScreen({super.key, required this.lessonId});
  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(learningPathProvider)
      .when(
        skipLoadingOnRefresh: false,
        loading: () => Scaffold(
          appBar: AppBar(),
          body: const AsyncStatusView(
            message: 'Loading lesson…',
            loading: true,
          ),
        ),
        error: (error, stack) => Scaffold(
          appBar: AppBar(),
          body: AsyncStatusView(
            message: 'This lesson could not be loaded.',
            onRetry: () => retryLearningPath(ref),
          ),
        ),
        data: (path) {
          final entry = path.findLesson(lessonId);
          final locked = entry?.availability == LessonAvailability.locked;
          return PlaceholderPage(
            title: entry == null
                ? 'Lesson not found'
                : locked
                ? 'Lesson locked'
                : entry.lesson.title,
            message: entry == null
                ? 'This lesson is not part of your course.'
                : locked
                ? 'Complete the earlier lessons to unlock this one.'
                : 'Lesson ID: $lessonId\nExercises will be added in a future phase.',
            action: FilledButton.tonal(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Back to Learn'),
            ),
          );
        },
      );
}
```

## test/widget_test.dart

```dart
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app/app.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/core/router/app_router.dart';
import 'package:myapp/features/home/data/home_providers.dart';
import 'package:myapp/features/home/domain/learning_path.dart';
import 'package:myapp/features/lessons/domain/course.dart';
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
  }) {
    this.repository = repository ?? MemoryOnboardingRepository(saved: settings);
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        onboardingRepositoryProvider.overrideWithValue(this.repository),
        appDatabaseProvider.overrideWithValue(database),
        appConfigProvider.overrideWithValue(
          const AppConfig(appName: 'Test App'),
        ),
        courseCatalogProvider.overrideWith((ref) async {
          if (catalogFails) throw StateError('Catalog failure');
          return catalogGate?.future ?? [course];
        }),
        if (statsError)
          userStatsProvider.overrideWith(
            (ref) => Stream.error(StateError('Stats error')),
          ),
      ],
    );
  }
  final course = sampleCourse();
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
    expect(find.textContaining('Lesson ID: ja_greetings'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('tabs, locked and unknown lesson routes remain usable', (
    tester,
  ) async {
    final harness = AppHarness(settings: completedSettings());
    await mount(tester, harness);
    await tapText(tester, 'Review');
    expect(
      find.text('Flashcard reviews will appear here in a future phase.'),
      findsOneWidget,
    );
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    expect(
      find.text('Your profile will appear here in a future phase.'),
      findsOneWidget,
    );
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
```

## README.md

````markdown
# Language learning app - Phases 1 through 3

This project contains Material 3 light/dark themes, Riverpod, go_router,
three-step onboarding, a learning path, and placeholder lesson, Review, and Profile screens.
Phase 2 adds course content, immutable models, asset loading, and Drift tables.
Phase 3 connects onboarding preferences and database progress to the interface.
Backend integration and learning logic belong to later phases.

## Create a separate project

Replace MYHANDLE and app_name before running. Keep app_name lowercase_with_underscores.
Do not recreate the existing project to run it.

```powershell
flutter doctor -v
flutter create --org com.MYHANDLE --project-name app_name app_name
cd app_name
```

The existing project keeps package name myapp and its existing native identifiers.
Changing the org flag only affects newly created projects. In another package,
replace package:myapp/ imports in tests with package:app_name/.

## Android setup and run

Your current doctor output reports missing Android SDK Command-line Tools and
unknown Android license status. In Android Studio, open Tools > SDK Manager >
SDK Tools, install Android SDK Command-line Tools (latest), and then run:

```powershell
flutter doctor --android-licenses
flutter doctor -v
cd C:\Langunge_flutter\myapp
flutter pub get
flutter emulators
flutter emulators --launch Medium_Phone_API_37.0
flutter devices
```

Wait until the emulator boots. Use the Android device ID printed by flutter devices
(e.g. emulator-5554, which can vary):

```powershell
flutter run -d emulator-5554 --dart-define="APP_NAME=My Language App" --dart-define="TARGET_LANGUAGE=Japanese" --dart-define="NATIVE_LANGUAGE=English"
```

Press r for hot reload, R for hot restart, and q to quit. Change dart-defines by
stopping and rerunning. AppConfig uses dart-defines; flutter_dotenv is installed
but no .env file or asset registration is needed in this phase.
Client configuration is not a place for private server credentials.

## Verify

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Widget tests cover welcome configuration, all bottom tabs, lesson IDs, back
navigation, direct routes, an unknown route, and 320x568 layouts at 200% text
scale in both light and dark themes. An Android build has not been verified.

## Structure

- lib/app: root app widget.
- lib/core/config: compile-time configuration.
- lib/core/theme: shared ColorScheme and typography.
- lib/core/constants: route constants.
- lib/core/router: go_router configuration.
- lib/core/utils: reserved for shared utilities.
- lib/features/{onboarding,home,lessons,exercises,flashcards,profile}/:
  each feature has data, domain, and presentation folders.
- lib/shared/widgets: reusable widgets.

Empty folders have empty .gitkeep files so Git can retain them.
ProviderScope supplies Riverpod providers, much like React context.
ConsumerWidget can watch those providers and rebuild when their values change.
StatefulShellRoute.indexedStack keeps each bottom tab's navigation state.
context.go changes location; context.push stacks a page so Back returns to Learn.
ThemeMode.system follows the device light/dark setting. The text theme inherits
platform fonts, then customizes weights and line heights.

## Dependencies and Git

Direct dependency versions were checked against pub.dev's latest stable metadata.
drift_dev and build_runner are dev dependencies for the Drift database generator;
see the Phase 2 commands below to regenerate it after schema edits.
Commit pubspec.lock in this application to reproduce resolved dependencies.
.gitignore excludes build output, local env files, SDK paths, and signing files.
This directory currently has no Git repository; initialize one when ready.
See PHASE1_FILES.md for complete setup file contents and the dependency lockfile.

## Phase 2: content and persistence

Sample language assumption: Japanese for English speakers. The registered asset
is assets/courses/japanese_basics.json: 1 course, 2 units, 3 lessons per unit,
6 exercises per lesson, and 60 common words/phrases (10 per lesson). Topics are
greetings, people, numbers, food, places, and actions. Example sentences may
include supporting vocabulary beyond the 60 study entries. Audio URLs are optional
and omitted because no recordings have been supplied.

All content models are handwritten immutable classes. Their lists are copied
into unmodifiable lists, and fromJson rejects missing/invalid required fields.
Exercises use a sealed hierarchy with a type discriminator in JSON.

CourseRepository loads the Flutter asset through an injectable AssetBundle.
courseProvider is a FutureProvider<Course>, so consumers receive an AsyncValue
that represents loading, data, or an error. Phase 3 uses the course catalog to
connect the selected course to Learn and lesson placeholder screens.
The sample path can be overridden via COURSE_ASSET using --dart-define; any
replacement asset must also be registered in pubspec.yaml. App display language
configuration does not translate or select content automatically.

The Drift database lives in lib/core/database/app_database.dart and is exposed
through appDatabaseProvider. It opens lazily when a consumer first queries it.
Only Drift infrastructure uses code generation; the content models do not.
Tables use IDs matching content IDs, but no SQL foreign keys reference the JSON
asset. Word dueDate is required; completedAt and lastActiveDate are nullable.
bestScore is a percentage from 0 to 100. UserStats adds an internal primary key
restricted to 1, ensuring one local user's stats row, initialized on creation.
No XP, streak, scoring, or spaced-repetition algorithms are implemented yet.

After editing the database schema, regenerate its code:

```powershell
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

Keep app_database.g.dart with the source, and do not edit it manually. Schema
version is 1; later schema changes will need a version bump and a migration.
The native database setup targets Android/iOS/desktop; running the database on
web requires Drift's separate web worker/WASM setup in a later phase.

Tests check every required sample field for missing and null values, JSON round
trips, optional audio, immutable collections, exercise validation, duplicate IDs,
broken word references, injected/registered asset loading, database defaults,
progress round trips, and database constraints. SQLite tests use an in-memory DB.
See PHASE2_FILES.md for the short JSON schema table and every Phase 2 file in full.

## Phase 3: onboarding and Learn

First launch follows /welcome -> /languages -> /daily-goal. A language must be
selected before continuing. Daily goals are 5, 10, or 15 minutes (default 10).
OnboardingRepository stores the selected course ID and goal in one versioned JSON
document using SharedPreferencesAsync. Completion is published to Riverpod only
after saving succeeds, so a failed save stays on the goal screen with a retry.
A startup screen handles asynchronous preference loading and read errors.
Returning launches redirect to /home; completed users cannot revisit onboarding
routes. System Back preserves choices when moving between onboarding steps.

The language list is driven by courseCatalogPathsProvider. It starts with the
Japanese asset selected by courseAssetPathProvider. Add another registered asset
to the catalog to extend the choices; labels come from the course metadata.
Course IDs are stable preference keys, so changing a label does not lose selection.

Learn displays unit sections and round lesson nodes. A pure LearningPath model
flattens lessons in JSON order: the first incomplete lesson is available; later
incomplete lessons are locked; completed lessons remain open. The database's
completed flag controls unlocking, even when an unfinished lesson has a score.
Completed scores earn 1 star below 70%, 2 at 70-89%, and 3 at 90-100%.
LessonProgress and UserStats are observed with Riverpod StreamProviders: new
records update the path, XP, and streak without restarting or manually refreshing.
No completion, XP award, streak calculation, or exercise gameplay is added here.
The tests insert progress records to exercise the unlocking behavior.

Tapping an available/completed node pushes /lesson/:id. Direct links to locked
or unknown lesson IDs show explanatory pages. Loading/error states have friendly
messages and retry actions; stats failures do not hide the learning path.

Shared widgets provide responsive page bodies, loading/error feedback, choice
cards, wrapping stat badges, and accessible lesson nodes. Tests exercise 320x568
screens at 200% text scale in light and dark themes, including scrolling to unit 2.

```powershell
cd C:\Langunge_flutter\myapp
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d emulator-5554
```

Use your Android device ID in the final command. No dependency or database schema
changes were needed for Phase 3, so there is no new database generation step.
To manually test onboarding, complete the steps, quit, and reopen the app: Learn
should open directly. To see onboarding again in development, clear this app's
storage through Android Settings (this also clears its local database).
See PHASE3_FILES.md for the file manifest and full Phase 3 code.
````

