import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/lingo_tokens.dart';
import '../../core/localization/lingo_localizations.dart';
import 'lingo_components.dart';

enum AnswerVisualState { normal, selected, correct, wrong }

class AnswerOption extends StatelessWidget {
  const AnswerOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.pairLabel,
    this.status = AnswerVisualState.normal,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final String? pairLabel;
  final AnswerVisualState status;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = status == AnswerVisualState.normal && selected
        ? AnswerVisualState.selected
        : status;
    final background = switch (state) {
      AnswerVisualState.normal => colors.surface,
      AnswerVisualState.selected => colors.secondaryContainer,
      AnswerVisualState.correct => context.lingo.success,
      AnswerVisualState.wrong => colors.errorContainer,
    };
    final foreground = state == AnswerVisualState.normal
        ? colors.onSurface
        : colors.onPrimary;
    return Semantics(
      label:
          state == AnswerVisualState.correct || state == AnswerVisualState.wrong
          ? context.l10n.text(state.name)
          : null,
      selected: selected,
      button: true,
      enabled: onTap != null,
      child: PressFeedback(
        enabled: onTap != null,
        child: Card(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LingoRadii.control),
            side: BorderSide(color: colors.outline, width: LingoSpace.border),
          ),
          child: InkWell(
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: LingoSpace.touch),
              child: Padding(
                padding: const EdgeInsets.all(LingoSpace.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state == AnswerVisualState.correct ||
                        state == AnswerVisualState.wrong)
                      Icon(
                        state == AnswerVisualState.correct
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        color: foreground,
                      ),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (pairLabel != null) ...[
                      const SizedBox(height: LingoSpace.s8),
                      Text(
                        pairLabel!,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: foreground),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
