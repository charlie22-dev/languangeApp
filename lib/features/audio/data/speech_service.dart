import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

final speechServiceProvider = Provider<SpeechService>(
  (ref) => PluginSpeechService(),
);

class SpeechFailure implements Exception {
  const SpeechFailure(this.key);
  final String key;
}

abstract interface class SpeechService {
  Future<void> listen({
    required Object owner,
    required String locale,
    required void Function(String text, bool finalResult) onWords,
    required void Function(bool listening) onStatus,
    required void Function(String key) onError,
  });
  bool listeningFor(Object owner);
  Future<void> stop(Object owner);
  Future<void> cancel({Object? owner});
}

class PluginSpeechService implements SpeechService {
  final _speech = SpeechToText();
  Object? _owner;
  int _generation = 0;
  void Function(bool)? _status;
  void Function(String)? _error;
  @override
  bool listeningFor(Object owner) => owner == _owner && _speech.isListening;

  @override
  Future<void> listen({
    required Object owner,
    required String locale,
    required void Function(String text, bool finalResult) onWords,
    required void Function(bool listening) onStatus,
    required void Function(String key) onError,
  }) async {
    _status?.call(false);
    _status = null;
    _error = null;
    _owner = owner;
    final generation = ++_generation;
    bool current() => _owner == owner && generation == _generation;
    await _speech.cancel();
    if (!current()) return;
    _status = onStatus;
    _error = onError;
    final available = await _speech.initialize(
      onStatus: (status) =>
          _status?.call(status == SpeechToText.listeningStatus),
      onError: (error) => _error?.call(switch (error.errorMsg) {
        'error_permission_denied' ||
        'error_audio_error' => 'speechPermissionDenied',
        'error_network' || 'error_network_timeout' => 'speechNetworkError',
        'error_no_match' || 'error_speech_timeout' => 'speechNoMatch',
        _ => 'speechUnavailable',
      }),
      options: [SpeechToText.androidNoBluetooth],
    );
    if (!current()) return;
    if (!available) throw const SpeechFailure('speechUnavailable');
    var selected = locale;
    if (!kIsWeb) {
      final locales = await _speech.locales();
      if (!current()) return;
      String normalize(String code) => code.replaceAll('_', '-').toLowerCase();
      final requested = normalize(locale);
      final matches = locales
          .where((l) => normalize(l.localeId) == requested)
          .toList();
      final languageMatches = locales
          .where(
            (l) =>
                normalize(l.localeId).split('-').first ==
                requested.split('-').first,
          )
          .toList();
      if (matches.isEmpty && languageMatches.isEmpty) {
        throw const SpeechFailure('speechLocaleUnavailable');
      }
      selected =
          (matches.isNotEmpty ? matches.first : languageMatches.first).localeId;
    }
    await _speech.listen(
      onResult: (result) {
        if (current()) onWords(result.recognizedWords, result.finalResult);
      },
      listenOptions: SpeechListenOptions(
        localeId: selected,
        listenMode: ListenMode.confirmation,
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Future<void> stop(Object owner) async {
    if (_owner != owner) return;
    await _speech.stop();
    if (_owner == owner) _status?.call(false);
  }

  @override
  Future<void> cancel({Object? owner}) async {
    if (owner != null && owner != _owner) return;
    _generation++;
    _owner = null;
    _status?.call(false);
    _status = null;
    _error = null;
    try {
      await _speech.cancel();
    } catch (_) {
      // Session ownership/callbacks are already cleared; cleanup must not crash navigation.
    }
  }
}
