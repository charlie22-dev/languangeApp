import '../../../shared/widgets/lingo_components.dart';
import '../../../core/localization/lingo_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/lesson_status_header.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../domain/lesson.dart';
import '../domain/lesson_session.dart';
import 'exercise_content.dart';
import 'lesson_action_bar.dart';
import 'lesson_controller.dart';
import 'results_screen.dart';
import '../../../shared/widgets/pip_mascot.dart';

class LessonRunner extends ConsumerStatefulWidget {
  const LessonRunner({super.key, required this.lesson});
  final Lesson lesson;

  @override
  ConsumerState<LessonRunner> createState() => _LessonRunnerState();
}

class _LessonRunnerState extends ConsumerState<LessonRunner> {
  bool _exitDialogOpen = false;

  Future<void> _requestExit() async {
    final session = ref.read(lessonControllerProvider(widget.lesson));
    if (session.saving || _exitDialogOpen) return;
    if (session.phase == LessonPhase.finished &&
        (session.saved || !session.result!.success)) {
      context.go(AppRoutes.home);
      return;
    }
    _exitDialogOpen = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const PipMascot(mood: PipMood.sad),
        title: Text(context.l10n.text('ui8d0ec552c7')),
        content: Text(
          session.phase == LessonPhase.finished
              ? context.l10n.text('ui6bf00cbfa1')
              : context.l10n.text('uif01124363e'),
        ),
        actions: [
          LingoButton.ghost(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.text('uiae768f766f')),
          ),
          LingoButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.text('ui7e3520a973')),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (leave == true && mounted) context.go(AppRoutes.home);
  }

  void _check() {
    FocusScope.of(context).unfocus();
    ref.read(lessonControllerProvider(widget.lesson).notifier).check();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(lessonControllerProvider(widget.lesson));
    final controller = ref.read(
      lessonControllerProvider(widget.lesson).notifier,
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestExit();
      },
      child: session.phase == LessonPhase.finished
          ? ResultsScreen(
              session: session,
              onContinue: () => context.go(AppRoutes.home),
              onRetry: controller.saveResult,
              onClose: _requestExit,
            )
          : Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                title: Text(widget.lesson.title),
                leading: IconButton(
                  tooltip: context.l10n.text('uif816925e28'),
                  onPressed: _requestExit,
                  icon: const Icon(Icons.close),
                ),
              ),
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => Column(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.25,
                        ),
                        child: SingleChildScrollView(
                          child: LessonStatusHeader(
                            cleared: session.correctCount,
                            total: session.originalCount,
                            hearts: session.hearts,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ResponsiveBody(
                          child: ExerciseContent(
                            key: ValueKey(
                              '${session.currentIndex}:${session.currentExercise!.id}',
                            ),
                            session: session,
                            controller: controller,
                            onCheck: _check,
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.5,
                        ),
                        child: SingleChildScrollView(
                          child: LessonActionBar(
                            session: session,
                            onCheck: _check,
                            onContinue: controller.continueLesson,
                            feedbackMaxHeight: constraints.maxHeight * 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
