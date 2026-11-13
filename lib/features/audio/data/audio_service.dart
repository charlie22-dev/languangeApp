import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import '../../home/data/home_providers.dart';
import '../domain/audio_ports.dart';
import '../domain/language_locale.dart';
import 'audio_cache.dart';

final pronunciationLocaleProvider = Provider<String?>((ref) {
  final course = ref.watch(selectedCourseProvider).asData?.value;
  return course?.targetLocale ??
      (course == null ? null : localeForLanguage(course.targetLanguage));
});
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService(
    output: PlayerAudioOutput(),
    tts: FlutterTtsOutput(),
    cache: createAudioCache(),
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

class AudioService {
  AudioService({required this.output, required this.tts, required this.cache});
  final AudioOutput output;
  final TtsOutput tts;
  final AudioCache cache;
  Object? _owner;
  int _generation = 0;
  bool _disposed = false;

  Future<void> _stopOutputs(int generation) async {
    try {
      await output.stop();
    } catch (_) {
      /* An unavailable backend may still have TTS. */
    }
    if (generation != _generation) return;
    try {
      await tts.stop();
    } catch (_) {
      /* An unavailable TTS engine may still play files. */
    }
  }

  Future<AudioOutcome> play({
    required Object owner,
    required String text,
    required String? locale,
    String? audioUrl,
  }) async {
    if (_disposed) return AudioOutcome.cancelled;
    _owner = owner;
    final generation = ++_generation;
    bool current() => !_disposed && generation == _generation;
    await _stopOutputs(generation);
    if (!current()) return AudioOutcome.cancelled;
    if (audioUrl != null && audioUrl.trim().isNotEmpty) {
      try {
        final asset = audioUrl.startsWith('assets/');
        var source = audioUrl;
        if (!asset) {
          try {
            source = await cache.resolve(audioUrl);
          } catch (_) {
            // Streaming is useful if the cache is full or browser CORS blocks fetching.
            final uri = Uri.tryParse(audioUrl);
            if (uri == null || !{'https', 'http'}.contains(uri.scheme)) rethrow;
          }
        }
        if (!current()) return AudioOutcome.cancelled;
        await output
            .load(source, asset: asset)
            .timeout(const Duration(seconds: 20));
        if (!current()) return AudioOutcome.cancelled;
        await output.play();
        return current() ? AudioOutcome.recorded : AudioOutcome.cancelled;
      } catch (_) {
        if (!current()) return AudioOutcome.cancelled;
        try {
          await output.stop();
        } catch (_) {
          /* Fall back to TTS. */
        }
      }
    }
    if (locale == null || locale.isEmpty) return AudioOutcome.missingVoice;
    try {
      final supported = await tts.supports(locale);
      if (!current()) return AudioOutcome.cancelled;
      if (!supported) return AudioOutcome.missingVoice;
      await tts.speak(text, locale);
      return current() ? AudioOutcome.tts : AudioOutcome.cancelled;
    } catch (_) {
      return current() ? AudioOutcome.unavailable : AudioOutcome.cancelled;
    }
  }

  Future<void> stop({Object? owner}) async {
    if (owner != null && owner != _owner) return;
    _owner = null;
    await _stopOutputs(++_generation);
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
    cache.dispose();
    await output.dispose();
  }
}

class PlayerAudioOutput implements AudioOutput {
  AudioPlayer? _player;
  AudioPlayer get player => _player ??= AudioPlayer();
  @override
  Future<void> load(String source, {required bool asset}) async {
    if (asset) {
      await player.setAsset(source);
    } else {
      await player.setUrl(source);
    }
  }

  @override
  Future<void> play() => player.play();
  @override
  Future<void> stop() async {
    await _player?.stop();
  }

  @override
  Future<void> dispose() async {
    await _player?.dispose();
  }
}

class FlutterTtsOutput implements TtsOutput {
  FlutterTts? _engine;
  FlutterTts get engine => _engine ??= FlutterTts();
  @override
  Future<bool> supports(String locale) async =>
      await engine.isLanguageAvailable(locale) == true;
  @override
  Future<void> speak(String text, String locale) async {
    await engine.awaitSpeakCompletion(true);
    await engine.setLanguage(locale);
    await engine.setSpeechRate(.45);
    final result = await engine.speak(text);
    if (result == 0) throw StateError('TTS unavailable');
  }

  @override
  Future<void> stop() async {
    await _engine?.stop();
  }
}
