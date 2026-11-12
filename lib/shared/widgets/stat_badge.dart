import '../../core/theme/lingo_tokens.dart';

import 'package:flutter/material.dart';

class StatBadge extends StatelessWidget {
  const StatBadge({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LingoSpace.s16,
            vertical: LingoSpace.s8,
          ),
          decoration: BoxDecoration(
            color: icon == Icons.bolt
                ? colors.primaryContainer
                : icon == Icons.local_fire_department_outlined
                ? colors.errorContainer
                : colors.secondaryContainer,
            borderRadius: BorderRadius.circular(LingoRadii.pill),
            border: Border.all(color: colors.outline, width: LingoSpace.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: colors.onSecondaryContainer),
              const SizedBox(width: LingoSpace.s8),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: colors.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
