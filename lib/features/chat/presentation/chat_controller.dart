import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/data/home_providers.dart';
import '../data/chat_api.dart';
import '../data/chat_repository.dart';
import '../domain/chat_models.dart';

class ChatState {
  ChatState({
    required this.scenario,
    required List<ChatMessage> messages,
    this.sending = false,
    this.error,
    this.wordError,
    Set<String> savingWords = const {},
  }) : messages = List.unmodifiable(messages),
       savingWords = Set.unmodifiable(savingWords);
  final ChatScenario scenario;
  final List<ChatMessage> messages;
  final bool sending;
  final String? error, wordError;
  final Set<String> savingWords;
  ChatMessage? get pending => messages.where((m) => m.pending).lastOrNull;
  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? sending,
    String? error,
    String? wordError,
    bool clearError = false,
    bool clearWordError = false,
    Set<String>? savingWords,
  }) => ChatState(
    scenario: scenario,
    messages: messages ?? this.messages,
    sending: sending ?? this.sending,
    error: clearError ? null : error ?? this.error,
    wordError: clearWordError ? null : wordError ?? this.wordError,
    savingWords: savingWords ?? this.savingWords,
  );
}

final chatControllerProvider = AsyncNotifierProvider<ChatController, ChatState>(
  ChatController.new,
  retry: (count, error) => null,
);

class ChatController extends AsyncNotifier<ChatState> {
  int _generation = 0;
  @override
  Future<ChatState> build() async {
    _generation++;
    final repository = ref.watch(chatRepositoryProvider);
    final scenario = await repository.lastScenario();
    return ChatState(
      scenario: scenario,
      messages: await repository.load(scenario),
    );
  }

  Future<void> selectScenario(ChatScenario scenario) async {
    final current = state.asData?.value;
    if (current == null || current.sending || current.scenario == scenario) {
      return;
    }
    final repository = ref.read(chatRepositoryProvider);
    final generation = ++_generation;
    state = const AsyncLoading();
    try {
      final messages = await repository.load(scenario);
      if (ref.mounted && generation == _generation) {
        state = AsyncData(ChatState(scenario: scenario, messages: messages));
      }
    } catch (error, stack) {
      if (ref.mounted && generation == _generation) {
        state = AsyncError(error, stack);
      }
    }
  }

  Future<void> send(String text) async {
    final current = state.asData?.value;
    if (current == null || current.sending || current.pending != null) return;
    final value = text.trim();
    if (value.isEmpty || value.runes.length > 500) {
      state = AsyncData(current.copyWith(error: 'chatMessageLimit'));
      return;
    }
    final repository = ref.read(chatRepositoryProvider);
    final generation = _generation;
    state = AsyncData(current.copyWith(sending: true, clearError: true));
    try {
      final user = await repository.addUser(value, current.scenario);
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        current.copyWith(
          messages: [
            ...current.messages,
            user,
          ].reversed.take(20).toList().reversed.toList(),
          sending: true,
        ),
      );
      await _reply(user, repository, generation);
    } catch (_) {
      if (ref.mounted && generation == _generation) {
        state = AsyncData(
          state.asData!.value.copyWith(
            sending: false,
            error: 'chatStorageError',
          ),
        );
      }
    }
  }

  Future<void> retry() async {
    final current = state.asData?.value;
    final pending = current?.pending;
    if (current == null || pending == null || current.sending) return;
    state = AsyncData(current.copyWith(sending: true, clearError: true));
    await _reply(pending, ref.read(chatRepositoryProvider), _generation);
  }

  Future<void> _reply(
    ChatMessage user,
    ChatRepository repository,
    int generation,
  ) async {
    try {
      final api = await ref.read(chatApiProvider.future);
      if (!ref.mounted || generation != _generation) return;
      final current = state.asData!.value;
      // Limit the same-scenario context to 20 messages and 6000 code points.
      final history = <ChatMessage>[];
      var length = 0;
      for (final message in current.messages.reversed) {
        if (message.id > user.id) continue;
        if (length + message.content.runes.length > 6000) break;
        history.insert(0, message);
        length += message.content.runes.length;
      }
      final turn = await api.send(history, current.scenario);
      if (!ref.mounted || generation != _generation) return;
      await repository.complete(user, turn);
      final messages = await repository.load(current.scenario);
      if (ref.mounted && generation == _generation) {
        state = AsyncData(
          state.asData!.value.copyWith(messages: messages, sending: false),
        );
      }
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      try {
        await repository.markFailed(user.id);
      } catch (_) {
        /* Keep the persisted pending turn retryable. */
      }
      if (!ref.mounted || generation != _generation) return;
      state = AsyncData(
        state.asData!.value.copyWith(
          sending: false,
          error: error is ChatFailure ? error.key : 'chatUnavailable',
        ),
      );
    }
  }

  Future<void> discardPending() async {
    final current = state.asData?.value;
    if (current == null || current.sending || current.pending == null) return;
    final repository = ref.read(chatRepositoryProvider);
    final generation = _generation;
    state = AsyncData(current.copyWith(sending: true, clearError: true));
    try {
      await repository.discard(current.pending!.id);
      final messages = await repository.load(current.scenario);
      if (ref.mounted && generation == _generation) {
        state = AsyncData(
          current.copyWith(messages: messages, clearError: true),
        );
      }
    } catch (_) {
      if (ref.mounted && generation == _generation) {
        state = AsyncData(current.copyWith(error: 'chatStorageError'));
      }
    }
  }

  Future<void> saveWord(SuggestedWord word) async {
    final current = state.asData?.value;
    final key = vocabularyKey(word.text);
    if (current == null || current.savingWords.contains(key)) return;
    final generation = _generation;
    final repository = ref.read(chatRepositoryProvider);
    state = AsyncData(
      current.copyWith(
        savingWords: {...current.savingWords, key},
        clearWordError: true,
      ),
    );
    String? error;
    try {
      final course = await ref.read(selectedCourseProvider.future);
      if (!ref.mounted || generation != _generation) return;
      await repository.saveWord(word, course);
    } catch (_) {
      error = 'chatWordSaveError';
    }
    if (!ref.mounted || generation != _generation) return;
    state = AsyncData(
      state.asData!.value.copyWith(
        savingWords: {...state.asData!.value.savingWords}..remove(key),
        wordError: error,
      ),
    );
  }
}
