import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../exercises/domain/exercise.dart';
import '../data/audio_service.dart';
import '../data/speech_service.dart';
import '../../exercises/domain/exercise_grader.dart';

class SpeakingState {
  const SpeakingState({
    this.preparing = false,
    this.recording = false,
    this.transcript = '',
    this.error,
    this.score,
  });
  final bool preparing, recording;
  final String transcript;
  final String? error;
  final double? score;
  bool get busy => preparing || recording;
}

final speakingControllerProvider = NotifierProvider.autoDispose
    .family<SpeakingController, SpeakingState, Speaking>(
      SpeakingController.new,
    );

class SpeakingController extends Notifier<SpeakingState> {
  SpeakingController(this.exercise);
  final Speaking exercise;
  final _owner = Object();
  @override
  SpeakingState build() {
    final service = ref.watch(speechServiceProvider);
    ref.onDispose(() => unawaited(service.cancel(owner: _owner)));
    return const SpeakingState();
  }

  void _status(bool recording) {
    if (!ref.mounted) return;
    state = SpeakingState(
      recording: recording,
      transcript: state.transcript,
      error: state.error,
      score: !recording && state.transcript.isNotEmpty
          ? scoreSpeaking(exercise, state.transcript)
          : null,
    );
  }

  Future<void> start(String? locale) async {
    if (state.busy) return;
    if (locale == null) {
      state = const SpeakingState(error: 'speechLocaleUnavailable');
      return;
    }
    state = const SpeakingState(preparing: true);
    try {
      await ref.read(audioServiceProvider).stop();
      if (!ref.mounted) return;
      final service = ref.read(speechServiceProvider);
      await service.listen(
        owner: _owner,
        locale: locale,
        onWords: (text, finalResult) {
          if (!ref.mounted) return;
          state = SpeakingState(
            recording: !finalResult,
            transcript: text,
            score: finalResult ? scoreSpeaking(exercise, text) : null,
          );
        },
        onStatus: _status,
        onError: (key) {
          if (ref.mounted) {
            state = SpeakingState(transcript: state.transcript, error: key);
          }
        },
      );
      if (ref.mounted && state.error == null) {
        _status(service.listeningFor(_owner));
      }
    } on SpeechFailure catch (error) {
      if (ref.mounted) state = SpeakingState(error: error.key);
    } catch (_) {
      if (ref.mounted) state = const SpeakingState(error: 'speechUnavailable');
    }
  }

  Future<void> stop() async {
    try {
      await ref.read(speechServiceProvider).stop(_owner);
    } catch (_) {
      if (ref.mounted) state = const SpeakingState(error: 'speechUnavailable');
    }
  }

  Future<void> cancel() =>
      ref.read(speechServiceProvider).cancel(owner: _owner);
}
