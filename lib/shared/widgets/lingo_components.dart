import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/lingo_localizations.dart';
import '../../core/theme/lingo_tokens.dart';
import 'pip_mascot.dart';

enum LingoButtonKind { primary, tonal, outlined, ghost }

/// One celebration pulse, rather than a permanent animation on a reading screen.
class CelebrationPulse extends StatelessWidget {
  const CelebrationPulse({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeInOut,
      builder: (context, t, child) => Transform.rotate(
        angle: math.sin(t * math.pi * 2) * 3 * math.pi / 180,
        child: Transform.scale(
          scale: 1 + math.sin(t * math.pi) * .16,
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class LingoButton extends StatelessWidget {
  const LingoButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  }) : kind = LingoButtonKind.primary,
       icon = null;
  const LingoButton.tonal({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  }) : kind = LingoButtonKind.tonal,
       icon = null;
  const LingoButton.outlined({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  }) : kind = LingoButtonKind.outlined,
       icon = null;
  const LingoButton.ghost({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  }) : kind = LingoButtonKind.ghost,
       icon = null;
  const LingoButton.outlinedIcon({
    super.key,
    required this.onPressed,
    required this.icon,
    required Widget label,
    this.style,
  }) : kind = LingoButtonKind.outlined,
       child = label;
  const LingoButton.ghostIcon({
    super.key,
    required this.onPressed,
    required this.icon,
    required Widget label,
    this.style,
  }) : kind = LingoButtonKind.ghost,
       child = label;
  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final ButtonStyle? style;
  final LingoButtonKind kind;
  @override
  Widget build(BuildContext context) {
    final button = switch (kind) {
      LingoButtonKind.primary => FilledButton(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
      LingoButtonKind.tonal => FilledButton.tonal(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
      LingoButtonKind.outlined =>
        icon == null
            ? OutlinedButton(onPressed: onPressed, style: style, child: child)
            : OutlinedButton.icon(
                onPressed: onPressed,
                style: style,
                icon: icon!,
                label: child,
              ),
      LingoButtonKind.ghost =>
        icon == null
            ? TextButton(onPressed: onPressed, style: style, child: child)
            : TextButton.icon(
                onPressed: onPressed,
                style: style,
                icon: icon!,
                label: child,
              ),
    };
    return PressFeedback(enabled: onPressed != null, child: button);
  }
}

class LingoPanel extends StatelessWidget {
  const LingoPanel({super.key, required this.child, this.color});
  final Widget child;
  final Color? color;
  @override
  Widget build(BuildContext context) => Card(
    color: color,
    child: Padding(padding: const EdgeInsets.all(LingoSpace.s24), child: child),
  );
}

class LingoEmptyState extends StatelessWidget {
  const LingoEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.mood = PipMood.sleepy,
    this.action,
  });
  final String title;
  final String message;
  final PipMood mood;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      PipMascot(mood: mood),
      const SizedBox(height: LingoSpace.s24),
      Text(
        title,
        style: Theme.of(context).textTheme.headlineMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: LingoSpace.s16),
      Text(message, textAlign: TextAlign.center),
      if (action != null) ...[const SizedBox(height: LingoSpace.s24), action!],
    ],
  );
}

class LingoSkeleton extends StatelessWidget {
  const LingoSkeleton({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Column(
      children: [
        for (final width in [
          double.infinity,
          LingoSpace.node * 2,
          LingoSpace.node,
        ])
          Container(
            width: width,
            height: LingoSpace.s16,
            margin: const EdgeInsets.only(bottom: LingoSpace.s16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(LingoRadii.control),
            ),
          ),
      ],
    ),
  );
}

class PressFeedback extends StatefulWidget {
  const PressFeedback({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: widget.enabled
        ? (_) {
            setState(() => pressed = true);
            HapticFeedback.selectionClick();
          }
        : null,
    onPointerUp: (_) => setState(() => pressed = false),
    onPointerCancel: (_) => setState(() => pressed = false),
    child: AnimatedScale(
      scale: pressed && !MediaQuery.disableAnimationsOf(context) ? 0.95 : 1.0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: widget.child,
    ),
  );
}

class LingoProgress extends StatelessWidget {
  const LingoProgress({super.key, required this.value, required this.label});
  final double value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(
        color: Theme.of(context).colorScheme.outline,
        width: LingoSpace.border,
      ),
      borderRadius: BorderRadius.circular(LingoRadii.pill),
    ),
    clipBehavior: Clip.antiAlias,
    child: LinearProgressIndicator(
      value: value.clamp(0, 1),
      semanticsLabel: label,
    ),
  );
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.fromUser = false,
    this.correction,
  });
  final String message;
  final bool fromUser;
  final String? correction;
  @override
  Widget build(BuildContext context) => Align(
    alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
    child: LingoPanel(
      color: fromUser ? Theme.of(context).colorScheme.secondaryContainer : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: fromUser
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : null,
            ),
          ),
          if (correction != null)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              iconColor: fromUser
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : Theme.of(context).colorScheme.onSurface,
              collapsedIconColor: fromUser
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : Theme.of(context).colorScheme.onSurface,
              title: Text(
                context.l10n.text('correction'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: fromUser
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              children: [
                Text(
                  correction!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: fromUser
                        ? Theme.of(context).colorScheme.onSecondaryContainer
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

/// Shows a real target, never an invented elapsed-minutes percentage.
class DailyGoalCard extends StatelessWidget {
  const DailyGoalCard({
    super.key,
    required this.minutes,
    required this.label,
    this.detail,
    this.progress = 0,
    this.complete = false,
  });
  final int minutes;
  final String label;
  final String? detail;
  final double progress;
  final bool complete;
  @override
  Widget build(BuildContext context) => LingoPanel(
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleLarge),
              if (detail != null) Text(detail!),
            ],
          ),
        ),
        const SizedBox(width: LingoSpace.s16),
        Semantics(
          label: label,
          value: '${(progress * 100).round()}%',
          child: SizedBox.square(
            dimension: LingoSpace.node,
            child: CustomPaint(
              painter: _GoalRing(Theme.of(context).colorScheme, progress),
              child: Center(
                child: Icon(
                  complete ? Icons.check : Icons.bolt,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _GoalRing extends CustomPainter {
  const _GoalRing(this.colors, this.progress);
  final double progress;
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawCircle(
      rect.center,
      size.shortestSide / 2 - LingoSpace.s8,
      Paint()
        ..color = colors.surfaceContainerHighest
        ..style = PaintingStyle.stroke
        ..strokeWidth = LingoSpace.s8,
    );
    canvas.drawCircle(
      rect.center,
      size.shortestSide / 2 - LingoSpace.s8,
      Paint()
        ..color = colors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = LingoSpace.border,
    );
    final arc = Rect.fromCircle(
      center: rect.center,
      radius: size.shortestSide / 2 - LingoSpace.s8,
    );
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0, 1),
      false,
      Paint()
        ..color = colors.onSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = LingoSpace.s8
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_GoalRing oldDelegate) =>
      oldDelegate.colors != colors || oldDelegate.progress != progress;
}
