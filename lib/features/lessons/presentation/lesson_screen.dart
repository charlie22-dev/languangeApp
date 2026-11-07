import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/async_status_view.dart';
import '../../../shared/widgets/placeholder_page.dart';
import '../../home/data/home_providers.dart';
import '../../home/domain/learning_path.dart';
import 'lesson_runner.dart';

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
          if (entry != null && !locked) {
            if (entry.lesson.exercises.isEmpty) {
              return const PlaceholderPage(
                title: 'Lesson unavailable',
                message: 'This lesson has no exercises yet.',
              );
            }
            return LessonRunner(key: ValueKey(lessonId), lesson: entry.lesson);
          }
          return PlaceholderPage(
            title: entry == null ? 'Lesson not found' : 'Lesson locked',
            message: entry == null
                ? 'This lesson is not part of your course.'
                : 'Complete the earlier lessons to unlock this one.',
            action: FilledButton.tonal(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Back to Learn'),
            ),
          );
        },
      );
}
