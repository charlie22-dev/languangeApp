import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/audio/domain/audio_ports.dart';

import 'support/audio_fixtures.dart';

void main() {
  test('bundled recording wins over TTS and remote cache', () async {
    final output = FakeAudioOutput();
    final tts = FakeTts();
    final cache = FakeAudioCache();
    final service = fakeAudio(output: output, tts: tts, cache: cache);
    expect(
      await service.play(
        owner: Object(),
        text: 'hello',
        locale: 'en-US',
        audioUrl: 'assets/audio/hello.mp3',
      ),
      AudioOutcome.recorded,
    );
    expect(output.loaded.single, 'asset:assets/audio/hello.mp3');
    expect(tts.spoken, isEmpty);
    expect(cache.requests, 0);
  });
  test('remote audio is resolved through cache', () async {
    final output = FakeAudioOutput();
    final cache = FakeAudioCache();
    final service = fakeAudio(output: output, cache: cache);
    expect(
      await service.play(
        owner: Object(),
        text: 'hello',
        locale: 'en-US',
        audioUrl: 'https://example.com/hello.mp3',
      ),
      AudioOutcome.recorded,
    );
    expect(output.loaded.single, 'url:file:///cached/clip.mp3');
    expect(cache.requests, 1);
  });
  test('broken recording falls back to the requested language voice', () async {
    final tts = FakeTts();
    final service = fakeAudio(output: FakeAudioOutput()..fail = true, tts: tts);
    expect(
      await service.play(
        owner: Object(),
        text: 'hello',
        locale: 'ja-JP',
        audioUrl: 'assets/audio/missing.mp3',
      ),
      AudioOutcome.tts,
    );
    expect(tts.spoken.single.locale, 'ja-JP');
  });
  test('missing voice and engine errors become actionable outcomes', () async {
    expect(
      await fakeAudio(tts: FakeTts()..available = false)
          .play(owner: Object(), text: 'hello', locale: 'ja-JP'),
      AudioOutcome.missingVoice,
    );
    expect(
      await fakeAudio(tts: FakeTts()..fail = true)
          .play(owner: Object(), text: 'hello', locale: 'ja-JP'),
      AudioOutcome.unavailable,
    );
  });
  test('superseded download cannot interrupt a newer utterance', () async {
    final pending = Completer<String>();
    final cache = FakeAudioCache()..pending = pending.future;
    final output = FakeAudioOutput();
    final tts = FakeTts();
    final service = fakeAudio(output: output, tts: tts, cache: cache);
    final oldOwner = Object();
    final newOwner = Object();
    final old = service.play(
      owner: oldOwner,
      text: 'old',
      locale: 'en-US',
      audioUrl: 'https://example.com/old.mp3',
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      await service.play(owner: newOwner, text: 'new', locale: 'en-US'),
      AudioOutcome.tts,
    );
    final stops = output.stops;
    await service.stop(owner: oldOwner);
    expect(output.stops, stops);
    pending.complete('file:///old.mp3');
    expect(await old, AudioOutcome.cancelled);
    expect(output.loaded, isEmpty);
    expect(tts.spoken.single.text, 'new');
  });
}
