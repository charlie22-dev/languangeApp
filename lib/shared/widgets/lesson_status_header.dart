import 'package:flutter/material.dart';

class LessonStatusHeader extends StatelessWidget {
  const LessonStatusHeader({
    super.key,
    required this.cleared,
    required this.total,
    required this.hearts,
  });
  final int cleared;
  final int total;
  final int hearts;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : cleared / total,
                semanticsLabel:
                    'Lesson progress: $cleared of $total exercises cleared',
              ),
            ),
            const SizedBox(width: 16),
            Semantics(
              label: '$hearts hearts remaining',
              liveRegion: true,
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    3,
                    (index) => Icon(
                      index < hearts ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '$cleared of $total exercises cleared',
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    ),
  );
}
