import '../../../shared/widgets/lingo_components.dart';
import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/answer_feedback_sheet.dart';
import '../domain/lesson_session.dart';

class LessonActionBar extends StatelessWidget {
  const LessonActionBar({
    super.key,
    required this.session,
    required this.onCheck,
    required this.onContinue,
    required this.feedbackMaxHeight,
  });
  final LessonSession session;
  final VoidCallback onCheck;
  final VoidCallback onContinue;
  final double feedbackMaxHeight;

  @override
  Widget build(BuildContext context) {
    final feedback = session.phase == LessonPhase.feedback;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LingoSpace.s24,
        LingoSpace.s8,
        LingoSpace.s24,
        LingoSpace.s16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (feedback) ...[
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: feedbackMaxHeight),
              child: SingleChildScrollView(
                child: AnswerFeedbackSheet(feedback: session.feedback!),
              ),
            ),
            const SizedBox(height: LingoSpace.s8),
          ],
          LingoButton(
            onPressed: feedback
                ? onContinue
                : session.canCheck
                ? onCheck
                : null,
            child: Text(
              feedback
                  ? context.l10n.text('continueAction')
                  : context.l10n.text('ui4b5e84be0e'),
            ),
          ),
        ],
      ),
    );
  }
}
