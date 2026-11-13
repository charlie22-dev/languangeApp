import 'package:flutter/material.dart';

import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';
import '../../../shared/widgets/answer_option.dart';
import '../../../shared/widgets/audio_speaker_button.dart';
import '../../../shared/widgets/lingo_components.dart';
import '../domain/exercise.dart';

class ListeningView extends StatefulWidget {
  const ListeningView({
    super.key,
    required this.exercise,
    required this.enabled,
    required this.selectedIndex,
    required this.value,
    required this.onSelected,
    required this.onChanged,
    required this.onSubmitted,
    this.feedbackCorrect,
  });
  final Listening exercise;
  final bool enabled;
  final int? selectedIndex;
  final String value;
  final ValueChanged<int> onSelected;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final bool? feedbackCorrect;
  @override
  State<ListeningView> createState() => _ListeningViewState();
}

class _ListeningViewState extends State<ListeningView> {
  bool _unavailable = false;
  bool _reveal = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.l10n.text(
          widget.exercise.options.isEmpty ? 'listenAndType' : 'listenAndChoose',
        ),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: LingoSpace.s16),
      AudioSpeakerButton(
        text: widget.exercise.audioText,
        audioUrl: widget.exercise.audioUrl,
        enabled: widget.enabled,
        onUnavailable: () => setState(() => _unavailable = true),
      ),
      if (_unavailable)
        LingoButton.ghost(
          onPressed: () => setState(() => _reveal = true),
          child: Text(context.l10n.text('showAudioTranscript')),
        ),
      if (_reveal) Text(widget.exercise.audioText),
      const SizedBox(height: LingoSpace.s16),
      if (widget.exercise.options.isEmpty)
        TextFormField(
          key: const ValueKey('listening-input'),
          initialValue: widget.value,
          readOnly: !widget.enabled,
          autocorrect: false,
          enableSuggestions: false,
          minLines: 1,
          maxLines: 4,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: context.l10n.text('heardText'),
          ),
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.enabled ? (_) => widget.onSubmitted() : null,
        )
      else
        for (var i = 0; i < widget.exercise.options.length; i++)
          AnswerOption(
            label: widget.exercise.options[i],
            selected: widget.selectedIndex == i,
            onTap: widget.enabled ? () => widget.onSelected(i) : null,
            status: widget.selectedIndex == i && widget.feedbackCorrect != null
                ? (widget.feedbackCorrect!
                      ? AnswerVisualState.correct
                      : AnswerVisualState.wrong)
                : AnswerVisualState.normal,
          ),
    ],
  );
}
