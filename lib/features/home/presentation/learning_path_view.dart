import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/lesson_path_node.dart';
import '../domain/learning_path.dart';
import '../../../shared/widgets/lingo_components.dart';

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
        padding: const EdgeInsets.fromLTRB(
          LingoSpace.s24,
          LingoSpace.s8,
          LingoSpace.s24,
          LingoSpace.s32,
        ),
        itemCount: path.units.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: LingoSpace.s24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    path.course.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: LingoSpace.s8),
                  DailyGoalCard(
                    minutes: goalMinutes,
                    label: context.l10n.text('uied25d2bddd', {
                      'arg0': (goalMinutes),
                    }),
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
          padding: const EdgeInsets.all(LingoSpace.s16),
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(LingoRadii.card),
            border: Border.all(color: colors.outline, width: LingoSpace.border),
          ),
          child: Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.text('uiabbfe9b13c', {'arg0': (number)}),
                  style: TextStyle(
                    color: colors.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: LingoSpace.s8),
                Text(
                  unit.unit.title,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: colors.onSecondaryContainer),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: LingoSpace.s24),
        for (var i = 0; i < unit.lessons.length; i++) ...[
          if (i > 0)
            ExcludeSemantics(
              child: SizedBox(
                height: LingoSpace.s32,
                width: double.infinity,
                child: CustomPaint(
                  painter: _PathConnector(
                    from: _nodeAlignment(i - 1),
                    to: _nodeAlignment(i),
                    color: colors.outline,
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment(_nodeAlignment(i), 0),
            child: FractionallySizedBox(
              widthFactor: .7,
              child: LessonPathNode(
                key: ValueKey('lesson-node-${unit.lessons[i].lesson.id}'),
                entry: unit.lessons[i],
                number: offset + i + 1,
                onPressed:
                    unit.lessons[i].availability == LessonAvailability.locked
                    ? null
                    : () => context.push(
                        AppRoutes.lessonLocation(unit.lessons[i].lesson.id),
                      ),
              ),
            ),
          ),
        ],
        const SizedBox(height: LingoSpace.s32),
      ],
    );
  }
}

double _nodeAlignment(int index) => switch (index % 3) {
  0 => -.85,
  1 => .85,
  _ => 0,
};

class _PathConnector extends CustomPainter {
  const _PathConnector({
    required this.from,
    required this.to,
    required this.color,
  });
  final double from;
  final double to;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final x1 = size.width * (.5 + from * .15);
    final x2 = size.width * (.5 + to * .15);
    final path = Path()
      ..moveTo(x1, 0)
      ..cubicTo(x1, size.height * .5, x2, size.height * .5, x2, size.height);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = LingoSpace.border
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_PathConnector old) =>
      old.from != from || old.to != to || old.color != color;
}
