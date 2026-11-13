import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/presentation/settings_controller.dart';
import '../../core/localization/lingo_localizations.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/exercises/domain/exercise_grader.dart';
import '../../core/theme/lingo_tokens.dart';

class AnswerFeedbackSheet extends ConsumerStatefulWidget {
  const AnswerFeedbackSheet({super.key, required this.feedback});
  final AnswerFeedback feedback;
  @override
  ConsumerState<AnswerFeedbackSheet> createState() =>
      _AnswerFeedbackSheetState();
}

class _AnswerFeedbackSheetState extends ConsumerState<AnswerFeedbackSheet> {
  @override
  void initState() {
    super.initState();
    if (ref.read(practiceSettingsProvider).asData?.value.sound == true) {
      unawaited(
        SystemSound.play(
          widget.feedback.correct
              ? SystemSoundType.click
              : SystemSoundType.alert,
        ).catchError((Object _) {}),
      );
    }
    if (widget.feedback.correct) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedback = widget.feedback;
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onPrimary;
    final content = Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(LingoSpace.s16),
        decoration: BoxDecoration(
          color: feedback.correct
              ? context.lingo.success
              : theme.colorScheme.errorContainer,
          border: Border.all(
            color: theme.colorScheme.outline,
            width: LingoSpace.border,
          ),
          borderRadius: BorderRadius.circular(LingoRadii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  feedback.correct
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: foreground,
                ),
                const SizedBox(width: LingoSpace.s8),
                Expanded(
                  child: Text(
                    feedback.correct
                        ? context.l10n.text('correctTitle')
                        : context.l10n.text('ui756c76607b'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: LingoSpace.s8),
            Text(
              context.l10n.text('uid23f4d3d4e', {
                'arg0': (feedback.correctAnswer),
              }),
              style: theme.textTheme.bodyLarge?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return content;
    return TweenAnimationBuilder<double>(
      key: ValueKey(feedback),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(
          feedback.correct
              ? 0
              : math.sin(t * math.pi * 6) * (1 - t) * LingoSpace.s8,
          0,
        ),
        child: Transform.scale(
          scale: feedback.correct ? _answerPop(t) : 1.0,
          child: child,
        ),
      ),
      child: content,
    );
  }
}

double _answerPop(double t) => t < .55
    ? .85 + .23 * Curves.easeOutCubic.transform(t / .55)
    : 1.08 - .08 * Curves.easeOutCubic.transform((t - .55) / .45);
