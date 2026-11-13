abstract interface class AudioOutput {
  Future<void> load(String source, {required bool asset});
  Future<void> play();
  Future<void> stop();
  Future<void> dispose();
}

abstract interface class TtsOutput {
  Future<bool> supports(String locale);
  Future<void> speak(String text, String locale);
  Future<void> stop();
}

abstract interface class AudioCache {
  Future<String> resolve(String url);
  void dispose();
}

enum AudioOutcome { recorded, tts, missingVoice, unavailable, cancelled }
