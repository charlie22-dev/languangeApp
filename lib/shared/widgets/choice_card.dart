import 'package:flutter/material.dart';

import '../../core/theme/lingo_tokens.dart';
import 'lingo_components.dart';

class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.icon = Icons.translate,
  });
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.onPrimary : colors.onSurface;
    return Semantics(
      selected: selected,
      button: true,
      enabled: onTap != null,
      child: PressFeedback(
        enabled: onTap != null,
        child: Card(
          color: selected ? colors.primaryContainer : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LingoRadii.control),
            side: BorderSide(color: colors.outline, width: LingoSpace.border),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(LingoSpace.s16),
              child: Row(
                children: [
                  Icon(icon, color: foreground),
                  const SizedBox(width: LingoSpace.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: foreground),
                        ),
                        const SizedBox(height: LingoSpace.s8),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: foreground),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: LingoSpace.s8),
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: foreground,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
