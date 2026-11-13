import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';
import '../../../shared/widgets/speech_permission_dialog.dart';
import '../../audio/presentation/chat_dictation_controller.dart';
import 'chat_controller.dart';

class ChatInputBar extends ConsumerStatefulWidget {
  const ChatInputBar({super.key, required this.enabled});
  final bool enabled;
  @override
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final _text = TextEditingController();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final text = _text.text.trim();
    if (!widget.enabled || text.isEmpty) return;
    if (text.runes.length > 500) {
      ref.read(chatControllerProvider.notifier).send(text);
      return;
    }
    ref.read(chatControllerProvider.notifier).send(text);
    _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final dictation = ref.watch(chatDictationProvider);
    ref.listen(chatDictationProvider, (previous, next) {
      if (next.text != previous?.text) {
        _text.value = TextEditingValue(
          text: next.text,
          selection: TextSelection.collapsed(offset: next.text.length),
        );
      }
    });
    return Padding(
      padding: const EdgeInsets.all(LingoSpace.s8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dictation.error != null)
            Text(context.l10n.text(dictation.error!)),
          if (dictation.busy)
            Semantics(
              liveRegion: true,
              child: Text(
                context.l10n.text(
                  dictation.preparing ? 'speechPreparing' : 'speechListening',
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: context.l10n.text(
                  dictation.recording ? 'stopRecording' : 'startRecording',
                ),
                icon: Icon(
                  dictation.recording
                      ? Icons.stop_circle_outlined
                      : Icons.mic_none,
                ),
                onPressed: !widget.enabled || dictation.preparing
                    ? null
                    : () async {
                        final controller = ref.read(
                          chatDictationProvider.notifier,
                        );
                        if (dictation.recording) {
                          await controller.stop();
                          return;
                        }
                        final allowed = await showSpeechPermissionDialog(
                          context,
                          bodyKey: 'chatMicExplanation',
                          declineKey: 'notNow',
                        );
                        if (allowed == true && mounted) {
                          await controller.start(_text.text);
                        }
                      },
              ),
              Expanded(
                child: TextField(
                  key: const ValueKey('chat-input'),
                  controller: _text,
                  enabled: widget.enabled,
                  readOnly: dictation.busy,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 500,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    labelText: context.l10n.text('chatInputLabel'),
                  ),
                  onSubmitted: dictation.busy ? null : (_) => _send(),
                ),
              ),
              IconButton(
                tooltip: context.l10n.text('chatSend'),
                icon: const Icon(Icons.send_outlined),
                onPressed: widget.enabled && !dictation.busy ? _send : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
