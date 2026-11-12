import '../../core/localization/lingo_localizations.dart';
import '../../core/theme/lingo_tokens.dart';

import 'dart:math';

import 'package:flutter/material.dart';

import '../../features/flashcards/domain/word.dart';

class FlippableFlashcard extends StatelessWidget {
  const FlippableFlashcard({
    super.key,
    required this.word,
    required this.revealed,
    required this.onFlip,
  });
  final Word word;
  final bool revealed;
  final VoidCallback? onFlip;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: revealed
          ? context.l10n.text('showWord')
          : context.l10n.text('ui1abc8584ad'),
      child: Material(
        color: colors.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LingoRadii.card),
          side: BorderSide(color: colors.outline, width: LingoSpace.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('flashcard-flip'),
          onTap: onFlip,
          child: AnimatedSwitcher(
            duration: reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 550),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) => AnimatedBuilder(
              animation: animation,
              child: child,
              builder: (context, child) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY((1 - animation.value) * pi / 2),
                child: Opacity(opacity: animation.value, child: child),
              ),
            ),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.center,
              children: [
                for (final child in previous) ExcludeSemantics(child: child),
                ?current,
              ],
            ),
            child: _CardFace(
              key: ValueKey('${word.id}:$revealed'),
              word: word,
              revealed: revealed,
            ),
          ),
        ),
      ),
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({super.key, required this.word, required this.revealed});
  final Word word;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimaryContainer;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 240),
      padding: const EdgeInsets.all(LingoSpace.s24),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: color),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              word.text,
              textAlign: TextAlign.center,
              style:
                  (revealed
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.headlineLarge)
                      ?.copyWith(color: color),
            ),
            if (revealed) ...[
              const SizedBox(height: LingoSpace.s16),
              Text(
                word.translation,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(color: color),
              ),
              const SizedBox(height: LingoSpace.s24),
              const Divider(),
              const SizedBox(height: LingoSpace.s16),
              Text(
                word.example,
                style: theme.textTheme.bodyLarge?.copyWith(color: color),
              ),
              const SizedBox(height: LingoSpace.s8),
              Text(word.exampleTranslation),
            ],
            const SizedBox(height: LingoSpace.s24),
            Text(
              revealed
                  ? context.l10n.text('showWordAgain')
                  : context.l10n.text('ui8e80e16b5c'),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
