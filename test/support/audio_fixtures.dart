import 'package:myapp/features/audio/data/audio_service.dart';
import 'package:myapp/features/audio/data/speech_service.dart';
import 'package:myapp/features/audio/domain/audio_ports.dart';

class FakeAudioOutput implements AudioOutput {
  final loaded = <String>[];
  bool fail = false;
  int plays = 0, stops = 0;
  @override
  Future<void> load(String source, {required bool asset}) async {
    if (fail) throw StateError('Unavailable file');
    loaded.add('${asset ? 'asset' : 'url'}:$source');
  }

  @override
  Future<void> play() async {
    plays++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {}
}

class FakeTts implements TtsOutput {
  bool available = true, fail = false;
  final spoken = <({String text, String locale})>[];
  @override
  Future<bool> supports(String locale) async => available;
  @override
  Future<void> speak(String text, String locale) async {
    if (fail) throw StateError('No engine');
    spoken.add((text: text, locale: locale));
  }

  @override
  Future<void> stop() async {}
}

class FakeAudioCache implements AudioCache {
  int requests = 0;
  Future<String>? pending;
  @override
  Future<String> resolve(String url) async {
    requests++;
    return pending ?? 'file:///cached/clip.mp3';
  }

  @override
  void dispose() {}
}

AudioService fakeAudio({
  FakeTts? tts,
  FakeAudioOutput? output,
  FakeAudioCache? cache,
}) => AudioService(
  output: output ?? FakeAudioOutput(),
  tts: tts ?? FakeTts(),
  cache: cache ?? FakeAudioCache(),
);

class FakeSpeechService implements SpeechService {
  Object? owner;
  bool denied = false, active = false;
  int starts = 0;
  void Function(String, bool)? words;
  void Function(bool)? status;
  @override
  Future<void> listen({
    required Object owner,
    required String locale,
    required void Function(String, bool) onWords,
    required void Function(bool) onStatus,
    required void Function(String) onError,
  }) async {
    starts++;
    if (denied) throw const SpeechFailure('speechPermissionDenied');
    this.owner = owner;
    words = onWords;
    status = onStatus;
    active = true;
    onStatus(true);
  }

  void result(String text, {bool finalResult = true}) {
    active = !finalResult;
    words?.call(text, finalResult);
    if (finalResult) status?.call(false);
  }

  @override
  bool listeningFor(Object owner) => this.owner == owner && active;
  @override
  Future<void> stop(Object owner) async {
    if (this.owner == owner) {
      active = false;
      status?.call(false);
    }
  }

  @override
  Future<void> cancel({Object? owner}) async {
    if (owner != null && this.owner != owner) return;
    active = false;
    status?.call(false);
    this.owner = null;
    words = null;
    status = null;
  }
}
