import '../../../shared/widgets/lingo_components.dart';
import '../../../core/localization/lingo_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/lingo_tokens.dart';
import '../../home/data/home_providers.dart';
import '../domain/exercise.dart';

class TypeTranslationView extends ConsumerStatefulWidget {
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
  ConsumerState<TypeTranslationView> createState() =>
      _TypeTranslationViewState();
}

class _TypeTranslationViewState extends ConsumerState<TypeTranslationView> {
  late final TextEditingController input = TextEditingController(
    text: widget.value,
  );
  final focus = FocusNode();
  @override
  void didUpdateWidget(TypeTranslationView old) {
    super.didUpdateWidget(old);
    if (input.text != widget.value) {
      input.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    input.dispose();
    focus.dispose();
    super.dispose();
  }

  void append(String character) {
    final selection = input.selection;
    final start = selection.isValid ? selection.start : input.text.length;
    final end = selection.isValid ? selection.end : start;
    final text = input.text.replaceRange(start, end, character);
    input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + character.length),
    );
    widget.onChanged(text);
    focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref
        .watch(selectedCourseProvider)
        .asData
        ?.value
        .targetLanguage
        .toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.exercise.prompt,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: LingoSpace.s24),
        TextFormField(
          key: const ValueKey('translation-input'),
          controller: input,
          focusNode: focus,
          readOnly: !widget.enabled,
          minLines: 1,
          maxLines: 4,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: context.l10n.text('ui9586b55b35'),
          ),
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.enabled ? (_) => widget.onSubmitted() : null,
        ),
        if (language == 'spanish' || language == 'es') ...[
          const SizedBox(height: LingoSpace.s16),
          Wrap(
            spacing: LingoSpace.s8,
            runSpacing: LingoSpace.s8,
            children: [
              for (final accent
                  in context.l10n.text('spanishAccents').split(''))
                LingoButton.outlined(
                  onPressed: widget.enabled ? () => append(accent) : null,
                  child: Text(accent),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
