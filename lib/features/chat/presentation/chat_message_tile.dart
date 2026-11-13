import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';
import '../../../shared/widgets/lingo_components.dart';
import '../data/chat_vocabulary_providers.dart';
import '../domain/chat_models.dart';
import 'chat_controller.dart';

class ChatMessageTile extends StatefulWidget {
  const ChatMessageTile({super.key, required this.message});
  final ChatMessage message;
  @override
  State<ChatMessageTile> createState() => _ChatMessageTileState();
}

class _ChatMessageTileState extends State<ChatMessageTile> {
  bool _translated = false;
  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    return Column(
      crossAxisAlignment: message.fromUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (message.fromUser)
          ChatBubble(message: message.content, fromUser: true)
        else
          InkWell(
            onTap: () => setState(() => _translated = !_translated),
            child: ChatBubble(message: message.content, fromUser: false),
          ),
        if (!message.fromUser && message.translation != null) ...[
          TextButton(
            onPressed: () => setState(() => _translated = !_translated),
            child: Text(
              context.l10n.text(
                _translated ? 'chatHideTranslation' : 'chatTranslate',
              ),
            ),
          ),
          if (_translated) Text(message.translation!),
        ],
        if (message.pending) Text(context.l10n.text('chatNotSent')),
        for (final correction in message.corrections)
          _CorrectionCard(correction: correction),
        if (message.newWords.isNotEmpty)
          ExpansionTile(
            title: Text(
              context.l10n.text('chatNewWords', {
                'count': message.newWords.length,
              }),
            ),
            children: [
              for (final word in message.newWords)
                _SuggestedWordCard(word: word),
            ],
          ),
      ],
    );
  }
}

class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({required this.correction});
  final ChatCorrection correction;
  @override
  Widget build(BuildContext context) => LingoPanel(
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(context.l10n.text('chatGentleCorrection')),
      children: [
        Text(
          correction.original,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(decoration: TextDecoration.lineThrough),
        ),
        Text(
          correction.corrected,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: LingoSpace.s8),
        Text(correction.explanation),
      ],
    ),
  );
}

class _SuggestedWordCard extends ConsumerWidget {
  const _SuggestedWordCard({required this.word});
  final SuggestedWord word;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = vocabularyKey(word.text);
    final saved =
        ref.watch(savedChatWordTextsProvider).asData?.value.contains(key) ??
        false;
    final saving =
        ref
            .watch(chatControllerProvider)
            .asData
            ?.value
            .savingWords
            .contains(key) ??
        false;
    return LingoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(word.text, style: Theme.of(context).textTheme.titleLarge),
          Text(word.translation),
          const SizedBox(height: LingoSpace.s8),
          Text(word.example),
          Text(word.exampleTranslation),
          LingoButton.outlined(
            onPressed: saved || saving
                ? null
                : () =>
                      ref.read(chatControllerProvider.notifier).saveWord(word),
            child: Text(
              context.l10n.text(
                saved
                    ? 'chatWordSaved'
                    : saving
                    ? 'chatWordSaving'
                    : 'chatSaveWord',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
