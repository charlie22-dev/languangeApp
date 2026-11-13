import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/audio/data/audio_service.dart';
import 'package:myapp/features/audio/data/speech_service.dart';
import 'package:myapp/features/audio/presentation/speaking_controller.dart';
import 'package:myapp/features/exercises/domain/exercise.dart';

import 'support/audio_fixtures.dart';

void main() {
  test('recording starts explicitly and late transcripts cannot update a disposed exercise', () async {
    final speech = FakeSpeechService();
    final container = ProviderContainer(
      overrides: [
        audioServiceProvider.overrideWithValue(fakeAudio()),
        speechServiceProvider.overrideWithValue(speech),
      ],
    );
    addTearDown(container.dispose);
    final exercise = Speaking(id: 's', phrase: 'hello');
    final provider = speakingControllerProvider(exercise);
    final sub = container.listen(provider, (_, _) {});
    expect(speech.starts, 0);
    await container.read(provider.notifier).start('en-US');
    expect(container.read(provider).recording, isTrue);
    final lateResult = speech.words!;
    speech.result('HELLO!');
    expect(container.read(provider).score, 1);
    sub.close();
    await container.pump();
    expect(() => lateResult('old result', true), returnsNormally);
    expect(speech.active, isFalse);
  });
  test(
    'unavailable recognition becomes retryable state without recording',
    () async {
      final speech = FakeSpeechService()..denied = true;
      final container = ProviderContainer(
        overrides: [
          audioServiceProvider.overrideWithValue(fakeAudio()),
          speechServiceProvider.overrideWithValue(speech),
        ],
      );
      addTearDown(container.dispose);
      final provider = speakingControllerProvider(
        Speaking(id: 's', phrase: 'hello'),
      );
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await container.read(provider.notifier).start('en-US');
      expect(container.read(provider).busy, isFalse);
      expect(container.read(provider).error, 'speechPermissionDenied');
      speech.denied = false;
      await container.read(provider.notifier).start('en-US');
      expect(container.read(provider).recording, isTrue);
    },
  );
}
