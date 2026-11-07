import 'package:flutter/material.dart';

import '../domain/exercise.dart';

class TypeTranslationView extends StatelessWidget {
  const TypeTranslationView({
    super.key,
    required this.exercise,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
  });
  final TypeTranslation exercise;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(exercise.prompt, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 24),
      TextFormField(
        key: const ValueKey('translation-input'),
        initialValue: value,
        readOnly: !enabled,
        minLines: 1,
        maxLines: 4,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Your translation',
          border: OutlineInputBorder(),
        ),
        onChanged: onChanged,
        onFieldSubmitted: enabled ? (_) => onSubmitted() : null,
      ),
    ],
  );
}
