import '../../home/data/home_providers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/lingo_localizations.dart';
import '../../../shared/widgets/lingo_components.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../../../shared/widgets/pip_mascot.dart';
import '../../../core/theme/lingo_tokens.dart';
import '../domain/chat_models.dart';
import 'chat_controller.dart';
import 'chat_input_bar.dart';
import 'chat_message_tile.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final language =
        ref.watch(selectedCourseProvider).asData?.value.targetLanguage ??
        context.l10n.text('selectedLanguage');
    ref.listen(chatControllerProvider, (previous, next) {
      if (previous?.asData?.value.messages.length !=
              next.asData?.value.messages.length ||
          previous?.asData?.value.sending != next.asData?.value.sending) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      }
    });
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.text('chat'))),
      body: SafeArea(
        child: chat.when(
          loading: () => const Center(child: LingoSkeleton()),
          error: (error, stack) => ResponsiveBody(
            child: LingoEmptyState(
              title: context.l10n.text('chatTitle'),
              message: context.l10n.text('chatStorageError'),
              action: LingoButton(
                onPressed: () => ref.invalidate(chatControllerProvider),
                child: Text(context.l10n.text('chatRetry')),
              ),
            ),
          ),
          data: (state) => LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * .25,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(LingoSpace.s8),
                    child: Wrap(
                      spacing: LingoSpace.s8,
                      runSpacing: LingoSpace.s8,
                      children: [
                        for (final scenario in ChatScenario.values)
                          ChoiceChip(
                            label: Text(context.l10n.text(scenario.labelKey)),
                            selected: state.scenario == scenario,
                            onSelected: state.sending
                                ? null
                                : (_) => ref
                                      .read(chatControllerProvider.notifier)
                                      .selectScenario(scenario),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: state.messages.isEmpty
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.all(LingoSpace.s16),
                          child: LingoEmptyState(
                            title: context.l10n.text('chatTitle'),
                            message: context.l10n.text('chatStartPrompt', {
                              'language': language,
                            }),
                            mood: PipMood.thinking,
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(LingoSpace.s16),
                          itemCount:
                              state.messages.length + (state.sending ? 1 : 0),
                          itemBuilder: (context, index) =>
                              index == state.messages.length
                              ? Semantics(
                                  liveRegion: true,
                                  child: Text(context.l10n.text('chatTyping')),
                                )
                              : Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: LingoSpace.s16,
                                  ),
                                  child: ChatMessageTile(
                                    key: ValueKey(state.messages[index].id),
                                    message: state.messages[index],
                                  ),
                                ),
                        ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * .45,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!state.sending &&
                            (state.error != null || state.pending != null))
                          Padding(
                            padding: const EdgeInsets.all(LingoSpace.s8),
                            child: Column(
                              children: [
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    context.l10n.text(
                                      state.error ?? 'chatPendingRetry',
                                    ),
                                  ),
                                ),
                                Wrap(
                                  spacing: LingoSpace.s8,
                                  children: [
                                    if (state.pending != null)
                                      TextButton(
                                        onPressed: ref
                                            .read(
                                              chatControllerProvider.notifier,
                                            )
                                            .retry,
                                        child: Text(
                                          context.l10n.text('chatRetry'),
                                        ),
                                      ),
                                    if (state.pending != null)
                                      TextButton(
                                        onPressed: ref
                                            .read(
                                              chatControllerProvider.notifier,
                                            )
                                            .discardPending,
                                        child: Text(
                                          context.l10n.text('chatDiscard'),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        if (state.wordError != null)
                          Text(context.l10n.text(state.wordError!)),
                        ChatInputBar(
                          key: ValueKey(state.scenario),
                          enabled: !state.sending && state.pending == null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
