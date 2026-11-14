import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';
import '../../../shared/widgets/lesson_path_node.dart';
import '../../activity/presentation/daily_goal_progress.dart';
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
  Widget build(BuildContext context) {
    // Build lightweight row descriptions, not a whole unit's widgets at once.
    final rows = <_PathRow>[];
    var lessonNumber = 0;
    for (var unitIndex = 0; unitIndex < path.units.length; unitIndex++) {
      final unit = path.units[unitIndex];
      rows.add(_UnitRow(unit, unitIndex + 1));
      for (var i = 0; i < unit.lessons.length; i++) {
        if (i > 0) {
          rows.add(_ConnectorRow(i, unit.lessons[i].lesson.id));
        }
        rows.add(_LessonRow(unit.lessons[i], ++lessonNumber, i));
      }
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: LingoSpace.contentWidth),
        child: ListView.builder(
          key: const PageStorageKey('learning-path'),
          padding: const EdgeInsets.fromLTRB(
            LingoSpace.s24,
            LingoSpace.s8,
            LingoSpace.s24,
            LingoSpace.s32,
          ),
          itemCount: rows.length + 1,
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
                    DailyGoalProgress(minutes: goalMinutes),
                  ],
                ),
              );
            }
            final row = rows[index - 1];
            return switch (row) {
              _UnitRow() => Padding(
                key: ValueKey('unit-header-${row.unit.unit.id}'),
                padding: EdgeInsets.only(
                  top: index == 1 ? 0 : LingoSpace.s32,
                  bottom: LingoSpace.s24,
                ),
                child: _UnitHeader(unit: row.unit, number: row.number),
              ),
              _ConnectorRow() => ExcludeSemantics(
                key: ValueKey('connector-${row.id}'),
                child: SizedBox(
                  height: LingoSpace.s32,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _PathConnector(
                      from: _nodeAlignment(row.index - 1),
                      to: _nodeAlignment(row.index),
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ),
              _LessonRow() => Align(
                key: ValueKey('lesson-row-${row.entry.lesson.id}'),
                alignment: Alignment(_nodeAlignment(row.index), 0),
                child: FractionallySizedBox(
                  widthFactor: .7,
                  child: LessonPathNode(
                    key: ValueKey('lesson-node-${row.entry.lesson.id}'),
                    entry: row.entry,
                    number: row.number,
                    onPressed:
                        row.entry.availability == LessonAvailability.locked
                        ? null
                        : () => context.push(
                            AppRoutes.lessonLocation(row.entry.lesson.id),
                          ),
                  ),
                ),
              ),
            };
          },
        ),
      ),
    );
  }
}

sealed class _PathRow {
  const _PathRow();
}

class _UnitRow extends _PathRow {
  const _UnitRow(this.unit, this.number);
  final UnitPath unit;
  final int number;
}

class _ConnectorRow extends _PathRow {
  const _ConnectorRow(this.index, this.id);
  final int index;
  final String id;
}

class _LessonRow extends _PathRow {
  const _LessonRow(this.entry, this.number, this.index);
  final LessonPathEntry entry;
  final int number, index;
}

class _UnitHeader extends StatelessWidget {
  const _UnitHeader({required this.unit, required this.number});
  final UnitPath unit;
  final int number;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
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
