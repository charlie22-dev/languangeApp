import '../../../shared/widgets/lingo_components.dart';
import '../../../core/localization/lingo_localizations.dart';

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
          body: AsyncStatusView(
            message: context.l10n.text('ui8966e65028'),
            loading: true,
          ),
        ),
        error: (error, stack) => Scaffold(
          appBar: AppBar(),
          body: AsyncStatusView(
            message: context.l10n.text('uief65719d1c'),
            onRetry: () => retryLearningPath(ref),
          ),
        ),
        data: (path) {
          final entry = path.findLesson(lessonId);
          final locked = entry?.availability == LessonAvailability.locked;
          if (entry != null && !locked) {
            if (entry.lesson.exercises.isEmpty) {
              return PlaceholderPage(
                title: context.l10n.text('ui7a3ec4daa4'),
                message: context.l10n.text('ui992010f71a'),
              );
            }
            return LessonRunner(key: ValueKey(lessonId), lesson: entry.lesson);
          }
          return PlaceholderPage(
            title: entry == null
                ? context.l10n.text('lessonNotFound')
                : context.l10n.text('ui4411672e28'),
            message: entry == null
                ? context.l10n.text('ui1ff2458dce')
                : context.l10n.text('ui54a1d32a01'),
            action: LingoButton.tonal(
              onPressed: () => context.go(AppRoutes.home),
              child: Text(context.l10n.text('ui3469f4bb98')),
            ),
          );
        },
      );
}
