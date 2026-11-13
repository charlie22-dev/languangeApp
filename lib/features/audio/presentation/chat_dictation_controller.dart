import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/audio_service.dart';
import '../data/speech_service.dart';

class DictationState {
  const DictationState({
    this.text = '',
    this.preparing = false,
    this.recording = false,
    this.error,
  });
  final String text;
  final bool preparing, recording;
  final String? error;
  bool get busy => preparing || recording;
}

final chatDictationProvider =
    NotifierProvider.autoDispose<ChatDictationController, DictationState>(
      ChatDictationController.new,
    );

class ChatDictationController extends Notifier<DictationState> {
  final _owner = Object();
  @override
  DictationState build() {
    final service = ref.watch(speechServiceProvider);
    ref.onDispose(() => unawaited(service.cancel(owner: _owner)));
    return const DictationState();
  }

  Future<void> start(String existing) async {
    if (state.busy) return;
    final locale = ref.read(pronunciationLocaleProvider);
    if (locale == null) {
      state = DictationState(text: existing, error: 'speechLocaleUnavailable');
      return;
    }
    state = DictationState(text: existing, preparing: true);
    try {
      if (ref.read(audioServiceProvider.exists)) {
        await ref.read(audioServiceProvider).stop();
      }
      if (!ref.mounted) return;
      final speech = ref.read(speechServiceProvider);
      await speech.listen(
        owner: _owner,
        locale: locale,
        onWords: (text, finalResult) {
          if (!ref.mounted) return;
          final combined = '${existing.trim()} ${text.trim()}'.trim();
          state = DictationState(
            text: String.fromCharCodes(combined.runes.take(500)),
            recording: !finalResult,
            error: combined.runes.length > 500 ? 'chatMessageLimit' : null,
          );
        },
        onStatus: (recording) {
          if (ref.mounted) {
            state = DictationState(
              text: state.text,
              recording: recording,
              error: state.error,
            );
          }
        },
        onError: (error) {
          if (ref.mounted) {
            state = DictationState(text: state.text, error: error);
          }
        },
      );
      if (ref.mounted) {
        state = DictationState(
          text: state.text,
          recording: speech.listeningFor(_owner),
          error: state.error,
        );
      }
    } on SpeechFailure catch (error) {
      if (ref.mounted) {
        state = DictationState(text: state.text, error: error.key);
      }
    } catch (_) {
      if (ref.mounted) {
        state = DictationState(text: state.text, error: 'speechUnavailable');
      }
    }
  }

  Future<void> stop() async {
    try {
      await ref.read(speechServiceProvider).stop(_owner);
    } catch (_) {
      if (ref.mounted) {
        state = DictationState(text: state.text, error: 'speechUnavailable');
      }
    }
  }
}
