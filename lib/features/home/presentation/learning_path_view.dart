import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/lesson_path_node.dart';
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
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: ListView.builder(
        key: const PageStorageKey('learning-path'),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        itemCount: path.units.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    path.course.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your daily goal: $goalMinutes minutes',
                    style: Theme.of(context).textTheme.bodyLarge,
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Semantics(
            header: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UNIT $number',
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  unit.unit.title,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: colors.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        for (var i = 0; i < unit.lessons.length; i++) ...[
          if (i > 0)
            Center(
              child: ExcludeSemantics(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  width: 3,
                  height: 28,
                  color: colors.outlineVariant,
                ),
              ),
            ),
          LessonPathNode(
            key: ValueKey('lesson-node-${unit.lessons[i].lesson.id}'),
            entry: unit.lessons[i],
            number: offset + i + 1,
            onPressed: unit.lessons[i].availability == LessonAvailability.locked
                ? null
                : () => context.push(
                    AppRoutes.lessonLocation(unit.lessons[i].lesson.id),
                  ),
          ),
        ],
        const SizedBox(height: 36),
      ],
    );
  }
}
